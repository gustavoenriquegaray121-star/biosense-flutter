// BioSense Band - Firmware v5.7.1 - Corregido
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
#define PACKET_SIZE 44
#define PIN_SDA 6
#define PIN_SCL 7
#define PIN_NIR 0
#define PIN_LED 8
#define ADDR_MLX90614 0x5A
#define ADDR_MPU6050 0x68

MAX30105 particleSensor;
Preferences prefs;
BLEServer* pServer=nullptr;
BLECharacteristic* pCharacteristic=nullptr;
BLECharacteristic* pEpochChar=nullptr;
bool deviceConnected=false;
bool shouldRestartAdv=false;
uint32_t sequenceNumber=0;
uint8_t packet[44];
uint8_t lastPacket[44];
float hrv_ms=72, spo2_pct=98, temp_c=36.6, gsr_ratio=1, glucose_index=100;
float ax=0, ay=0, az=0, motion_magnitude=0;
float motion_history[5]={};
uint8_t motion_hist_idx=0;
float calib_m=200, calib_b=80;
const byte RATE_SIZE=8;
byte rates[8];
byte rateSpot=0;
long lastBeat=0;
float beatsPerMinute=72;
int beatAvg=72;
long beatIntervals[8]={};
byte intervalSpot=0;
uint8_t fitness[5]={255,200,180,220,240};
uint8_t fitnessWinner=0;
float darwin_weights[5]={0.30,0.25,0.20,0.15,0.10};
uint16_t winStreak[5]={};
bool max_ok=false, mlx_ok=false, mpu_ok=false;
unsigned long lastMLXRead=0, lastAdvRestart=0, lastBLETX=0, lastPrefsSave=0;
float last_hrv=0, last_temp=0, last_gluc=0, last_motion=0;
uint32_t epoch_offset=0;

class EpochCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    std::string v=pChar->getValue();
    if(v.length()>=4){
      uint32_t epoch=(uint8_t)v[0]|((uint8_t)v[1]<<8)|((uint8_t)v[2]<<16)|((uint8_t)v[3]<<24);
      epoch_offset=epoch-(millis()/1000);
      prefs.begin("darwin",false);
      prefs.putUInt("epoch",epoch_offset);
      prefs.end();
    }
  }
};

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* p) override { deviceConnected=true; digitalWrite(PIN_LED,HIGH); }
  void onDisconnect(BLEServer* p) override { deviceConnected=false; shouldRestartAdv=true; digitalWrite(PIN_LED,LOW); }
};

bool initMAX30102(){
  if(!particleSensor.begin(Wire, I2C_SPEED_FAST)) return false;
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeIR(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);
  return true;
}

float readMLX90614(){
  Wire.beginTransmission(ADDR_MLX90614); Wire.write(0x07);
  if(Wire.endTransmission(false)!=0) return temp_c;
  Wire.requestFrom(ADDR_MLX90614,3);
  if(Wire.available()<3) return temp_c;
  uint8_t lsb=Wire.read(), msb=Wire.read(); Wire.read();
  uint16_t raw=((uint16_t)msb<<8)|lsb;
  float tempC=raw*0.02-273.15;
  if(tempC<30 || tempC>45) return temp_c;
  return temp_c*0.7 + tempC*0.3;
}

void readMPU6050(){
  Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x3B);
  Wire.endTransmission(false); Wire.requestFrom(ADDR_MPU6050,6);
  if(Wire.available()<6) return;
  int16_t ax_raw=(Wire.read()<<8)|Wire.read();
  int16_t ay_raw=(Wire.read()<<8)|Wire.read();
  int16_t az_raw=(Wire.read()<<8)|Wire.read();
  ax=ax_raw/16384.0; ay=ay_raw/16384.0; az=az_raw/16384.0;
  motion_magnitude=fabs(sqrt(ax*ax+ay*ay+az*az)-1.0);
  motion_history[motion_hist_idx]=motion_magnitude;
  motion_hist_idx=(motion_hist_idx+1)%5;
}

