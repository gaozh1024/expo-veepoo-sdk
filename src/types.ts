/**
 * expo-veepoo-sdk TypeScript Type Definitions
 * Based on official Veepoo SDK Android/iOS API documentation
 */

export interface VeepooDevice {
  id: string;
  name: string;
  rssi: number;
  mac?: string;
  uuid?: string;
  address?: string;
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

export interface ScanOptions {
  timeout?: number;
  allowDuplicates?: boolean;
}

export interface ScanResult {
  device: VeepooDevice;
  timestamp: number;
}

export interface ConnectOptions {
  password?: string;
  is24Hour?: boolean;
  timeSetting?: DeviceTimeSetting;
}

export interface DeviceTimeSetting {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  system?: number;
}

export type BluetoothState = 'unknown' | 'resetting' | 'unsupported' | 'unauthorized' | 'poweredOff' | 'poweredOn';
export type BluetoothAuthorization = 'notDetermined' | 'restricted' | 'denied' | 'allowedAlways';

export interface BluetoothStatus {
  state: BluetoothState;
  stateName: string;
  authorization: BluetoothAuthorization;
  authorizationName: string;
  isScanning: boolean;
  pendingScanStart: boolean;
}

export type PasswordStatus = 'CHECK_SUCCESS' | 'CHECK_FAIL' | 'NOT_SET' | 'UNKNOWN';

export interface PasswordData {
  status: PasswordStatus;
  password: string;
  deviceNumber: number;
  deviceVersion: string;
  deviceTestVersion: string;
  isHaveDrinkData: boolean;
  isOpenNightTurnWrist: FunctionStatus;
  findPhoneFunction: FunctionStatus;
  wearDetectFunction: FunctionStatus;
}

export type FunctionStatus = 'unsupported' | 'support' | 'open' | 'close' | 'unknown';

export interface DeviceFunctionPackage1 {
  bloodPressure: FunctionStatus;
  drinking: FunctionStatus;
  sedentaryRemind: FunctionStatus;
  heartRateWarning: FunctionStatus;
  weChatSport: FunctionStatus;
  camera: FunctionStatus;
  fatigue: FunctionStatus;
  spoH: FunctionStatus;
  spo2HAdjustment: FunctionStatus;
  spoHBreathBreak: FunctionStatus;
  woman: FunctionStatus;
  alarm: FunctionStatus;
  newCalcSport: FunctionStatus;
  ambulatoryBPAdjustment: FunctionStatus;
  screenLight: FunctionStatus;
  heartRateDetect: FunctionStatus;
  nightTurnSetting: FunctionStatus;
  textAlarm: FunctionStatus;
}

export interface DeviceFunctionPackage2 {
  countDown: FunctionStatus;
  sportModelFunction: FunctionStatus;
  hidFunction: FunctionStatus;
  screenStyleFunction: FunctionStatus;
  breathFunction: FunctionStatus;
  hrvFunction: FunctionStatus;
  weatherFunction: FunctionStatus;
  screenLightTime: FunctionStatus;
  precisionSleep: FunctionStatus;
  ecgFunction: FunctionStatus;
  multSportMode: FunctionStatus;
  lowPower: FunctionStatus;
  sleepTag: number;
  watchDataDayNumber: number;
  contactMsgLength: number;
  allMsgLength: number;
  sportModelDay: number;
  screenstyle: number;
  weatherStyle: number;
  originProtocolVersion: number;
  ecgType: number;
}

export interface DeviceFunctionPackage3 {
  bigDataTranType: number;
  watchUiServerCount: number;
  watchUiCustomCount: number;
  temperatureFunction: FunctionStatus;
  temperatureType: number;
  cpuType: number;
  stressFunction: FunctionStatus;
  stressType: number;
  contactFunction: FunctionStatus;
  contactType: number;
  musicStyle: number;
  findDeviceByPhoneFunction: FunctionStatus;
  agpsFunction: FunctionStatus;
  bloodGlucoseTag: number;
  bloodGlucose: number;
  bloodGlucoseAdjusting: FunctionStatus;
  bloodGlucoseMultipleAdjusting: FunctionStatus;
  bloodGlucoseRiskAssessment: FunctionStatus;
}

export interface DeviceFunctionPackage4 {
  bloodComponent: FunctionStatus;
  bloodComponentSingleCalibration: FunctionStatus;
  bodyComponent: FunctionStatus;
  worldClock: FunctionStatus;
  autoMeasure: FunctionStatus;
  temperatureAlarm: FunctionStatus;
  wallet: FunctionStatus;
  postcard: FunctionStatus;
  gameSetting: FunctionStatus;
  aiQA: FunctionStatus;
  aiDial: FunctionStatus;
  distanceCalorieGoal: FunctionStatus;
  videoDial: FunctionStatus;
  photoAlbum: FunctionStatus;
  miniCheckup: FunctionStatus;
}

export interface DeviceFunctionPackage5 {
  textImagePush: FunctionStatus;
}

export interface DeviceFunctions {
  package1?: DeviceFunctionPackage1;
  package2?: DeviceFunctionPackage2;
  package3?: DeviceFunctionPackage3;
  package4?: DeviceFunctionPackage4;
  package5?: DeviceFunctionPackage5;
}

export type ChargeState = 'normal' | 'charging' | 'lowPressure' | 'full';

export interface BatteryInfo {
  level: number;
  percent: boolean;
  powerModel: number;
  state: number;
  bat: number;
  isLowBattery: boolean;
  chargeState?: ChargeState;
}

export type Sex = 0 | 1;

export interface PersonalInfo {
  sex: Sex;
  height: number;
  weight: number;
  age: number;
  stepAim: number;
  sleepAim: number;
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
  originalTemp?: number;
}

export interface StressData {
  stress: number;
  timestamp: number;
}

export interface BloodGlucoseData {
  glucose: number;
  timestamp: number;
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

export interface SportStepData {
  step: number;
  distance: number;
  calories: number;
  date?: string;
}

export interface HalfHourData {
  time: string;
  heartValue?: number;
  sportValue?: number;
  stepValue?: number;
  calValue?: number;
  disValue?: number;
  diastolic?: number;
  systolic?: number;
  spo2Value?: number;
  tempValue?: number;
  stressValue?: number;
  met?: number;
}

export type TestState = 'idle' | 'start' | 'testing' | 'notWear' | 'deviceBusy' | 'over' | 'error';

export interface HeartRateTestResult {
  state: TestState;
  value?: number;
}

export interface BloodPressureTestResult {
  state: TestState;
  systolic?: number;
  diastolic?: number;
  pulse?: number;
}

export interface BloodOxygenTestResult {
  state: TestState;
  value?: number;
}

export interface TemperatureTestResult {
  state: TestState;
  value?: number;
  originalValue?: number;
  progress?: number;
  enable?: boolean;
}

export type ReadState = 'idle' | 'start' | 'reading' | 'complete' | 'invalid';

export interface ReadOriginProgress {
  readState: ReadState;
  totalDays: number;
  currentDay: number;
  progress: number;
}

export interface AutoMeasureSetting {
  type: string;
  enabled: boolean;
  startTime?: string;
  endTime?: string;
  interval?: number;
}

export type Language =
  | 'chinese' | 'chineseTraditional' | 'english' | 'japanese' | 'korean'
  | 'german' | 'russian' | 'spanish' | 'italian' | 'french'
  | 'vietnamese' | 'portuguese' | 'thai' | 'polish' | 'swedish'
  | 'turkish' | 'dutch' | 'czech' | 'arabic' | 'hungarian'
  | 'greek' | 'romanian' | 'slovak' | 'indonesian' | 'brazilianPortuguese'
  | 'croatian' | 'lithuanian' | 'ukrainian' | 'hindi' | 'hebrew'
  | 'danish' | 'persian' | 'finnish' | 'malay';

export interface SocialMsgData {
  phone: FunctionStatus;
  sms: FunctionStatus;
  wechat: FunctionStatus;
  qq: FunctionStatus;
  facebook: FunctionStatus;
  twitter: FunctionStatus;
  instagram: FunctionStatus;
  linkedin: FunctionStatus;
  whatsapp: FunctionStatus;
  line: FunctionStatus;
  skype: FunctionStatus;
  email: FunctionStatus;
  calendar: FunctionStatus;
  other: FunctionStatus;
}

export interface CustomSettingData {
  [key: string]: string | number | boolean;
}

export type VeepooErrorCode =
  | 'UNKNOWN'
  | 'PERMISSION_DENIED'
  | 'CONNECTION_FAILED'
  | 'DISCONNECTION_FAILED'
  | 'BLUETOOTH_NOT_ENABLED'
  | 'DEVICE_NOT_FOUND'
  | 'OPERATION_FAILED'
  | 'SDK_NOT_INITIALIZED'
  | 'DEVICE_NOT_CONNECTED'
  | 'DEVICE_BUSY'
  | 'PASSWORD_REQUIRED'
  | 'TIMEOUT'
  | 'NOT_WEARING';

export interface VeepooError {
  code: VeepooErrorCode;
  message: string;
  deviceId?: string;
}

export type VeepooEvent =
  | 'deviceFound'
  | 'deviceConnected'
  | 'deviceDisconnected'
  | 'deviceConnectStatus'
  | 'deviceReady'
  | 'bluetoothStateChanged'
  | 'deviceFunction'
  | 'deviceVersion'
  | 'passwordData'
  | 'socialMsgData'
  | 'readOriginProgress'
  | 'readOriginComplete'
  | 'originHalfHourData'
  | 'heartRateTestResult'
  | 'bloodPressureTestResult'
  | 'bloodOxygenTestResult'
  | 'temperatureTestResult'
  | 'stressData'
  | 'bloodGlucoseData'
  | 'batteryData'
  | 'customSettingData'
  | 'dataReceived'
  | 'connectionStatusChanged'
  | 'error';

export interface VeepooEventPayload {
  deviceFound: { device: VeepooDevice; timestamp: number };
  deviceConnected: { deviceId: string; deviceVersion?: string; deviceNumber?: string };
  deviceDisconnected: { deviceId: string };
  deviceConnectStatus: { deviceId: string; status: ConnectionStatus; code?: number };
  deviceReady: { deviceId: string; isOadModel?: boolean };
  bluetoothStateChanged: BluetoothStatus;
  deviceFunction: { deviceId: string; functions: DeviceFunctions };
  deviceVersion: { deviceId: string; version: string; deviceNumber: string };
  passwordData: { deviceId: string; data: PasswordData };
  socialMsgData: { deviceId: string; data: SocialMsgData };
  readOriginProgress: { deviceId: string; progress: ReadOriginProgress };
  readOriginComplete: { deviceId: string; success: boolean };
  originHalfHourData: { deviceId: string; data: HalfHourData };
  heartRateTestResult: { deviceId: string; result: HeartRateTestResult };
  bloodPressureTestResult: { deviceId: string; result: BloodPressureTestResult };
  bloodOxygenTestResult: { deviceId: string; result: BloodOxygenTestResult };
  temperatureTestResult: { deviceId: string; result: TemperatureTestResult };
  stressData: { deviceId: string; data: StressData };
  bloodGlucoseData: { deviceId: string; data: BloodGlucoseData };
  batteryData: { deviceId: string; data: BatteryInfo };
  customSettingData: { deviceId: string; data: CustomSettingData };
  dataReceived: { deviceId: string; data: unknown };
  connectionStatusChanged: { deviceId: string; status: ConnectionStatus };
  error: VeepooError;
}

export type OperationStatus = 'success' | 'fail' | 'unknown';

export type TemperatureUnit = 'celsius' | 'fahrenheit';
export type DistanceUnit = 'metric' | 'imperial';
export type TimeFormat = '12hour' | '24hour';
export type BloodGlucoseUnit = 'mmolL' | 'mgdL';

export interface DeviceAlarm {
  id: number;
  enabled: boolean;
  hour: number;
  minute: number;
  repeat: number[];
  type?: 'normal' | 'text';
  text?: string;
}

export interface DeviceData {
  deviceId: string;
  data: unknown;
}
