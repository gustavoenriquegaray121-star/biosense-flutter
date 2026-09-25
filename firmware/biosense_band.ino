// BioSense Band - Firmware v5.9.0 - PHSE World Class
// Platform: ESP32-C3 Only - 50Hz sampling, Homeostatic Engine
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <MAX30105.h>
#include <heartRate.h>
#include <Preferences.h>

#define SERVICE_UUID "A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E"
#define CHARACTERISTIC_UUID "B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6"
#define CHARACTERISTIC_EPOCH_UUID "C206F56F-3B8E-4D9B-AF4F-B2C3D4E5F6A"
#define DEVICE_NAME "BioSense-Band"
#define PROTOCOL_VERSION 0x05
#define PACKET_SIZE 44
#define FRAG_SIZE 17
#define DARWIN_ENABLED false

#define PIN_SDA 6
#define PIN_SCL 7
#define PIN_NIR 4
#define PIN_LED 8
#define PIN_BAT 3

#define ADDR_MLX90614 0x5A
#define ADDR_MPU6050 0x68

enum SensorFlags : uint8_t {
  FLAG_MAX_VALID = 1 << 0,
  FLAG_MLX_VALID = 1 << 1,
  FLAG_MPU_VALID = 1 << 2,
  FLAG_BAT_VALID = 1 << 3,
  FLAG_HRV_VALID = 1 << 4,
  FLAG_OXY_VALID = 1 << 5,
  FLAG_GLUCOSE_EXPERIMENTAL = 1 << 6,
  FLAG_MOTION_VALID = 1 << 7
};

// --- TU APORTE 1: Motor PHSE con Zona Homeostática ---
struct PHSE_State {
  float current_value;
  float predicted_delta;
  float stability_index;
  float filtered_buffer[10];
  uint8_t buf_idx;
};

PHSE_State glucoseEngine = {100.0f, 0, 1.0f, {0}, 0};
PHSE_State hrvEngine = {72.0f, 0, 1.0f, {0}, 0};

void updatePHSE(PHSE_State &engine, float newValue) {
  // Filtro de media móvil para 50Hz
  engine.filtered_buffer[engine.buf_idx] = newValue;
  engine.buf_idx = (engine.buf_idx + 1) % 10;
  float avg = 0;
  for(int i=0;i<10;i++) avg += engine.filtered_buffer[i];
  avg /= 10.0f;

  float delta = avg - engine.current_value;

  if (fabsf(delta) > 15.0f) {
    avg = engine.current_value + (delta * 0.1f);
    engine.stability_index = max(0.0f, engine.stability_index - 0.05f);
  } else {
    engine.stability_index = min(1.0f, engine.stability_index + 0.01f);
  }

  engine.current_value = avg;
  engine.predicted_delta = delta;
}

MAX30105 particleSensor;
Preferences prefs;
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
BLECharacteristic* pEpochChar = nullptr;
bool deviceConnected = false;
bool shouldRestartAdv = false;
uint16_t negotiatedMTU = 23;
uint32_t sequenceNumber = 0;
uint8_t packet[PACKET_SIZE];
uint8_t lastPacket[PACKET_SIZE];
float hrv_estimated_ms = 0;
float lastValidHRV = 0;
float oxygenation_index_pct = 0;
float temp_c = 0;
float gsr_ratio = 0;
float glucose_index = 0;
float ax=0, ay=0, az=0;
float motion_magnitude = 0;
float motion_history[5] = {0};
uint8_t motion_hist_idx = 0;
uint8_t validMotionSamples = 0;
float battery_v = 0;
float calib_m = 200.0f;
float calib_b = 80.0f;
const byte RATE_SIZE = 8;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;
long beatIntervals[10] = {0};
byte intervalSpot = 0;
uint8_t validIntervals = 0;
uint8_t fitness[5] = {0};
uint8_t fitnessWinner = 0;
float darwin_weights[5] = {0.30f, 0.25f, 0.20f, 0.15f, 0.10f};
uint16_t winStreak[5] = {0};
bool max_ok = false;
bool mlx_ok = false;
bool mpu_ok = false;
uint8_t sensorFlags = 0;
unsigned long lastMLXRead = 0;
unsigned long lastAdvRestart = 0;
unsigned long lastBLETX = 0;
unsigned long lastPrefsSave = 0;
unsigned long lastSample = 0;
const unsigned long SAMPLE_INTERVAL = 20; // 50Hz FIX: antes 100ms
float last_hrv = 0, last_temp = 0, last_gluc = 0, last_motion = 0;
uint32_t epoch_offset = 0;

class EpochCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    std::string v = pChar->getValue();
    if (v.length() >= 4) {
      uint32_t epoch = (uint32_t)((uint8_t)v[0] | ((uint8_t)v[1] << 8) | ((uint8_t)v[2] << 16) | ((uint8_t)v[3] << 24));
      epoch_offset = epoch - (millis() / 1000);
      prefs.begin("darwin", false);
      prefs.putUInt("epoch", epoch_offset);
      prefs.end();
    }
  }
};

// --- TU APORTE 2: Clase completa ---
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      negotiatedMTU = pServer->getPeerMTU(pServer->getConnId());
      digitalWrite(PIN_LED, HIGH);
      Serial.println(">>> Dispositivo enlazado. Telemetría PHSE iniciada. MTU:");
      Serial.println(negotiatedMTU);
    }
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      shouldRestartAdv = true;
      negotiatedMTU = 23;
      digitalWrite(PIN_LED, LOW);
      Serial.println(">>> Conexión perdida. Reiniciando publicidad...");
    }
};

uint32_t crc32(const uint8_t* data, size_t len) {
  uint32_t crc = 0xFFFFFFFF;
  for (size_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (int j = 0; j < 8; j++) crc = (crc >> 1) ^ ((crc & 1)? 0xEDB88320 : 0);
  }
  return ~crc;
}

void loadDarwinWeights() {
  prefs.begin("darwin", true);
  if (prefs.isKey("w0")) {
    darwin_weights[0] = prefs.getFloat("w0", 0.30f);
    darwin_weights[1] = prefs.getFloat("w1", 0.25f);
    darwin_weights[2] = prefs.getFloat("w2", 0.20f);
    darwin_weights[3] = prefs.getFloat("w3", 0.15f);
    darwin_weights[4] = prefs.getFloat("w4", 0.10f);
    epoch_offset = prefs.getUInt("epoch", 0);
  }
  prefs.end();
}

// --- TU APORTE 3: Setup de máxima sensibilidad ---
void setupSensorMAX() {
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 no encontrado. Verifica I2C 6/7");
    max_ok = false;
  } else {
    // ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange
    particleSensor.setup(0x1F, 4, 2, 400, 411, 4096);
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeIR(0x0A);
    particleSensor.setPulseAmplitudeGreen(0);
    max_ok = true;
    Serial.println("MAX30102 OK a 50Hz, alta sensibilidad");
  }
}

float readMLX90614() {
  Wire.beginTransmission(ADDR_MLX90614);
  Wire.write(0x07);
  if (Wire.endTransmission(false)!= 0) return NAN;
  if (Wire.requestFrom((uint8_t)ADDR_MLX90614, (uint8_t)3)!= 3) return NAN;
  uint8_t lsb = Wire.read(); uint8_t msb = Wire.read(); Wire.read();
  uint16_t raw = ((uint16_t)msb << 8) | lsb;
  float tempC = raw * 0.02f - 273.15f;
  if (tempC < 30.0f || tempC > 45.0f) return NAN;
  return tempC;
}

void readMPU6050() {
  Wire.beginTransmission(ADDR_MPU6050);
  Wire.write(0x3B);
  if (Wire.endTransmission(false)!= 0) return;
  if (Wire.requestFrom((uint8_t)ADDR_MPU6050, (uint8_t)6)!= 6) return;
  int16_t ax_raw = (Wire.read() << 8) | Wire.read();
  int16_t ay_raw = (Wire.read() << 8) | Wire.read();
  int16_t az_raw = (Wire.read() << 8) | Wire.read();
  ax = ax_raw / 16384.0f; ay = ay_raw / 16384.0f; az = az_raw / 16384.0f;
  motion_magnitude = fabsf(sqrtf(ax*ax + ay*ay + az*az) - 1.0f);
  motion_history[motion_hist_idx] = motion_magnitude;
  motion_hist_idx = (motion_hist_idx + 1) % 5;
  if (validMotionSamples < 5) validMotionSamples++;
}

float predictMotionPhoenix() {
  if (validMotionSamples < 4) return motion_magnitude;
  int idx1 = (motion_hist_idx + 4) % 5;
  int idx2 = (motion_hist_idx + 3) % 5;
  int idx3 = (motion_hist_idx + 2) % 5;
  int idx4 = (motion_hist_idx + 1) % 5;
  float t1 = motion_history[idx1]; float t2 = motion_history[idx2];
  float t3 = motion_history[idx3]; float t4 = motion_history[idx4];
  float x = t1; float v = t1 - t2; float a = t1 - 2*t2 + t3;
  float j = t1 - 3*t2 + 3*t3 - t4;
  float dt = SAMPLE_INTERVAL / 1000.0f;
  float horizon = x + v*dt + 0.5f*a*dt*dt + (1.0f/6.0f)*j*dt*dt*dt;
  return constrain(horizon, 0.0f, 5.0f);
}

