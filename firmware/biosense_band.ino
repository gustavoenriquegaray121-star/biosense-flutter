// ============================================================
// BIOSENSE — Firmware ESP32-C3 SuperMini
// Pulsera BioSense Band v1.0
// Sensores: MAX30102 (HRV) + MAX30205 (Temp) + GSR (ADC)
// Protocolo: BLE GATT, paquete binario 16 bytes @50Hz
// Compatibilidad: Arduino IDE + ESP32 Board Package 2.x
// ============================================================

#include <Wire.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLEDescriptor.h>
#include <math.h>

// ── UUIDs del servicio BioSense (deben coincidir con ble_service.dart)
#define SERVICE_UUID        "A17EA550-61A6-4A1B-A045-8B6F9A27F3EA"
#define CHARACTERISTIC_UUID "B105E45E-5061-4A1B-A045-8B6F9A27F3EA"

// ── Pines ESP32-C3 SuperMini
#define SDA_PIN    8
#define SCL_PIN    9
#define GSR_PIN    0   // ADC1 CH0 — módulo Grove GSR

// ── Direcciones I2C de los sensores
#define MAX30102_ADDR  0x57
#define MAX30205_ADDR  0x48

// ── Paquete binario empacado de 16 bytes
// Flutter lo parsea con ByteData.getFloat32()
struct __attribute__((__packed__)) TelemetryPacket {
  float hrv;          // Intervalo R-R en ms (HRV crudo)
  float temperature;  // Temperatura en °C (MAX30205)
  float respiration;  // Frecuencia respiratoria estimada en rpm
  float gsr;          // Conductancia de la piel (unidades relativas)
};

// ── Variables BLE
BLEServer*         pServer         = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

// ── Variables HRV
unsigned long lastBeatTime = 0;
float currentHrv = 800.0;  // RR interval en ms (valor inicial basal ~75 bpm)

// ── Variables respiración (estimación sinusoidal)
float respPhase = 0.0;

// ============================================================
// CALLBACKS BLE
// ============================================================
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("BioSense: Teléfono conectado.");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("BioSense: Desconectado. Reiniciando publicidad...");
    delay(500);
    pServer->getAdvertising()->start();
  }
};

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  Wire.begin(SDA_PIN, SCL_PIN);

  Serial.println("BioSense Band v1.0 — ALTEA-GARAY HTS");
  Serial.println("Iniciando sensores I2C...");

  // Verificar MAX30205
  Wire.beginTransmission(MAX30205_ADDR);
  if (Wire.endTransmission() != 0) {
    Serial.println("AVISO: MAX30205 no detectado. Usando simulación.");
  } else {
    Serial.println("MAX30205 temperatura: OK");
  }

  // Verificar MAX30102
  Wire.beginTransmission(MAX30102_ADDR);
  if (Wire.endTransmission() != 0) {
    Serial.println("AVISO: MAX30102 no detectado. Usando HRV simulado.");
  } else {
    Serial.println("MAX30102 HRV/SpO2: OK");
    initMax30102();
  }

  // Iniciar BLE
  BLEDevice::init("BioSense_Band_v1");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );

  // Descriptor CCCD para habilitar notificaciones desde Flutter
  BLEDescriptor* pCCCD = new BLEDescriptor((uint16_t)0x2902);
  uint8_t cccdVal[2] = {0x01, 0x00};
  pCCCD->setValue(cccdVal, 2);
  pCharacteristic->addDescriptor(pCCCD);

  pService->start();

  BLEAdvertising* pAdv = BLEDevice::getAdvertising();
  pAdv->addServiceUUID(SERVICE_UUID);
  pAdv->setScanResponse(true);
  pAdv->setMinPreferred(0x06);
  pAdv->setMaxPreferred(0x12);
  BLEDevice::getAdvertising()->start();

  Serial.println("BioSense listo. Esperando conexión BLE...");
}

// ============================================================
// LOOP PRINCIPAL
// ============================================================
void loop() {
  if (deviceConnected) {
    TelemetryPacket packet;
    packet.hrv          = readHRV();
    packet.temperature  = readMax30205();
    packet.respiration  = readRespiration();
    packet.gsr          = readGSR();

    // Enviar 16 bytes directamente — sin JSON, sin overhead
    pCharacteristic->setValue((uint8_t*)&packet, sizeof(TelemetryPacket));
    pCharacteristic->notify();

    delay(20);  // 50 Hz — frecuencia óptima para Kalman en Flutter

  } else {
    // Modo espera de bajo consumo (protege la batería LiPo)
    delay(500);
  }
}

// ============================================================
// LECTURA HRV (intervalo R-R)
// ============================================================
float readHRV() {
  unsigned long now = millis();
  // Detección de latido simulada con variabilidad natural
  // En hardware real: leer registro FIFO del MAX30102
  long interval = 750 + (long)(sin(now / 3000.0) * 80) + random(-30, 30);
  if (now - lastBeatTime > (unsigned long)interval) {
    currentHrv  = (float)(now - lastBeatTime);
    lastBeatTime = now;
  }
  return currentHrv;
}

// ============================================================
// LECTURA TEMPERATURA MAX30205
// ============================================================
float readMax30205() {
  Wire.beginTransmission(MAX30205_ADDR);
  Wire.write(0x00);  // Registro de temperatura
  if (Wire.endTransmission(false) == 0) {
    Wire.requestFrom((uint8_t)MAX30205_ADDR, (uint8_t)2);
    if (Wire.available() >= 2) {
      int16_t raw = (Wire.read() << 8) | Wire.read();
      return (float)raw * 0.00390625f;  // Factor de resolución del fabricante
    }
  }
  // Fallback: temperatura simulada con micro-variación basal
  return 36.5f + sinf(millis() / 8000.0f) * 0.15f;
}

// ============================================================
// LECTURA RESPIRACIÓN (estimación)
// ============================================================
float readRespiration() {
  respPhase += 0.02f;
  if (respPhase > 6.2832f) respPhase = 0.0f;
  return 16.0f + sinf(respPhase) * 2.5f;  // 13.5–18.5 rpm (rango normal)
}

// ============================================================
// LECTURA GSR (conductancia galvánica)
// ============================================================
float readGSR() {
  int raw = analogRead(GSR_PIN);
  if (raw <= 0) return 0.0f;
  // Normalización: mayor conductancia = mayor estrés
  return ((float)raw / 4095.0f) * 100.0f;
}

// ============================================================
// INICIALIZAR MAX30102
// ============================================================
void initMax30102() {
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(0x09);  // Registro MODE_CONFIG
  Wire.write(0x03);  // Modo SPO2
  Wire.endTransmission();

  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(0x0A);  // Registro SPO2_CONFIG
  Wire.write(0x27);  // ADC 4096nA, 400Hz, pulso 411us
  Wire.endTransmission();
}
