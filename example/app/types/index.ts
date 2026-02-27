import type {
  HeartRateTestResult,
  BloodPressureTestResult,
  BloodOxygenTestResult,
  TemperatureTestResult,
  StressData,
  BloodGlucoseData,
  VeepooDevice,
  SportStepData,
  HalfHourData,
} from '@gaozh1024/expo-veepoo-sdk';

export { 
  HeartRateTestResult, 
  BloodPressureTestResult, 
  BloodOxygenTestResult,
  TemperatureTestResult,
  StressData,
  BloodGlucoseData,
  VeepooDevice,
  SportStepData,
  HalfHourData,
};

export interface SleepDataItem {
  date: string;
  sleepTime: string;
  wakeTime: string;
  deepSleepMinutes: number;
  lightSleepMinutes: number;
  totalSleepMinutes: number;
  sleepQuality: number;
  sleepLine: string;
  wakeUpCount: number;
}

export type TestType = 
  | 'heartRate' 
  | 'bloodPressure' 
  | 'bloodOxygen' 
  | 'temperature' 
  | 'stress' 
  | 'bloodGlucose';

export interface SavedDevice {
  id: string;
  name: string;
  mac?: string;
  uuid?: string;
  lastConnected: number;
}