void computeFitness() {
  long irVal = 0; long redVal = 0;
  if (max_ok) { irVal = particleSensor.getIR(); redVal = particleSensor.getRed(); }
  float snr = (irVal > 0)? constrain(irVal / 300.0f, 0.0f, 255.0f) : 0;
  float perfusion = (redVal > 0 && irVal > 0)? constrain((irVal / (float)redVal) * 50.0f, 0.0f, 255.0f) : 0;
  float mean = 0; if (validMotionSamples > 0) { for (int i = 0; i < validMotionSamples; i++) mean += motion_history[i]; mean /= validMotionSamples; }
  float var = 0; if (validMotionSamples > 1) { for (int i = 0; i < validMotionSamples; i++) var += powf(motion_history[i] - mean, 2); var /= validMotionSamples; }
  float stability = constrain(255.0f - var * 5000.0f, 0.0f, 255.0f);
  float tempScore = (temp_c > 35.0f && temp_c < 39.0f)? 220.0f : 80.0f;
  float predictedMotion = predictMotionPhoenix();
  float motion_penalty = constrain(predictedMotion * 25.0f, 0.0f, 120.0f);
  auto weighted = [&](float snr_c, float perf_c) { return darwin_weights[0]*snr_c + darwin_weights[1]*(255.0f - motion_penalty*2.0f) + darwin_weights[2]*perf_c + darwin_weights[3]*tempScore + darwin_weights[4]*stability; };
  fitness[0] = constrain(weighted(snr, perfusion), 0.0f, 255.0f);
  fitness[1] = constrain(weighted(snr*0.8f, perfusion*0.9f), 0.0f, 255.0f);
  fitness[2] = constrain(weighted(200.0f, 150.0f) - motion_penalty*0.5f, 0.0f, 255.0f);
  fitness[3] = constrain(darwin_weights[0]*220.0f + darwin_weights[1]*240.0f + darwin_weights[2]*200.0f + darwin_weights[3]*tempScore + darwin_weights[4]*stability, 0.0f, 255.0f);
  fitness[4] = constrain(255.0f - predictedMotion*20.0f, 0.0f, 255.0f);
  fitnessWinner = 0; for (int i = 1; i < 5; i++) if (fitness[i] > fitness[fitnessWinner]) fitnessWinner = i;
}

float estimateGlucoseIndex(float nir_ratio, float ir_ratio, float skin_temp) {
  nir_ratio = constrain(nir_ratio, 0.01f, 2.0f);
  ir_ratio = constrain(ir_ratio, 0.01f, 1.0f);
  float ratio_diff = nir_ratio / ir_ratio;
  float temp_factor = 1.0f + (skin_temp - 36.6f) * 0.02f;
  float g = calib_b + (ratio_diff - 1.0f) * calib_m * temp_factor;
  return constrain(g, 40.0f, 400.0f);
}

