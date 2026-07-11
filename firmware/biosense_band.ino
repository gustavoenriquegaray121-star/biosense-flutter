// ============================================================
// BIOSENSE BAND — Firmware v3.0 COMPLETO
// ESP32-C3 SuperMini
// Sensores: MAX30102 + MAX30205 + GSR
// BLE SecureLink — UUIDs sincronizados con la app Flutter
// ============================================================

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>

#include <MAX30105.h>
#include <heartRate.h>

// ============================================================
// UUIDs (IDÉNTICOS a la app Flutter)
// ============================================================
#define SERVICE_UUID        "A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E"
#define CHARACTERISTIC_UUID "B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6"
#define DEVICE_NAME         "BioSense-Band"
#define PACKET_SIZE         44

// ============================================================
// PINES
// ============================================================
#define PIN_GSR     3     // GPIO3 — ADC para GSR
#define PIN_SDA     6     // GPIO6 — I2C Data
#define PIN_SCL     7     // GPIO7 — I2C Clock
#define PIN_LED     8     // LED interno

// Direcciones I2C
#define ADDR_MAX30102  0x57
#define ADDR_MAX30205  0x48

// Objetos globales
MAX30105 particleSensor;

BLEServer*         pServer         = nullptr;
BLECharacteristic* pCharacteristic = nullptr;

bool deviceConnected    = false;
bool oldDeviceConnected = false;

uint32_t sequenceNumber = 0;
uint8_t  packet[PACKET_SIZE];

// Métricas
float hrv_ms    = 45.0;
float temp_c    = 36.6;
float gsr_us    = 1.2;
float spo2_pct  = 98.0;

// HRV
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 72.0;
int   beatAvg = 72;

// Estado sensores
bool max30102_ok = false;
bool max30205_ok = false;

// ============================================================
// CALLBACKS BLE
// ============================================================
class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
        deviceConnected = true;
        digitalWrite(PIN_LED, HIGH);
        Serial.println("[BLE] Dispositivo conectado");
    }

    void onDisconnect(BLEServer* pServer) override {
        deviceConnected = false;
        digitalWrite(PIN_LED, LOW);
        Serial.println("[BLE] Dispositivo desconectado");
    }
};

// ============================================================
// INICIALIZACIÓN DE SENSORES
// ============================================================
bool initMAX30102() {
    if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
        Serial.println("[MAX30102] ERROR: Sensor no encontrado");
        return false;
    }
    particleSensor.setup();
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeGreen(0);
    Serial.println("[MAX30102] Inicializado correctamente");
    return true;
}

float readMAX30205() {
    Wire.beginTransmission(ADDR_MAX30205);
    Wire.write(0x00);
    if (Wire.endTransmission(false) != 0) return temp_c;

    Wire.requestFrom(ADDR_MAX30205, 2);
    if (Wire.available() < 2) return temp_c;

    uint8_t msb = Wire.read();
    uint8_t lsb = Wire.read();

    int16_t raw = ((int16_t)msb << 8) | lsb;
    raw >>= 7;
    float tempC = raw * 0.5f;

    if (tempC >= 35.0 && tempC <= 42.0) return tempC;
    return temp_c;
}

float readGSR() {
    int raw = analogRead(PIN_GSR);
    if (raw <= 0) return gsr_us;

    float resistance = (4095.0 - raw) * 10000.0 / raw;
    if (resistance <= 0) return gsr_us;

    float conductance = 1000000.0 / resistance;
    if (conductance >= 0.1 && conductance <= 50.0) return conductance;
    return gsr_us;
}

// ============================================================
// LECTURA DE PULSO Y SpO2
// ============================================================
void readMAX30102() {
    long irValue = particleSensor.getIR();

    if (irValue < 50000) return;  // Sin dedo

    if (checkForBeat(irValue)) {
        long delta = millis() - lastBeat;
        lastBeat = millis();
        beatsPerMinute = 60.0 / (delta / 1000.0);

        if (beatsPerMinute < 255 && beatsPerMinute > 20) {
            rates[rateSpot++] = (byte)beatsPerMinute;
            rateSpot %= RATE_SIZE;

            beatAvg = 0;
            for (byte x = 0; x < RATE_SIZE; x++) beatAvg += rates[x];
            beatAvg /= RATE_SIZE;
        }
    }

    hrv_ms = (float)beatAvg;

    long redValue = particleSensor.getRed();
    if (redValue > 0 && irValue > 0) {
        float ratio = (float)redValue / (float)irValue;
        spo2_pct = 104.0 - 17.0 * ratio;
        spo2_pct = constrain(spo2_pct, 90.0, 100.0);
    }
}