float predictMotionPhoenix(){
  float t1=motion_history[4], t2=motion_history[3], t3=motion_history[2], t4=motion_history[1];
  float x=t1; float v=t1-t2; float a=t1-(2*t2)+t3; float j=t1-(3*t2)+(3*t3)-t4;
  float dt=0.08;
  float horizon=x+v*dt+0.5*a*dt*dt+(1.0/6.0)*j*dt*dt*dt;
  if(horizon<0) horizon=0; if(horizon>5) horizon=5;
  return horizon;
}

uint32_t crc32(const uint8_t* data, size_t len){
  uint32_t crc=0xFFFFFFFF;
  for(size_t i=0;i<len;i++){ crc^=data[i]; for(int j=0;j<8;j++) crc=(crc>>1) ^ (0xEDB88320 & -(crc & 1)); }
  return ~crc;
}

void loadDarwinWeights(){
  prefs.begin("darwin", true);
  if(prefs.isKey("w0")){
    darwin_weights[0]=prefs.getFloat("w0",0.30); darwin_weights[1]=prefs.getFloat("w1",0.25);
    darwin_weights[2]=prefs.getFloat("w2",0.20); darwin_weights[3]=prefs.getFloat("w3",0.15);
    darwin_weights[4]=prefs.getFloat("w4",0.10); epoch_offset=prefs.getUInt("epoch",0);
  }
  prefs.end();
}

void saveDarwinWeights(){
  prefs.begin("darwin", false);
  prefs.putFloat("w0",darwin_weights[0]); prefs.putFloat("w1",darwin_weights[1]); prefs.putFloat("w2",darwin_weights[2]);
  prefs.putFloat("w3",darwin_weights[3]); prefs.putFloat("w4",darwin_weights[4]); prefs.putUInt("epoch",epoch_offset);
  prefs.end();
}

void normalizeWeights(){
  const float MIN_W=0.05f; const float MAX_W=0.40f; const int N=5;
  for(int i=0;i<N;i++) darwin_weights[i]=constrain(darwin_weights[i],MIN_W,MAX_W);
  for(int iter=0; iter<10; iter++){
    float sum=0; for(int i=0;i<N;i++) sum+=darwin_weights[i]; float error=1.0f-sum;
    if(fabs(error)<0.0001f) break;
    int freeCount=0;
    for(int i=0;i<N;i++){ if(error>0 && darwin_weights[i]<MAX_W-0.0001f) freeCount++; if(error<0 && darwin_weights[i]>MIN_W+0.0001f) freeCount++; }
    if(freeCount==0) break;
    float delta=error/freeCount;
    for(int i=0;i<N;i++){
      if(error>0 && darwin_weights[i]<MAX_W) darwin_weights[i]+=delta;
      else if(error<0 && darwin_weights[i]>MIN_W) darwin_weights[i]+=delta;
      darwin_weights[i]=constrain(darwin_weights[i],MIN_W,MAX_W);
    }
  }
  float sum=0; for(int i=0;i<5;i++) sum+=darwin_weights[i];
  darwin_weights[0]+=1.0f-sum; darwin_weights[0]=constrain(darwin_weights[0],MIN_W,MAX_W);
}

void updateDarwinWeights(){
  bool changed=false;
  for(int i=0;i<5;i++){
    if(i==fitnessWinner) winStreak[i]++; else winStreak[i]=0;
    if(winStreak[i]>500){ darwin_weights[i]+=0.02; normalizeWeights(); winStreak[i]=0; changed=true; }
    if(winStreak[i]==0&&fitness[i]<50){ float nw=max(0.05f,darwin_weights[i]-0.001f); if(fabs(nw-darwin_weights[i])>0.0001) changed=true; darwin_weights[i]=nw; normalizeWeights(); }
  }
  if(changed && millis()-lastPrefsSave>10000){ saveDarwinWeights(); lastPrefsSave=millis(); }
}

