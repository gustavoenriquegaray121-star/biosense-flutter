// ============================================================
// BioSense Band - Firmware v5.9.1 C3 PROD - Semaforo Haptico
// PHSE Altea Garay | USPTO #63/914,860
// PROD: SDA=1 SCL=0 @100kHz | MAX:1 MLX:1 MPU:1 validado en S21
// ============================================================
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <MAX30105.h>
#include <heartRate.h>
#include <Preferences.h>
#include <Adafruit_NeoPixel.h>
#include "esp_sleep.h"

#define SERVICE_UUID "A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E"
#define CHARACTERISTIC_UUID "B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6"
#define CHARACTERISTIC_EPOCH_UUID "C206F56F-3B8E-4D9B-AF4F-B2C3D4E5F6A7"
#define DEVICE_NAME "BioSense-Band"

#define PROTOCOL_VERSION 0x09
#define PACKET_SIZE 44
#define FRAG_PAYLOAD 14
#define MIN_TX_INTERVAL_MS 250
#define DARWIN_ENABLED false
#define USE_NIR_CIRCUIT false
#define ENABLE_VIB_MOTOR false

#define PIN_SDA 1
#define PIN_SCL 0
#define PIN_NIR 4
#define PIN_LED 8
#define PIN_VELCRO_LED 10
#define PIN_BAT 3
#define PIN_VIB_MOTOR 5
#define I2C_CLOCK 100000

#define ADDR_MLX90614 0x5A
#define ADDR_MPU6050 0x68
#define ADDR_MAX 0x57

#define ENABLE_BAT_SHUTDOWN false
#define BAT_CALIB 1.02f
#define BAT_LOW_V 3.3f
#define BAT_CRIT_V 3.0f
#define BAT_MAX_V 4.20f

#define PHOENIX_ENTER 0.30f
#define PHOENIX_EXIT 0.40f
#define PHOENIX_TIMEOUT_MS 30000
#define GREEN_INTERVAL 60000
#define YELLOW_INTERVAL 30000

Adafruit_NeoPixel rgbLed(1, PIN_LED, NEO_GRB + NEO_KHZ800);

enum SensorFlags : uint8_t {
  FLAG_MAX_VALID = 1 << 0, FLAG_MLX_VALID = 1 << 1, FLAG_MPU_VALID = 1 << 2,
  FLAG_BAT_VALID = 1 << 3, FLAG_HRV_VALID = 1 << 4, FLAG_OXY_VALID = 1 << 5,
  FLAG_GLUCOSE_EXPERIMENTAL= 1 << 6, FLAG_MOTION_VALID = 1 << 7
};

struct PHSE_State {
  float current_value; float stability_index; float maxDelta;
  float filtered_buffer[10]; uint8_t buf_idx; uint8_t validCount;
  unsigned long unstableSince;
  PHSE_State(float init=0, float md=15.0f) : current_value(init), stability_index(1.0f), maxDelta(md), buf_idx(0), validCount(0), unstableSince(0) {
    for(int i=0;i<10;i++) filtered_buffer[i]=init;
  }
};

PHSE_State glucoseEngine(100.0f, 8.0f);
PHSE_State sdnnEngine(72.0f, 25.0f);
MAX30105 particleSensor;
Preferences prefs;
BLEServer* pServer=nullptr;
BLECharacteristic* pCharacteristic=nullptr;
BLECharacteristic* pEpochChar=nullptr;
bool deviceConnected=false, shouldRestartAdv=false;
bool criticalBatShutdown=false, batteryLowWarning=false, haveLastBeat=false;
uint16_t negotiatedMTU=23;
uint32_t sequenceNumber=0;
uint8_t packet[PACKET_SIZE], lastPacket[PACKET_SIZE];
float sdnn_estimate_ms=0, oxygenation_estimate_pct=0;
float temp_c=0, gsr_ratio=0, experimental_index=0, bat_filtered=0;
float ax=0, ay=0, az=0, motion_magnitude=0, motion_history[5]={0};
uint8_t motion_hist_idx=0, validMotionSamples=0;
float battery_v=0;
const byte RATE_SIZE=8;
byte rates[RATE_SIZE]={0};
byte rateSpot=0, intervalSpot=0;
uint8_t validRateSamples=0;
long lastBeat=0;
float beatsPerMinute=0;
int beatAvg=0;
long beatIntervals[10]={0};
uint8_t validIntervals=0;
uint8_t fitness[5]={0}, fitnessWinner=0;
float darwin_weights[5]={0.30f,0.25f,0.20f,0.15f,0.10f};
uint16_t winStreak[5]={0};
bool max_ok=false, mlx_ok=false, mpu_ok=false;
uint8_t sensorFlags=0;
uint8_t lowBatCount=0;
unsigned long lastMLXRead=0, lastAdvRestart=0, lastBLETX=0;
unsigned long lastPrefsSave=0, lastSample=0, lastFragTime=0;
const unsigned long SAMPLE_INTERVAL=20;
float last_hrv=0, last_temp=0, last_gluc=0, last_motion=0;
uint32_t epoch_offset=0;
long latestIr=0, latestRed=0;
bool hasNewIrRed=false;
struct FragQueue { bool active; uint8_t total, next; uint8_t data[PACKET_SIZE]; uint32_t seq; uint8_t payload; } fragQ={false,0,0,{0},0,FRAG_PAYLOAD};
enum AlertLevel { ALERT_GREEN, ALERT_YELLOW, ALERT_RED };
AlertLevel currentAlert = ALERT_GREEN;
unsigned long lastGreenBlink=0, lastYellowBlink=0;
int yellowBlinkStep=0;
bool ledState=false;
unsigned long lastLedToggle=0;
uint32_t lastLedColor=0xFFFFFFFF;

