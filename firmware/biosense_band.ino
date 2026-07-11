// ============================================================
// BIOSENSE BAND — Firmware v2.0
// ESP32-C3 SuperMini + MAX30102 + MAX30205 + GSR
// SecureLink BLE: UUID sincronizados con Flutter app
// MTU negociada: 64 bytes (cubre 44 bytes del paquete)
// ============================================================

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>

// ============================================================
// UUIDs — DEBEN COINCIDIR EXACTAMENTE CON BleService en Flutter
// ============================================================
#define SERVICE_UUID        "A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E"
#define CHARACTERISTIC_UUID "B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6"
// NOTA: Estos son los mismos UUIDs que están en lib/services/ble_service.dart

// ============================================================
// PAQUETE SECURETELEMTRY — 44 bytes total
// Byte 0-3:   Sequence number (uint32 little-endian)
// Byte 4-7:   Timestamp ms (uint32 little-endian)
// Byte 8-9:   HRV * 100 (uint16)
// Byte 10-11: Temperature * 100 (uint16)
// Byte 12-13: GSR * 1000 (uint16)
// Byte 14-15: SpO2 * 100 (uint16)
// Byte 16:    Trust Score (uint8)
// Byte 17-27: Reserved (zeros)
// Byte 28-43: Auth Tag HMAC-SHA256 truncado 16 bytes
// ============================================================
#define PACKET_SIZE 44

// ============================================================
// VARIABLES GLOBALES
// ============================================================
BLEServer*         pServer         = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

uint32_t sequenceNumber = 0;
uint8_t  packet[PACKET_SIZE];

// Sensores (simulados hasta tener hardware físico)
float hrv_ms    = 45.0;
float temp_c    = 36.6;
float gsr_us    = 1.2;
float spo2_pct  = 98.0;
int   trustScore = 100;

// ============================================================
// CALLBACKS DE CONEXIÓN BLE
// ============================================================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] Cliente conectado");
    // Solicitar MTU de 64 bytes para el paquete de 44 bytes
    // El cliente Flutter también solicitará MTU mayor
    pServer->updateConnParams(0, 0x000F, 0x000F, 100);
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] Cliente desconectado");
  }
};

// ============================================================
// CONSTRUIR PAQUETE SECURETEMETRY
// ============================================================
void buildPacket(uint8_t* buf) {
  uint32_t now_ms = (uint32_t)(millis()); // timestamp relativo al arranque
  uint16_t hrv_raw  = (uint16_t)(hrv_ms * 100);
  uint16_t temp_raw = (uint16_t)(temp_c * 100);
  uint16_t gsr_raw  = (uint16_t)(gsr_us * 1000);
  uint16_t spo2_raw = (uint16_t)(spo2_pct * 100);

  // Limpiar buffer
  memset(buf, 0, PACKET_SIZE);

  // Bytes 0-3: Sequence (little-endian)
  buf[0] = (sequenceNumber >>  0) & 0xFF;
  buf[1] = (sequenceNumber >>  8) & 0xFF;
  buf[2] = (sequenceNumber >> 16) & 0xFF;
  buf[3] = (sequenceNumber >> 24) & 0xFF;

  // Bytes 4-7: Timestamp ms (little-endian)
  buf[4] = (now_ms >>  0) & 0xFF;
  buf[5] = (now_ms >>  8) & 0xFF;
  buf[6] = (now_ms >> 16) & 0xFF;
  buf[7] = (now_ms >> 24) & 0xFF;

  // Bytes 8-9: HRV
  buf[8]  = (hrv_raw >> 0) & 0xFF;
  buf[9]  = (hrv_raw >> 8) & 0xFF;

  // Bytes 10-11: Temperatura
  buf[10] = (temp_raw >> 0) & 0xFF;
  buf[11] = (temp_raw >> 8) & 0xFF;

  // Bytes 12-13: GSR
  buf[12] = (gsr_raw >> 0) & 0xFF;
  buf[13] = (gsr_raw >> 8) & 0xFF;

  // Bytes 14-15: SpO2
  buf[14] = (spo2_raw >> 0) & 0xFF;
  buf[15] = (spo2_raw >> 8) & 0xFF;

  // Byte 16: Trust Score
  buf[16] = (uint8_t)trustScore;

  // Bytes 17-27: Reserved
  // (ya en cero por memset)

  // Bytes 28-43: Auth Tag (HMAC simple con XOR para demo)
  // En producción: AES-256-GCM con clave compartida ECDH
  uint8_t tag = 0xA5; // seed
  for (int i = 0; i < 28; i++) tag ^= buf[i];
  tag ^= (uint8_t)(sequenceNumber & 0xFF);
  for (int i = 28; i < PACKET_SIZE; i++) {
    buf[i] = tag ^ (uint8_t)(i * 7 + 13);
  }
}

// ============================================================
// LEER SENSORES REALES (cuando estén conectados)
// Por ahora: simulación con variación realista
// ============================================================
void readSensors() {
  // TODO: Reemplazar con lectura real de MAX30102, MAX30205, GSR
  // MAX30102 → HRV + SpO2 via I2C (0x57)
  // MAX30205 → temperatura via I2C (0x48)
  // GSR → GPIO ADC pin A0

  // Simulación realista por ahora:
  float noise = (float)(random(-10, 10)) / 100.0;
  hrv_ms   = 45.0 + noise * 5;
  temp_c   = 36.6 + noise * 0.1;
  gsr_us   = 1.2  + noise * 0.3;
  spo2_pct = 98.0 + noise * 0.5;
  spo2_pct = constrain(spo2_pct, 95.0, 100.0);
}

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  Serial.println("[BioSense Band v2.0] Iniciando...");

  // Inicializar BLE
  BLEDevice::init("BioSense-Band");
  BLEDevice::setMTU(64); // Solicitar MTU 64 para paquete 44 bytes

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Crear servicio y característica
  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ   |
    BLECharacteristic::PROPERTY_NOTIFY |
    BLECharacteristic::PROPERTY_INDICATE
  );

  // Descriptor para notificaciones (requerido por BLE spec)
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  // Advertising — nombre visible en scan
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); // conexión rápida iPhone/Android
  pAdvertising->setMaxPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Esperando conexion...");
  Serial.print("[BLE] Service UUID:        "); Serial.println(SERVICE_UUID);
  Serial.print("[BLE] Characteristic UUID: "); Serial.println(CHARACTERISTIC_UUID);
}

// ============================================================
// LOOP — 50 Hz (cada 20ms)
// ============================================================
void loop() {
  if (deviceConnected) {
    readSensors();
    buildPacket(packet);

    // Enviar via BLE notify
    pCharacteristic->setValue(packet, PACKET_SIZE);
    pCharacteristic->notify();

    sequenceNumber++;

    // Debug cada 50 paquetes
    if (sequenceNumber % 50 == 0) {
      Serial.printf("[PKT %lu] HRV:%.1f Temp:%.2f GSR:%.3f SpO2:%.1f\n",
        sequenceNumber, hrv_ms, temp_c, gsr_us, spo2_pct);
    }

    delay(20); // 50 Hz
  }

  // Reconexión automática
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Reiniciando advertising...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}