void computeFitness(){
  long irVal=particleSensor.getIR(); long redVal=particleSensor.getRed();
  float snr=constrain(irVal/300.0,0,255);
  float perfusion=(redVal>0)?constrain((irVal/(float)redVal)*50.0,0,255):0;
  float mean=0; for(int i=0;i<5;i++) mean+=motion_history[i]; mean/=5;
  float var=0; for(int i=0;i<5;i++) var+=pow(motion_history[i]-mean,2);
  float stability=constrain(255-var*5000,0,255);
  float tempScore=(temp_c>35&&temp_c<39)?220:80;
  float predictedMotion=predictMotionPhoenix();
  float motion_penalty=constrain(predictedMotion*25.0f,0,120);
  auto weighted=[&](float snr_c,float perf_c){ return darwin_weights[0]*snr_c+darwin_weights[1]*(255-motion_penalty*2)+darwin_weights[2]*perf_c+darwin_weights[3]*tempScore+darwin_weights[4]*stability; };
  fitness[0]=constrain(weighted(snr,perfusion),0,255); fitness[1]=constrain(weighted(snr*0.8,perfusion*0.9),0,255);
  fitness[2]=constrain(weighted(200,150)-motion_penalty*0.5,0,255);
  fitness[3]=constrain(darwin_weights[0]*220+darwin_weights[1]*240+darwin_weights[2]*200+darwin_weights[3]*tempScore+darwin_weights[4]*stability,0,255);
  fitness[4]=constrain(255-predictedMotion*20,0,255);
  fitnessWinner=0; for(int i=1;i<5;i++) if(fitness[i]>fitness[fitnessWinner]) fitnessWinner=i;
  updateDarwinWeights();
}

float estimateGlucoseIndex(float nir_ratio,float ir_ratio,float skin_temp){
  float ratio_diff=nir_ratio/(ir_ratio+0.001); float temp_factor=1.0+(skin_temp-36.6)*0.02;
  float g=calib_b+(ratio_diff-1.0)*calib_m*temp_factor; return constrain(g,40,400);
}

void readAllSensorsOptimized(){
  if(max_ok){
    long irValue=particleSensor.getIR(); long redValue=particleSensor.getRed();
    if(irValue>50000){
      if(checkForBeat(irValue)){
        long delta=millis()-lastBeat; beatIntervals[intervalSpot]=delta; intervalSpot=(intervalSpot+1)%8; lastBeat=millis();
        beatsPerMinute=60.0/(delta/1000.0);
        if(beatsPerMinute<255&&beatsPerMinute>20){
          rates[rateSpot++]=(byte)beatsPerMinute; rateSpot%=8;
          beatAvg=0; for(byte x=0;x<8;x++) beatAvg+=rates[x]; beatAvg/=8;
          float meanInt=0; for(byte x=0;x<8;x++) meanInt+=beatIntervals[x]; meanInt/=8;
          float varInt=0; for(byte x=0;x<8;x++) varInt+=pow(beatIntervals[x]-meanInt,2); varInt/=8;
          hrv_ms=sqrt(varInt); if(hrv_ms<5) hrv_ms=beatAvg;
        }
      }
      if(redValue>0){ float ratio=(float)redValue/(float)irValue; spo2_pct=constrain(104.0-17.0*ratio,90,100); }
    }
  }
  if(mpu_ok) readMPU6050();
  if(mlx_ok&&millis()-lastMLXRead>2000){ temp_c=readMLX90614(); lastMLXRead=millis(); }
  float nir_ratio=0.5+(analogRead(PIN_NIR)/4095.0)*1.5; float ir_ratio=max_ok?(float)particleSensor.getIR()/100000.0:1.0;
  glucose_index=estimateGlucoseIndex(nir_ratio,ir_ratio,temp_c); gsr_ratio=nir_ratio; computeFitness();
}