void setLedColor(uint8_t r, uint8_t g, uint8_t b){
  uint32_t c=((uint32_t)r<<16)|((uint32_t)g<<8)|(uint32_t)b;
  if(c==lastLedColor) return;
  lastLedColor=c;
  rgbLed.setPixelColor(0, rgbLed.Color(r,g,b)); rgbLed.show();
}
void ledOff(){ setLedColor(0,0,0); }

AlertLevel evaluateHomeostasis() {
  if (criticalBatShutdown) return ALERT_RED;
  if ((sensorFlags & FLAG_MLX_VALID) && (temp_c > 38.5f || temp_c < 35.0f)) return ALERT_RED;
  if ((sensorFlags & FLAG_MAX_VALID) && beatAvg > 0 && (beatAvg > 130 || beatAvg < 45)) return ALERT_RED;
  if ((sensorFlags & FLAG_OXY_VALID) && oxygenation_estimate_pct < 90.0f && oxygenation_estimate_pct > 0) return ALERT_RED;
  if ((sensorFlags & FLAG_MLX_VALID) && (temp_c > 37.6f || temp_c < 35.8f)) return ALERT_YELLOW;
  if ((sensorFlags & FLAG_MAX_VALID) && beatAvg > 0 && (beatAvg > 100 || beatAvg < 55)) return ALERT_YELLOW;
  if (batteryLowWarning) return ALERT_YELLOW;
  if ((sensorFlags & FLAG_MOTION_VALID) && motion_magnitude > 1.5f) return ALERT_YELLOW;
  return ALERT_GREEN;
}

void handleSemaforoLED() {
  unsigned long now = millis();
  static AlertLevel prevAlert = ALERT_GREEN;
  if (currentAlert!= prevAlert) { ledOff(); ledState=false; yellowBlinkStep=0; prevAlert=currentAlert; }
  switch(currentAlert) {
    case ALERT_GREEN:
      if (ENABLE_VIB_MOTOR) digitalWrite(PIN_VIB_MOTOR, LOW);
      if (now - lastGreenBlink > GREEN_INTERVAL) {
        if (!ledState && now - lastLedToggle > 250) { setLedColor(0,255,0); ledState=true; lastLedToggle=now; }
        else if (ledState && now - lastLedToggle > 250) { ledOff(); ledState=false; lastLedToggle=now; lastGreenBlink=now; }
      } else { if (ledState && now - lastLedToggle > 250) { ledOff(); ledState=false; } }
      break;
    case ALERT_YELLOW:
      if (ENABLE_VIB_MOTOR) digitalWrite(PIN_VIB_MOTOR, LOW);
      if (now - lastYellowBlink > YELLOW_INTERVAL) {
        if (yellowBlinkStep==0) { setLedColor(255,255,0); ledState=true; lastLedToggle=now; yellowBlinkStep=1; }
        else if (yellowBlinkStep==1 && now-lastLedToggle>120) { ledOff(); ledState=false; lastLedToggle=now; yellowBlinkStep=2; }
        else if (yellowBlinkStep==2 && now-lastLedToggle>120) { setLedColor(255,255,0); ledState=true; lastLedToggle=now; yellowBlinkStep=3; }
        else if (yellowBlinkStep==3 && now-lastLedToggle>120) { ledOff(); ledState=false; lastLedToggle=now; yellowBlinkStep=0; lastYellowBlink=now; }
      }
      break;
    case ALERT_RED:
      setLedColor(255,0,0);
      if (ENABLE_VIB_MOTOR) digitalWrite(PIN_VIB_MOTOR, HIGH); else digitalWrite(PIN_VIB_MOTOR, LOW);
      ledState=true; break;
  }
}