void readAllSensorsOptimized() {
  sensorFlags = 0; sensorFlags |= FLAG_GLUCOSE_EXPERIMENTAL;
  long latestIr = 0; long latestRed = 0; bool hasNewSample = false;
  if (max_ok) {
    particleSensor.check();
    while (particleSensor.available()) {
      latestRed = particleSensor.getRed(); latestIr = particleSensor.getIR();
      particleSensor.nextSample(); hasNewSample = true;
      if (latestIr > 50000) {
        if (checkForBeat(latestIr)) {
          long now = millis(); long delta = now - lastBeat; lastBeat = now;
          if (delta > 300 && delta < 3000) {
            if (validIntervals > 0) {
              float meanInt = 0; for (byte x = 0; x < validIntervals; x++) meanInt += beatIntervals[x]; meanInt /= validIntervals;
              if (fabsf(delta - meanInt) <= meanInt * 0.20f) {
                beatIntervals[intervalSpot] = delta; intervalSpot = (intervalSpot + 1) % 10; if (validIntervals < 10) validIntervals++;
              }
            } else {
              beatIntervals[intervalSpot] = delta; intervalSpot = (intervalSpot + 1) % 10; if (validIntervals < 10) validIntervals++;
            }
            beatsPerMinute = 60000.0f / delta;
            if (beatsPerMinute < 255 && beatsPerMinute > 20) {
              rates[rateSpot++] = (byte)round(beatsPerMinute); rateSpot %= RATE_SIZE;
              beatAvg = 0; for (byte x = 0; x < RATE_SIZE; x++) beatAvg += rates[x]; beatAvg /= RATE_SIZE;
              if (validIntervals >= 8) {
                float mInt = 0; for (byte x = 0; x < validIntervals; x++) mInt += beatIntervals[x]; mInt /= validIntervals;
                float varInt = 0; for (byte x = 0; x < validIntervals; x++) varInt += powf(beatIntervals[x] - mInt, 2); varInt /= validIntervals;
                float computedHRV = sqrtf(varInt);
                if (computedHRV >= 5.0f && computedHRV < 300.0f) { lastValidHRV = computedHRV; hrv_estimated_ms = computedHRV; }
              }
            }
          }
        }
      }
    }
    if (hasNewSample && latestIr > 1000) {
      sensorFlags |= FLAG_MAX_VALID;
      static float red_dc = 0, ir_dc = 0;
      red_dc = red_dc * 0.95f + latestRed * 0.05f; ir_dc = ir_dc * 0.95f + latestIr * 0.05f;
      if (ir_dc > 1000 && red_dc > 1000) {
        float r_ratio = (latestRed / red_dc) / (latestIr / ir_dc);
        oxygenation_index_pct = constrain(110.0f - 25.0f * r_ratio, 0.0f, 100.0f);
        if (oxygenation_index_pct >= 70.0f) sensorFlags |= FLAG_OXY_VALID;
      }
    }
  }
  if (mpu_ok) { readMPU6050(); if (validMotionSamples >= 3) sensorFlags |= FLAG_MPU_VALID | FLAG_MOTION_VALID; }
  if (mlx_ok && millis() - lastMLXRead > 2000) {
    float newTemp = readMLX90614();
    if (!isnan(newTemp)) { if (temp_c == 0) temp_c = newTemp; else temp_c = temp_c * 0.7f + newTemp * 0.3f; sensorFlags |= FLAG_MLX_VALID; }
    lastMLXRead = millis();
  }
  if (validIntervals >= 8 && hrv_estimated_ms > 0) sensorFlags |= FLAG_HRV_VALID;
  float nir_raw = analogRead(PIN_NIR) / 4095.0f;
  float nir_ratio = 0.5f + nir_raw * 1.5f;
  float ir_ratio = max_ok? constrain((float)latestIr / 100000.0f, 0.01f, 1.0f) : 1.0f;
  float rawGlucose = estimateGlucoseIndex(nir_ratio, ir_ratio, temp_c);
  updatePHSE(glucoseEngine, rawGlucose);
  glucose_index = glucoseEngine.current_value;
  gsr_ratio = nir_ratio;
  battery_v = analogRead(PIN_BAT) * 3.3f / 4095.0f * 2.0f;
  if (battery_v > 3.0f) sensorFlags |= FLAG_BAT_VALID;
  computeFitness();
}

void buildPacket(uint8_t* buf) {
  uint32_t now = (millis() / 1000) + epoch_offset;
  uint16_t hrv_raw = (sensorFlags & FLAG_HRV_VALID)? (uint16_t)(hrv_estimated_ms * 100.0f) : 0;
  uint16_t tmp_raw = (sensorFlags & FLAG_MLX_VALID)? (uint16_t)(temp_c * 100.0f) : 0;
  uint16_t gsr_raw = (uint16_t)(gsr_ratio * 1000.0f);
  uint16_t spo_raw = (sensorFlags & FLAG_OXY_VALID)? (uint16_t)(oxygenation_index_pct * 100.0f) : 0;
  uint16_t glc_raw = (uint16_t)glucose_index;
  uint16_t mot_raw = (sensorFlags & FLAG_MOTION_VALID)? (uint16_t)(motion_magnitude * 1000.0f) : 0;
  uint16_t bat_raw = (sensorFlags & FLAG_BAT_VALID)? (uint16_t)(battery_v * 1000.0f) : 0;
  memset(buf, 0, PACKET_SIZE);
  buf[0] = PROTOCOL_VERSION; buf[1] = sensorFlags;
  buf[2] = sequenceNumber & 0xFF; buf[3] = (sequenceNumber >> 8) & 0xFF; buf[4] = (sequenceNumber >> 16) & 0xFF; buf[5] = (sequenceNumber >> 24) & 0xFF;
  buf[6] = now & 0xFF; buf[7] = (now >> 8) & 0xFF; buf[8] = (now >> 16) & 0xFF; buf[9] = (now >> 24) & 0xFF;
  buf[10] = hrv_raw & 0xFF; buf[11] = (hrv_raw >> 8) & 0xFF;
  buf[12] = tmp_raw & 0xFF; buf[13] = (tmp_raw >> 8) & 0xFF;
  buf[14] = gsr_raw & 0xFF; buf[15] = (gsr_raw >> 8) & 0xFF;
  buf[16] = spo_raw & 0xFF; buf[17] = (spo_raw >> 8) & 0xFF;
  buf[18] = fitness[fitnessWinner];
  buf[19] = glc_raw & 0xFF; buf[20] = (glc_raw >> 8) & 0xFF;
  buf[21] = mot_raw & 0xFF; buf[22] = (mot_raw >> 8) & 0xFF;
  for (int i = 0; i < 5; i++) buf[23 + i] = fitness[i];
  buf[28] = fitnessWinner; buf[29] = bat_raw & 0xFF; buf[30] = (bat_raw >> 8) & 0xFF;
  buf[31] = beatAvg & 0xFF; buf[32] = (uint8_t)beatsPerMinute;
  buf[33]=0; buf[34]=0; buf[35]=0; buf[36]=0; buf[37]=0; buf[38]=0; buf[39]=0;
  uint32_t crc = crc32(buf, 40);
  buf[40] = crc & 0xFF; buf[41] = (crc >> 8) & 0xFF; buf[42] = (crc >> 16) & 0xFF; buf[43] = (crc >> 24) & 0xFF;
}

