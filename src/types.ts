import { NativeModules, NativeEventEmitter, DeviceEventEmitter } from 'react-native';

export interface VeepooDevice {
  id: string;
  name: string;
  rssi: number;
  mac?: string;
  uuid?: string;
}

export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'disconnecting' | 'ready' | 'error';

export interface ConnectionResult {
  status: ConnectionStatus;
  code?: number;
  mac: string;
  isOadModel?: boolean;
  deviceVersion?: string;
  deviceNumber?: string;
}

export interface BluetoothStatus {
  state: 'unknown' | 'resetting' | 'unsupported' | 'unauthorized' | 'poweredOff' | 'poweredOn';
  stateName: string;
  authorization: 'notDetermined' | 'restricted' | 'denied' | 'allowedAlways';
  authorizationName: string;
  isScanning: boolean;
  pendingScanStart: boolean;
}

export interface DeviceFunctions {
  heartDetect: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  bp: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  drink: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  longseat: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  heartWarning: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  weChatSport: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  camera: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  fatigue: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  spoH: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  spo2Adjustment: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  spo2BreathBreak: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  woman: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  alarm: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  newCalcSport: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  countdown: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  angioAdjustment: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  screenLight: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  heartRateDetect: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  sportMode: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  nightTurnSetting: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  hid: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  screenStyle: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  breath: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  hrv: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  weather: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  screenLightTime: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  precisionSleep: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  resetData: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  ecg: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  multSportMode: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  lowPower: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  findDeviceByPhone: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  agps: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  temperature: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  textAlarm: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  bloodGlucose: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  bloodGlucoseAdjusting: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  bloodComponent: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  bodyComponent: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  worldClock: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  autoMeasure: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  temperatureAlarm: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  wallet: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  postcard: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  game: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  aiQA: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  aiDial: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  photoAlbum: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  miniCheckup: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  textImagePush: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  met: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
  stress: 'unsupported' | 'support' | 'open' | 'close' | 'unknown';
}

export interface BatteryInfo {
  level: number;
  percent: boolean;
  powerModel: number;
  state: number;
  bat: number;
  isLowBattery: boolean;
}

export interface PersonalInfo {
  sex: 0 | 1;
  height: number;
  weight: number;
  age: number;
  stepAim: number;
  sleepAim: number;
}

export interface AutoMeasureSetting {
  type: string;
  enabled: boolean;
}

export interface SleepData {
  date: string;
  deepSleepDuration: number;
  lightSleepDuration: number;
  remSleepDuration: number;
  awakeDuration: number;
  totalSleepDuration: number;
  sleepEfficiency: number;
  sleepScore?: number;
  napDuration?: number;
}

export interface HeartRateData {
  value: number;
  timestamp: number;
}

export interface BloodPressureData {
  systolic: number;
  diastolic: number;
  pulse: number;
  timestamp: number;
}

export interface BloodOxygenData {
  spo2: number;
  timestamp: number;
}

export interface TemperatureData {
  temperature: number;
  timestamp: number;
  isSurface?: boolean;
}

export interface StressData {
  stress: number;
  timestamp: number;
}

export interface BloodGlucoseData {
  glucose: number;
  timestamp: number;
}

export interface DailyHealthData {
  date: string;
  stepCount?: number;
  distance?: number;
  calories?: number;
  heartRate?: number;
  bloodPressure?: BloodPressureData;
  bloodOxygen?: BloodOxygenData;
  temperature?: TemperatureData;
  stress?: StressData;
  bloodGlucose?: BloodGlucoseData;
}

export interface CustomSettingData {
  [key: string]: string | number | boolean;
}

export interface ScanOptions {
  timeout?: number;
  allowDuplicates?: boolean;
}

export interface ConnectOptions {
  password?: string;
  is24Hour?: boolean;
}

export interface ReadOriginProgress {
  readState: 'idle' | 'start' | 'reading' | 'complete' | 'invalid';
  totalDays: number;
  currentDay: number;
  progress: number;
}

export interface DeviceData {
  deviceId: string;
  data: any;
}

export interface ScanResult {
  device: VeepooDevice;
  timestamp: number;
}

export type VeepooErrorCode =
  | 'UNKNOWN'
  | 'PERMISSION_DENIED'
  | 'CONNECTION_FAILED'
  | 'DISCONNECTION_FAILED'
  | 'BLUETOOTH_NOT_ENABLED'
  | 'DEVICE_NOT_FOUND'
  | 'OPERATION_FAILED';

export type VeepooEvent =
  | 'deviceFound'
  | 'deviceConnected'
  | 'deviceDisconnected'
  | 'deviceConnectStatus'
  | 'deviceReady'
  | 'bluetoothStateChanged'
  | 'deviceFunction'
  | 'deviceVersion'
  | 'readOriginProgress'
  | 'readOriginComplete'
  | 'originHalfHourData'
  | 'heartRateData'
  | 'bloodPressureData'
  | 'bloodOxygenData'
  | 'temperatureData'
  | 'stressData'
  | 'bloodGlucoseData'
  | 'batteryData'
  | 'customSettingData'
  | 'dataReceived'
  | 'connectionStatusChanged'
  | 'error';

export type VeepooEventPayload = {
  [K in VeepooEvent]: any;
};