void buildPacket(uint8_t* buf){
  uint32_t now=(millis()/1000)+epoch_offset;
  uint16_t hrv_raw=(uint16_t)(hrv_ms*100), tmp_raw=(uint16_t)(temp_c*100);
  uint16_t gsr_raw=(uint16_t)(gsr_ratio*1000), spo_raw=(uint16_t)(spo2_pct*100);
  uint16_t glc_raw=(uint16_t)(glucose_index), mot_raw=(uint16_t)(motion_magnitude*1000);
  memset(buf,0,44);
  buf[0]=sequenceNumber&0xFF; buf[1]=(sequenceNumber>>8)&0xFF; buf[2]=(sequenceNumber>>16)&0xFF; buf[3]=(sequenceNumber>>24)&0xFF;
  buf[4]=now&0xFF; buf[5]=(now>>8)&0xFF; buf[6]=(now>>16)&0xFF; buf[7]=(now>>24)&0xFF;
  buf[8]=hrv_raw&0xFF; buf[9]=(hrv_raw>>8)&0xFF; buf[10]=tmp_raw&0xFF; buf[11]=(tmp_raw>>8)&0xFF;
  buf[12]=gsr_raw&0xFF; buf[13]=(gsr_raw>>8)&0xFF; buf[14]=spo_raw&0xFF; buf[15]=(spo_raw>>8)&0xFF;
  buf[16]=fitness[fitnessWinner]; buf[17]=glc_raw&0xFF; buf[18]=(glc_raw>>8)&0xFF; buf[19]=mot_raw&0xFF; buf[20]=(mot_raw>>8)&0xFF;
  buf[21]=fitness[0]; buf[22]=fitness[1]; buf[23]=fitness[2]; buf[24]=fitness[3]; buf[25]=fitness[4]; buf[26]=fitnessWinner; buf[27]=0;
  uint32_t crc=crc32(buf,28); buf[28]=crc&0xFF; buf[29]=(crc>>8)&0xFF; buf[30]=(crc>>16)&0xFF; buf[31]=(crc>>24)&0xFF;
  for(int i=32;i<44;i++) buf[i]=0;
}

void setup(){
  Serial.begin(115200); delay(1000);
  loadDarwinWeights();
  pinMode(PIN_LED,OUTPUT);
  Wire.begin(PIN_SDA,PIN_SCL); delay(200);
  max_ok=initMAX30102();
  Wire.beginTransmission(ADDR_MLX90614); mlx_ok=(Wire.endTransmission()==0);
  Wire.beginTransmission(ADDR_MPU6050);
  Wire.write(0x6B);
  Wire.write(0x00);
  mpu_ok=(Wire.endTransmission()==0);
  delay(100);
  analogReadResolution(12);
  BLEDevice::init(DEVICE_NAME); BLEDevice::setMTU(64);
  pServer=BLEDevice::createServer(); pServer->setCallbacks(new MyServerCallbacks());
  BLEService* pService=pServer->createService(SERVICE_UUID);
  pCharacteristic=pService->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->addDescriptor(new BLE2902());
  pEpochChar=pService->createCharacteristic(CHARACTERISTIC_EPOCH_UUID, BLECharacteristic::PROPERTY_WRITE);
  pEpochChar->setCallbacks(new EpochCallbacks());
  pService->start();
  BLEAdvertising* pAdv=BLEDevice::getAdvertising(); pAdv->addServiceUUID(SERVICE_UUID); pAdv->setScanResponse(true); BLEDevice::startAdvertising();
}

void loop(){
  if(shouldRestartAdv){ if(millis()-lastAdvRestart>500){ pServer->startAdvertising(); shouldRestartAdv=false; lastAdvRestart=millis(); } }
  if(deviceConnected){
    readAllSensorsOptimized();
    bool shouldTX=false;
    if(abs(hrv_ms-last_hrv)>1.0||abs(temp_c-last_temp)>0.1||abs(glucose_index-last_gluc)>2.0||abs(motion_magnitude-last_motion)>0.05) shouldTX=true;
    if(millis()-lastBLETX>1000) shouldTX=true;
    if(shouldTX){
      buildPacket(packet);
      bool diff=false; for(int i=0;i<28;i++) if(packet[i]!=lastPacket[i]){diff=true; break;}
      if(diff||millis()-lastBLETX>1000){
        pCharacteristic->setValue(packet,44); pCharacteristic->notify();
        memcpy(lastPacket,packet,44); last_hrv=hrv_ms; last_temp=temp_c; last_gluc=glucose_index; last_motion=motion_magnitude;
        lastBLETX=millis(); sequenceNumber++;
      }
    }
  }
  delay(10);
}