void notifyFragmented() {
  if (negotiatedMTU >= PACKET_SIZE + 3) {
    pCharacteristic->setValue(packet, PACKET_SIZE); pCharacteristic->notify();
  } else {
    uint8_t totalFrags = (PACKET_SIZE + FRAG_SIZE - 1) / FRAG_SIZE;
    for (uint8_t f = 0; f < totalFrags; f++) {
      uint8_t frag[20]; frag[0] = sequenceNumber & 0xFF; frag[1] = f; frag[2] = totalFrags;
      uint8_t len = min((int)FRAG_SIZE, PACKET_SIZE - f * FRAG_SIZE);
      memcpy(&frag[3], &packet[f * FRAG_SIZE], len);
      pCharacteristic->setValue(frag, len + 3); pCharacteristic->notify(); delay(15);
    }
  }
}

void setup() {
  Serial.begin(115200); delay(1000);
  loadDarwinWeights();
  pinMode(PIN_LED, OUTPUT); digitalWrite(PIN_LED, LOW);
  pinMode(PIN_NIR, INPUT); pinMode(PIN_BAT, INPUT);
  analogReadResolution(12); analogSetAttenuation(ADC_11db);
  Wire.begin(PIN_SDA, PIN_SCL); delay(200);
  lastBeat = millis();
  setupSensorMAX();
  Wire.beginTransmission(ADDR_MLX90614); mlx_ok = (Wire.endTransmission() == 0);
  Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x6B); Wire.write(0x00); mpu_ok = (Wire.endTransmission() == 0); if (mpu_ok) delay(100);
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer(); pServer->setCallbacks(new MyServerCallbacks());
  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->addDescriptor(new BLE2902());
  pEpochChar = pService->createCharacteristic(CHARACTERISTIC_EPOCH_UUID, BLECharacteristic::PROPERTY_WRITE);
  pEpochChar->setCallbacks(new EpochCallbacks());
  pService->start();
  BLEAdvertising* pAdv = BLEDevice::getAdvertising();
  pAdv->addServiceUUID(SERVICE_UUID); pAdv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("PHSE v5.9.0 Listo - ESP32-C3 - 50Hz");
}

void loop() {
  if (shouldRestartAdv && millis() - lastAdvRestart > 500) { BLEDevice::startAdvertising(); shouldRestartAdv = false; lastAdvRestart = millis(); }
  if (millis() - lastSample >= SAMPLE_INTERVAL) {
    lastSample = millis();
    readAllSensorsOptimized();
    if (deviceConnected) {
      bool shouldTX = (fabsf(hrv_estimated_ms - last_hrv) > 1.0f || fabsf(temp_c - last_temp) > 0.1f || fabsf(glucose_index - last_gluc) > 2.0f || fabsf(motion_magnitude - last_motion) > 0.05f || millis() - lastBLETX > 1000);
      if (shouldTX) {
        buildPacket(packet);
        bool diff = false; for (int i = 0; i < 40; i++) { if (packet[i]!= lastPacket[i]) { diff = true; break; } }
        if (diff || millis() - lastBLETX > 1000) {
          notifyFragmented(); memcpy(lastPacket, packet, PACKET_SIZE);
          last_hrv = hrv_estimated_ms; last_temp = temp_c; last_gluc = glucose_index; last_motion = motion_magnitude;
          lastBLETX = millis(); sequenceNumber++;
        }
      }
    }
  }
}