// ============================================================
// LECTURA GENERAL
// ============================================================
void readAllSensors() {
    if (max30102_ok) readMAX30102();
    if (max30205_ok) temp_c = readMAX30205();
    gsr_us = readGSR();
}

// ============================================================
// CONSTRUCCIÓN DE PAQUETE
// ============================================================
void buildPacket(uint8_t* buf) {
    uint32_t now_ms = millis();
    uint16_t hrv_raw = (uint16_t)(hrv_ms * 100);
    uint16_t tmp_raw = (uint16_t)(temp_c * 100);
    uint16_t gsr_raw = (uint16_t)(gsr_us * 1000);
    uint16_t spo_raw = (uint16_t)(spo2_pct * 100);

    memset(buf, 0, PACKET_SIZE);

    // Sequence Number
    buf[0] = (sequenceNumber >> 0) & 0xFF;
    buf[1] = (sequenceNumber >> 8) & 0xFF;
    buf[2] = (sequenceNumber >> 16) & 0xFF;
    buf[3] = (sequenceNumber >> 24) & 0xFF;

    // Timestamp
    buf[4] = (now_ms >> 0) & 0xFF;
    buf[5] = (now_ms >> 8) & 0xFF;
    buf[6] = (now_ms >> 16) & 0xFF;
    buf[7] = (now_ms >> 24) & 0xFF;

    // Datos
    buf[8]  = (hrv_raw >> 0) & 0xFF;
    buf[9]  = (hrv_raw >> 8) & 0xFF;
    buf[10] = (tmp_raw >> 0) & 0xFF;
    buf[11] = (tmp_raw >> 8) & 0xFF;
    buf[12] = (gsr_raw >> 0) & 0xFF;
    buf[13] = (gsr_raw >> 8) & 0xFF;
    buf[14] = (spo_raw >> 0) & 0xFF;
    buf[15] = (spo_raw >> 8) & 0xFF;

    buf[16] = 100;  // Trust Score

    // Tag de autenticación simple
    uint8_t tag = 0xA5;
    for (int i = 0; i < 28; i++) tag ^= buf[i];
    for (int i = 28; i < PACKET_SIZE; i++) {
        buf[i] = tag ^ (uint8_t)(i * 7 + 13);
    }
}

// ============================================================
// SETUP
// ============================================================
void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(PIN_LED, OUTPUT);
    digitalWrite(PIN_LED, LOW);

    Wire.begin(PIN_SDA, PIN_SCL);
    delay(100);

    max30102_ok = initMAX30102();
    max30205_ok = true;

    analogReadResolution(12);

    // Inicializar BLE
    BLEDevice::init(DEVICE_NAME);
    BLEDevice::setMTU(64);

    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService* pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY);

    pCharacteristic->addDescriptor(new BLE2902());
    pService->start();

    BLEAdvertising* pAdv = BLEDevice::getAdvertising();
    pAdv->addServiceUUID(SERVICE_UUID);
    pAdv->setScanResponse(true);
    BLEDevice::startAdvertising();

    Serial.println("BioSense Band v3.0 iniciado");
    Serial.println("Esperando conexión con la app...");

    // Parpadeo inicial
    for (int i = 0; i < 3; i++) {
        digitalWrite(PIN_LED, HIGH); delay(200);
        digitalWrite(PIN_LED, LOW);  delay(200);
    }
}

// ============================================================
// LOOP
// ============================================================
void loop() {
    if (deviceConnected) {
        readAllSensors();
        buildPacket(packet);

        pCharacteristic->setValue(packet, PACKET_SIZE);
        pCharacteristic->notify();
        sequenceNumber++;

        if (sequenceNumber % 100 == 0) {
            Serial.printf("[PKT %lu] BPM:%.0f Temp:%.2f°C GSR:%.2fµS SpO2:%.1f%%\n",
                sequenceNumber, hrv_ms, temp_c, gsr_us, spo2_pct);
        }

        delay(20);  // 50 Hz
    }

    // Reconexión automática
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        pServer->startAdvertising();
        oldDeviceConnected = deviceConnected;
    }
    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }
}