void updatePHSE(PHSE_State &engine, float newValue) {
  engine.filtered_buffer[engine.buf_idx] = newValue;
  engine.buf_idx = (engine.buf_idx + 1) % 10;
  if(engine.validCount < 10) engine.validCount++;
  float avg=0; for(int i=0;i<engine.validCount;i++) avg+=engine.filtered_buffer[i]; avg/=engine.validCount;
  float delta = avg - engine.current_value;
  if (fabsf(delta) > engine.maxDelta) { avg = engine.current_value + (delta * 0.1f); engine.stability_index = max(0.0f, engine.stability_index - 0.05f); }
  else { engine.stability_index = min(1.0f, engine.stability_index + 0.01f); }
  engine.current_value = avg;
  if(engine.unstableSince==0){ if(engine.stability_index < PHOENIX_ENTER) engine.unstableSince=millis(); }
  else { if(engine.stability_index > PHOENIX_EXIT) engine.unstableSince=0; }
}
void checkPhoenixRebirth(PHSE_State &engine){
  if(engine.unstableSince!=0 && millis()-engine.unstableSince>PHOENIX_TIMEOUT_MS){
    float rebirth=0; uint8_t cnt=engine.validCount>0?engine.validCount:1;
    for(uint8_t i=0;i<cnt;i++) rebirth+=engine.filtered_buffer[i]; rebirth/=cnt;
    engine.current_value=rebirth; engine.stability_index=0.5f; engine.unstableSince=0;
  }
}
class EpochCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    String val = pChar->getValue();
    if (val.length() >= 4) {
      uint32_t epoch = (uint32_t)((uint8_t)val[0]|((uint8_t)val[1]<<8)|((uint8_t)val[2]<<16)|((uint8_t)val[3]<<24));
      epoch_offset = epoch - (millis()/1000);
    }
  }
};
class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pSrv) override { deviceConnected=true; negotiatedMTU=pSrv->getPeerMTU(pSrv->getConnId()); fragQ.active=false; fragQ.next=0; fragQ.total=0; lastFragTime=millis(); }
  void onDisconnect(BLEServer* pSrv) override { deviceConnected=false; shouldRestartAdv=true; negotiatedMTU=23; fragQ.active=false; }
};
uint32_t crc32(const uint8_t* data, size_t len){ uint32_t crc=0xFFFFFFFF; for(size_t i=0;i<len;i++){ crc^=data[i]; for(int j=0;j<8;j++) crc=(crc>>1)^((crc&1)?0xEDB88320:0); } return ~crc; }
void loadDarwinWeights(){ prefs.begin("darwin",true); if(prefs.isKey("w0")){ darwin_weights[0]=prefs.getFloat("w0",0.30f); darwin_weights[1]=prefs.getFloat("w1",0.25f); darwin_weights[2]=prefs.getFloat("w2",0.20f); darwin_weights[3]=prefs.getFloat("w3",0.15f); darwin_weights[4]=prefs.getFloat("w4",0.10f); } prefs.end(); }
void saveDarwinWeights(){ prefs.begin("darwin",false); prefs.putFloat("w0",darwin_weights[0]); prefs.putFloat("w1",darwin_weights[1]); prefs.putFloat("w2",darwin_weights[2]); prefs.putFloat("w3",darwin_weights[3]); prefs.putFloat("w4",darwin_weights[4]); prefs.end(); }
void normalizeWeights(){
  const float MIN_W=0.05f, MAX_W=0.40f;
  for(int i=0;i<5;i++) darwin_weights[i]=constrain(darwin_weights[i],MIN_W,MAX_W);
  for(int iter=0;iter<10;iter++){
    float sum=0; for(int i=0;i<5;i++) sum+=darwin_weights[i]; float err=1.0f-sum; if(fabsf(err)<0.0001f) break;
    int freeC=0; for(int i=0;i<5;i++){ if(err>0 && darwin_weights[i]<MAX_W-0.0001f) freeC++; if(err<0 && darwin_weights[i]>MIN_W+0.0001f) freeC++; }
    if(freeC==0) break; float d=err/freeC;
    for(int i=0;i<5;i++){ if(err>0 && darwin_weights[i]<MAX_W) darwin_weights[i]+=d; else if(err<0 && darwin_weights[i]>MIN_W) darwin_weights[i]+=d; darwin_weights[i]=constrain(darwin_weights[i],MIN_W,MAX_W); }
  }
}
void updateDarwinWeights(){
  if(!DARWIN_ENABLED) return; bool changed=false;
  for(int i=0;i<5;i++){ if(i==fitnessWinner) winStreak[i]++; else winStreak[i]=0; if(winStreak[i]>500){ darwin_weights[i]+=0.02f; normalizeWeights(); winStreak[i]=0; changed=true; } }
  if(changed && millis()-lastPrefsSave>10000){ saveDarwinWeights(); lastPrefsSave=millis(); }
}
void setupSensorMAX(){
  for(int tries=0; tries<3; tries++){
    Wire.beginTransmission(ADDR_MAX);
    if(Wire.endTransmission()==0){
      if(particleSensor.begin(Wire, I2C_SPEED_STANDARD)){
        particleSensor.setup(0x1F,4,2,100,411,4096);
        particleSensor.setPulseAmplitudeRed(0x0A);
        particleSensor.setPulseAmplitudeIR(0x0A);
        particleSensor.setPulseAmplitudeGreen(0);
        max_ok=true; return;
      }
    }
    delay(200);
  }
  max_ok=false;
}
bool setupMPU6050(){
  for(int tries=0; tries<3; tries++){
    Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x6B); Wire.write(0x00);
    if(Wire.endTransmission()!=0){ delay(200); continue; }
    delay(200);
    Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x75);
    if(Wire.endTransmission(false)!=0){ delay(200); continue; }
    if(Wire.requestFrom((uint8_t)ADDR_MPU6050,(uint8_t)1)!=1){ delay(200); continue; }
    uint8_t who=Wire.read();
    if(who==0x68 || who==0x70 || who==0x71){
      Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x1C); Wire.write(0x00); Wire.endTransmission(); delay(20);
      Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x1A); Wire.write(0x03); Wire.endTransmission(); delay(20);
      Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x19); Wire.write(0x04); Wire.endTransmission();
      mpu_ok=true; return true;
    }
    delay(200);
  }
  mpu_ok=false; return false;
}
float readMLX90614(){
  Wire.beginTransmission(ADDR_MLX90614); Wire.write(0x07); if(Wire.endTransmission(false)!=0) return NAN;
  if(Wire.requestFrom((uint8_t)ADDR_MLX90614,(uint8_t)3)!=3) return NAN;
  uint8_t lsb=Wire.read(), msb=Wire.read(); Wire.read(); uint16_t raw=((uint16_t)msb<<8)|lsb; if(raw==0xFFFF) return NAN;
  float t=raw*0.02f-273.15f; if(t<30.0f||t>45.0f) return NAN; return t;
}
void readMPU6050(){
  Wire.beginTransmission(ADDR_MPU6050); Wire.write(0x3B); if(Wire.endTransmission(false)!=0) return;
  if(Wire.requestFrom((uint8_t)ADDR_MPU6050,(uint8_t)6)!=6) return;
  int16_t ax_raw=(Wire.read()<<8)|Wire.read(); int16_t ay_raw=(Wire.read()<<8)|Wire.read(); int16_t az_raw=(Wire.read()<<8)|Wire.read();
  ax=ax_raw/16384.0f; ay=ay_raw/16384.0f; az=az_raw/16384.0f;
  motion_magnitude=fabsf(sqrtf(ax*ax+ay*ay+az*az)-1.0f);
  motion_history[motion_hist_idx]=motion_magnitude; motion_hist_idx=(motion_hist_idx+1)%5; if(validMotionSamples<5) validMotionSamples++;
}
float predictMotionPhoenix(){
  if(validMotionSamples<4) return motion_magnitude;
  int idx1=(motion_hist_idx+4)%5, idx2=(motion_hist_idx+3)%5, idx3=(motion_hist_idx+2)%5, idx4=(motion_hist_idx+1)%5;
  float t1=motion_history[idx1], t2=motion_history[idx2], t3=motion_history[idx3], t4=motion_history[idx4];
  float x=t1, v=t1-t2; float a=t1-2*t2+t3, j=t1-3*t2+3*t3-t4; float dt=SAMPLE_INTERVAL/1000.0f;
  return constrain(x+v*dt+0.5f*a*dt*dt+(1.0f/6.0f)*j*dt*dt*dt, 0.0f, 5.0f);
}
void computeFitness(long irVal, long redVal, bool hasNew){
  if(!DARWIN_ENABLED){ if(!hasNew) return; float snr=constrain(irVal/300.0f,0.0f,255.0f); for(int i=0;i<5;i++) fitness[i]=(uint8_t)snr; fitnessWinner=0; return; }
  if(!hasNew) return;
  float snr=constrain(irVal/300.0f,0.0f,255.0f), perf=0; if(redVal>0) perf=constrain((irVal/(float)redVal)*50.0f,0.0f,255.0f);
  float mean=0; if(validMotionSamples>0){ for(int i=0;i<validMotionSamples;i++) mean+=motion_history[i]; mean/=validMotionSamples; }
  float var=0; if(validMotionSamples>1){ for(int i=0;i<validMotionSamples;i++) var+=powf(motion_history[i]-mean,2); var/=validMotionSamples; }
  float stability=constrain(255.0f-var*5000.0f,0.0f,255.0f); float tempScore=(temp_c>35&&temp_c<39)?220:80;
  float pred=predictMotionPhoenix(), penalty=constrain(pred*25,0,120);
  auto w=[&](float sc,float pc){ return darwin_weights[0]*sc+darwin_weights[1]*(255-penalty*2)+darwin_weights[2]*pc+darwin_weights[3]*tempScore+darwin_weights[4]*stability; };
  fitness[0]=(uint8_t)constrain(w(snr,perf),0.0f,255.0f); fitness[1]=(uint8_t)constrain(w(snr*0.8f,perf*0.9f),0.0f,255.0f);
  fitness[2]=(uint8_t)constrain(w(200,150)-penalty*0.5f,0.0f,255.0f);
  fitness[3]=(uint8_t)constrain(darwin_weights[0]*220+darwin_weights[1]*240+darwin_weights[2]*200+darwin_weights[3]*tempScore+darwin_weights[4]*stability,0.0f,255.0f);
  fitness[4]=(uint8_t)constrain(255-pred*20,0.0f,255.0f); fitnessWinner=0; for(int i=1;i<5;i++) if(fitness[i]>fitness[fitnessWinner]) fitnessWinner=i; updateDarwinWeights();
}
float estimateExperimentalIndex(float nir_ratio,float ir_ratio,float skin_temp){
  nir_ratio=constrain(nir_ratio,0.01f,2.0f); ir_ratio=constrain(ir_ratio,0.01f,1.0f); float diff=nir_ratio/ir_ratio;
  float tf=1.0f+(skin_temp-36.6f)*0.02f; float g=80.0f+(diff-1.0f)*200.0f*tf; return constrain(g,40,400);
}
float computeMedianInterval(){
  if(validIntervals==0) return 0; long sorted[10]; for(byte i=0;i<validIntervals;i++) sorted[i]=beatIntervals[i];
  for(byte i=0;i<validIntervals-1;i++) for(byte j=i+1;j<validIntervals;j++) if(sorted[i]>sorted[j]){ long t=sorted[i]; sorted[i]=sorted[j]; sorted[j]=t; }
  if(validIntervals % 2 == 1) return sorted[validIntervals/2]; return (sorted[validIntervals/2-1]+sorted[validIntervals/2])/2.0f;
}
void readAllSensorsOptimized(){
  sensorFlags=0; hasNewIrRed=false; batteryLowWarning=false;
  if(USE_NIR_CIRCUIT) sensorFlags|=FLAG_GLUCOSE_EXPERIMENTAL;
  if(max_ok){
    particleSensor.check(); long curIr=0,curRed=0; bool hasNew=false;
    while(particleSensor.available()){
      curRed=particleSensor.getRed(); curIr=particleSensor.getIR(); particleSensor.nextSample(); hasNew=true;
      latestIr=curIr; latestRed=curRed; hasNewIrRed=true;
      bool beatNow=checkForBeat(curIr);
      if(curIr>50000 && beatNow){
        long now=millis(); if(!haveLastBeat){ lastBeat=now; haveLastBeat=true; } else {
          long delta=now-lastBeat; lastBeat=now;
          if(delta>300 && delta<3000){
            bool isOutlier=false; if(validIntervals>=3){ float median=computeMedianInterval(); if(median>0 && fabsf(delta-median)>median*0.20f) isOutlier=true; }
            if(!isOutlier){
              beatIntervals[intervalSpot]=delta; intervalSpot=(intervalSpot+1)%10; if(validIntervals<10) validIntervals++;
              beatsPerMinute=60000.0f/delta;
              if(beatsPerMinute>=20&&beatsPerMinute<=255){
                rates[rateSpot]=(byte)round(beatsPerMinute); rateSpot=(rateSpot+1)%RATE_SIZE; if(validRateSamples<RATE_SIZE) validRateSamples++;
                beatAvg=0; for(byte x=0;x<validRateSamples;x++) beatAvg+=rates[x]; beatAvg/=max(1,(int)validRateSamples);
                if(validIntervals==10){
                  float mInt=0; for(byte x=0;x<10;x++) mInt+=beatIntervals[x]; mInt/=10.0f;
                  float v=0; for(byte x=0;x<10;x++) v+=powf(beatIntervals[x]-mInt,2); v/=10.0f;
                  float sdnn=sqrtf(v); if(sdnn>=5.0f&&sdnn<300.0f){ updatePHSE(sdnnEngine,sdnn); sdnn_estimate_ms=sdnnEngine.current_value; }
                }
              }
            }
          }
        }
      }
    }
    if(hasNew && latestIr>1000){
      sensorFlags|=FLAG_MAX_VALID; static float red_dc=0, ir_dc=0;
      red_dc=red_dc*0.95f+latestRed*0.05f; ir_dc=ir_dc*0.95f+latestIr*0.05f;
      if(ir_dc>5000&&red_dc>1000){ if(latestRed>0){ float perf=constrain((latestIr/(float)latestRed)*50.0f,0.0f,255.0f); float r=(latestRed/red_dc)/(latestIr/ir_dc); float oxy=constrain(110.0f-25.0f*r,0.0f,100.0f); if(motion_magnitude<0.15f&&perf>30.0f){ oxygenation_estimate_pct=oxy; sensorFlags|=FLAG_OXY_VALID; } } }
    }
  }
  if(mpu_ok){ readMPU6050(); if(validMotionSamples>=3) sensorFlags|=FLAG_MPU_VALID|FLAG_MOTION_VALID; }
  if(mlx_ok&&millis()-lastMLXRead>2000){ float nt=readMLX90614(); if(!isnan(nt)){ if(temp_c==0) temp_c=nt; else temp_c=temp_c*0.7f+nt*0.3f; sensorFlags|=FLAG_MLX_VALID; } lastMLXRead=millis(); }
  if(validIntervals>=10&&sdnn_estimate_ms>0) sensorFlags|=FLAG_HRV_VALID; checkPhoenixRebirth(sdnnEngine);
  if(USE_NIR_CIRCUIT){ float nir_raw=analogRead(PIN_NIR)/4095.0f; float nir_ratio=0.5f+nir_raw*1.5f; float ir_ratio=constrain((float)latestIr/100000.0f,0.01f,1.0f); float raw=estimateExperimentalIndex(nir_ratio,ir_ratio,temp_c); updatePHSE(glucoseEngine,raw); experimental_index=glucoseEngine.current_value; gsr_ratio=nir_ratio; checkPhoenixRebirth(glucoseEngine); }
  uint32_t mv=analogReadMilliVolts(PIN_BAT); float v_bat=mv*2.0f/1000.0f*BAT_CALIB;
  if(bat_filtered==0) bat_filtered=v_bat; else bat_filtered=bat_filtered*0.90f+v_bat*0.10f;
  if(bat_filtered>0.5f&&bat_filtered<=BAT_MAX_V){ if(bat_filtered>=BAT_CRIT_V){ battery_v=bat_filtered; lowBatCount=0; sensorFlags|=FLAG_BAT_VALID; if(bat_filtered<BAT_LOW_V) batteryLowWarning=true; } else { battery_v=bat_filtered; if(lowBatCount<255) lowBatCount++; if(ENABLE_BAT_SHUTDOWN && lowBatCount>=50) criticalBatShutdown=true; } }
  computeFitness(latestIr,latestRed,hasNewIrRed); currentAlert=evaluateHomeostasis();
}
void buildPacket(uint8_t* buf){
  uint32_t now=(millis()/1000)+epoch_offset;
  uint16_t hrv_raw=(sensorFlags&FLAG_HRV_VALID)?(uint16_t)(sdnn_estimate_ms*100.0f):0;
  uint16_t tmp_raw=(sensorFlags&FLAG_MLX_VALID)?(uint16_t)(temp_c*100.0f):0;
  uint16_t spo_raw=(sensorFlags&FLAG_OXY_VALID)?(uint16_t)(oxygenation_estimate_pct*100.0f):0;
  uint16_t glc_raw=(sensorFlags&FLAG_GLUCOSE_EXPERIMENTAL)?(uint16_t)experimental_index:0;
  uint16_t mot_raw=(sensorFlags&FLAG_MOTION_VALID)?(uint16_t)(motion_magnitude*1000.0f):0;
  uint16_t bat_raw=(sensorFlags&FLAG_BAT_VALID||criticalBatShutdown)?(uint16_t)(battery_v*1000.0f):0;
  memset(buf,0,PACKET_SIZE); buf[0]=PROTOCOL_VERSION; buf[1]=sensorFlags;
  buf[2]=sequenceNumber&0xFF; buf[3]=(sequenceNumber>>8)&0xFF; buf[4]=(sequenceNumber>>16)&0xFF; buf[5]=(sequenceNumber>>24)&0xFF;
  buf[6]=now&0xFF; buf[7]=(now>>8)&0xFF; buf[8]=(now>>16)&0xFF; buf[9]=(now>>24)&0xFF;
  buf[10]=hrv_raw&0xFF; buf[11]=(hrv_raw>>8)&0xFF; buf[12]=tmp_raw&0xFF; buf[13]=(tmp_raw>>8)&0xFF; buf[14]=0; buf[15]=0;
  buf[16]=spo_raw&0xFF; buf[17]=(spo_raw>>8)&0xFF; buf[18]=fitness[fitnessWinner]; buf[19]=glc_raw&0xFF; buf[20]=(glc_raw>>8)&0xFF;
  buf[21]=mot_raw&0xFF; buf[22]=(mot_raw>>8)&0xFF; for(int i=0;i<5;i++) buf[23+i]=fitness[i]; buf[28]=fitnessWinner;
  buf[29]=bat_raw&0xFF; buf[30]=(bat_raw>>8)&0xFF; buf[31]=beatAvg&0xFF; buf[32]=(uint8_t)beatsPerMinute; buf[33]=batteryLowWarning?1:0; buf[34]=(uint8_t)currentAlert;
  for(int i=35;i<40;i++) buf[i]=0; uint32_t crc=crc32(buf,40); buf[40]=crc&0xFF; buf[41]=(crc>>8)&0xFF; buf[42]=(crc>>16)&0xFF; buf[43]=(crc>>24)&0xFF;
}
void refreshMTU(){ if(pServer && deviceConnected){ uint16_t m=pServer->getPeerMTU(pServer->getConnId()); if(m>=23) negotiatedMTU=m; } }
void startFragmented(){
  refreshMTU(); uint16_t maxPayload=negotiatedMTU>3?negotiatedMTU-3:20; if(maxPayload<=6){ fragQ.active=false; return; }
  uint8_t payload=min((uint16_t)FRAG_PAYLOAD,(uint16_t)(maxPayload-6)); memcpy(fragQ.data,packet,PACKET_SIZE);
  fragQ.seq=sequenceNumber; fragQ.payload=payload; fragQ.total=(PACKET_SIZE+payload-1)/payload; fragQ.next=0; fragQ.active=true;
}
void pumpFragment(){
  if(!fragQ.active) return; if(!deviceConnected){ fragQ.active=false; return; } if(millis()-lastFragTime<10) return;
  if(fragQ.payload==0||fragQ.total==0||fragQ.next>=fragQ.total){ fragQ.active=false; return; }
  uint16_t maxPayload=negotiatedMTU>3?negotiatedMTU-3:20; if(maxPayload<=6){ fragQ.active=false; return; }
  uint8_t curPayload=min((uint16_t)FRAG_PAYLOAD,(uint16_t)(maxPayload-6));
  if(curPayload!=fragQ.payload){ fragQ.payload=curPayload; fragQ.total=(PACKET_SIZE+curPayload-1)/curPayload; fragQ.next=0; }
  if(negotiatedMTU>=PACKET_SIZE+3){ pCharacteristic->setValue(fragQ.data,PACKET_SIZE); pCharacteristic->notify(); fragQ.active=false; lastFragTime=millis(); return; }
  uint16_t off=fragQ.next*fragQ.payload; if(off>=PACKET_SIZE){ fragQ.active=false; return; }
  uint8_t frag[20]; frag[0]=fragQ.seq&0xFF; frag[1]=(fragQ.seq>>8)&0xFF; frag[2]=(fragQ.seq>>16)&0xFF; frag[3]=(fragQ.seq>>24)&0xFF; frag[4]=fragQ.next; frag[5]=fragQ.total;
  uint8_t len=min((uint16_t)fragQ.payload,(uint16_t)(PACKET_SIZE-off)); memcpy(&frag[6],&fragQ.data[off],len);
  pCharacteristic->setValue(frag,len+6); pCharacteristic->notify(); fragQ.next++; lastFragTime=millis(); if(fragQ.next>=fragQ.total) fragQ.active=false;
}
void setup(){
  Serial.begin(115200); delay(1000); loadDarwinWeights();
  rgbLed.begin(); rgbLed.setBrightness(50); ledOff();
  pinMode(PIN_VELCRO_LED,OUTPUT);digitalWrite(PIN_VELCRO_LED,LOW);
  pinMode(PIN_VIB_MOTOR,OUTPUT); digitalWrite(PIN_VIB_MOTOR,LOW);
  pinMode(PIN_NIR,INPUT); pinMode(PIN_BAT,INPUT);
  analogReadResolution(12); analogSetAttenuation(ADC_11db);
  Wire.begin(PIN_SDA,PIN_SCL, I2C_CLOCK);
  Wire.setClock(I2C_CLOCK);
  delay(300);
  lastBeat=millis(); lastFragTime=millis(); memset(lastPacket,0xFF,PACKET_SIZE); bat_filtered=0;
  setupSensorMAX();
  Wire.beginTransmission(ADDR_MLX90614); mlx_ok=(Wire.endTransmission()==0);
  setupMPU6050();
  Serial.printf("MAX:%d MLX:%d MPU:%d\n",max_ok,mlx_ok,mpu_ok);
  BLEDevice::init(DEVICE_NAME); pServer=BLEDevice::createServer(); pServer->setCallbacks(new MyServerCallbacks());
  BLEService* pService=pServer->createService(SERVICE_UUID);
  pCharacteristic=pService->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ|BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->addDescriptor(new BLE2902());
  pEpochChar=pService->createCharacteristic(CHARACTERISTIC_EPOCH_UUID, BLECharacteristic::PROPERTY_WRITE); pEpochChar->setCallbacks(new EpochCallbacks());
  pService->start(); BLEAdvertising* pAdv=BLEDevice::getAdvertising(); pAdv->addServiceUUID(SERVICE_UUID); pAdv->setScanResponse(true); BLEDevice::startAdvertising();
  setLedColor(0,255,0); delay(300); ledOff(); delay(200); setLedColor(255,255,0); delay(300); ledOff(); delay(200); setLedColor(255,0,0); delay(300); ledOff();
  Serial.printf("BioSense-Band v5.9.1 C3 PROD - Listo\n");
}
void loop(){
  if(shouldRestartAdv&&millis()-lastAdvRestart>500){ BLEDevice::startAdvertising(); shouldRestartAdv=false; lastAdvRestart=millis(); }
  if(criticalBatShutdown){ if(deviceConnected){ pServer->disconnect(pServer->getConnId()); delay(200); } ledOff(); digitalWrite(PIN_VIB_MOTOR,LOW); esp_deep_sleep_start(); }
  if(millis()-lastSample>=SAMPLE_INTERVAL){
    lastSample=millis(); readAllSensorsOptimized();
    if(deviceConnected &&!fragQ.active && millis()-lastBLETX>=MIN_TX_INTERVAL_MS){
      bool shouldTX=(fabsf(sdnn_estimate_ms-last_hrv)>1.0f||fabsf(temp_c-last_temp)>0.1f||fabsf(experimental_index-last_gluc)>2.0f||fabsf(motion_magnitude-last_motion)>0.05f||millis()-lastBLETX>1000);
      if(shouldTX){ buildPacket(packet); bool diff=false; for(int i=10;i<40;i++) if(packet[i]!=lastPacket[i]){ diff=true; break; } if(diff||millis()-lastBLETX>1000){ startFragmented(); memcpy(lastPacket,packet,PACKET_SIZE); last_hrv=sdnn_estimate_ms; last_temp=temp_c; last_gluc=experimental_index; last_motion=motion_magnitude; lastBLETX=millis(); sequenceNumber++; } }
    }
  }
  pumpFragment(); handleSemaforoLED();
}
