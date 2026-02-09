import { NativeModules, NativeEventEmitter, DeviceEventEmitter } from 'react-native';

import type {
  VeepooDevice,
  ConnectionStatus,
  BluetoothStatus,
  BatteryInfo,
  PersonalInfo,
  AutoMeasureSetting,
  ConnectionResult,
  VeepooEvent,
  ScanOptions,
  ConnectOptions,
  CustomSettingData,
  DailyHealthData,
  SleepData,
  HeartRateData,
  BloodPressureData,
  BloodOxygenData,
  TemperatureData,
  StressData,
  BloodGlucoseData,
  DeviceFunctions,
  VeepooErrorCode,
  ReadOriginProgress,
} from './types';

const LINKING_ERROR = `The package 'expo-veepoo-sdk' doesn't seem to be linked. Make sure:\n\n` +
  `- You rebuilt the app after installing the package\n` +
  `- You are not using Expo Go\n`;

const VeepooSDKNativeModule = NativeModules.VeepooSDKNativeModule
  ? NativeModules.VeepooSDKNativeModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export interface NativeVeepooSDKInterface {
  isBluetoothEnabled(): Promise<boolean>;
  requestPermissions(): Promise<boolean>;
  startScanning(options?: ScanOptions): Promise<void>;
  stopScanning(): Promise<void>;
  connectToDevice(deviceId: string, options?: ConnectOptions): Promise<void>;
  disconnectFromDevice(deviceId: string): Promise<void>;
  getConnectionStatus(deviceId: string): Promise<ConnectionStatus>;
  sendData(deviceId: string, data: number[]): Promise<void>;
  addListener(event: VeepooEvent): void;
  removeListeners(count: number): void;
}

export class VeepooSDK implements NativeVeepooSDKInterface {
  private eventEmitter: typeof DeviceEventEmitter;

  constructor() {
    this.eventEmitter = DeviceEventEmitter;
  }

  private emitEvent(eventName: VeepooEvent, payload?: any): void {
    this.eventEmitter.emit(`VeepooSDK_${eventName}`, payload);
  }

  async isBluetoothEnabled(): Promise<boolean> {
    try {
      const result = await VeepooSDKNativeModule.isBluetoothEnabled();
      return result;
    } catch (error) {
      console.error('[VeepooSDK] Failed to check Bluetooth status:', error);
      return false;
    }
  }

  async requestPermissions(): Promise<boolean> {
    try {
      const result = await VeepooSDKNativeModule.requestPermissions();
      return result;
    } catch (error) {
      console.error('[VeepooSDK] Failed to request permissions:', error);
      return false;
    }
  }

  async startScan(options?: ScanOptions): Promise<void> {
    try {
      const scanOptions = options || {};
      await VeepooSDKNativeModule.startScanDevice(scanOptions);
    } catch (error) {
      console.error('[VeepooSDK] Failed to start scanning:', error);
      throw error;
    }
  }

  async startScanning(options?: ScanOptions): Promise<void> {
    return this.startScan(options);
  }

  async stopScan(): Promise<void> {
    try {
      await VeepooSDKNativeModule.stopScanDevice();
    } catch (error) {
      console.error('[VeepooSDK] Failed to stop scanning:', error);
    }
  }

  async stopScanning(): Promise<void> {
    return this.stopScan();
  }

  async connectToDevice(
    deviceId: string,
    options?: ConnectOptions
  ): Promise<void> {
    try {
      const connectOptions = options || {};
      await VeepooSDKNativeModule.connectDevice(deviceId, connectOptions);
    } catch (error) {
      console.error('[VeepooSDK] Failed to connect device:', error);
      throw error;
    }
  }

  async disconnectDevice(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.disconnectDevice(deviceId);
    } catch (error) {
      console.error('[VeepooSDK] Failed to disconnect device:', error);
    }
  }

  async disconnectFromDevice(deviceId: string): Promise<void> {
    return this.disconnectDevice(deviceId);
  }

  async getConnectionStatus(deviceId: string): Promise<ConnectionStatus> {
    try {
      const result = await VeepooSDKNativeModule.getConnectionStatus(deviceId);
      return result;
    } catch (error) {
      console.error('[VeepooSDK] Failed to get connection status:', error);
      return 'disconnected';
    }
  }

  async sendData(deviceId: string, data: number[]): Promise<void> {
    try {
      await VeepooSDKNativeModule.sendData(deviceId, data);
    } catch (error) {
      console.error('[VeepooSDK] Failed to send data:', error);
      throw error;
    }
  }

  async verifyPassword(
    password: string,
    is24Hour: boolean = false
  ): Promise<boolean> {
    try {
      const result = await VeepooSDKNativeModule.verifyPassword(password, is24Hour);
      return result;
    } catch (error) {
      console.error('[VeepooSDK] Failed to verify password:', error);
      return false;
    }
  }

  async readBattery(deviceId: string): Promise<BatteryInfo> {
    try {
      const result = await VeepooSDKNativeModule.readBattery();
      return this.normalizeBatteryInfo(result);
    } catch (error) {
      console.error('[VeepooSDK] Failed to read battery:', error);
      throw error;
    }
  }

  async syncPersonalInfo(info: PersonalInfo): Promise<boolean> {
    try {
      await VeepooSDKNativeModule.syncPersonInfo(
        info.sex,
        info.height,
        info.weight,
        info.age,
        info.stepAim,
        info.sleepAim
      );
      return true;
    } catch (error) {
      console.error('[VeepooSDK] Failed to sync personal info:', error);
      return false;
    }
  }

  async readAutoMeasureSetting(deviceId: string): Promise<AutoMeasureSetting[]> {
    try {
      const result = await VeepooSDKNativeModule.readAutoMeasureSetting();
      return this.normalizeAutoMeasureSettings(result);
    } catch (error) {
      console.error('[VeepooSDK] Failed to read auto measure setting:', error);
      throw error;
    }
  }

  async modifyAutoMeasureSetting(
    deviceId: string,
    setting: AutoMeasureSetting
  ): Promise<void> {
    try {
      await VeepooSDKNativeModule.modifyAutoMeasureSetting(setting);
    } catch (error) {
      console.error('[VeepooSDK] Failed to modify auto measure setting:', error);
      throw error;
    }
  }

  async readSleepData(deviceId: string, dayOffset: number = 0): Promise<SleepData[]> {
    try {
      const result = await VeepooSDKNativeModule.readSleepData(dayOffset);
      return this.normalizeSleepData(result);
    } catch (error) {
      console.error('[VeepooSDK] Failed to read sleep data:', error);
      throw error;
    }
  }

  async readSportStep(deviceId: string, dayOffset: number = 0): Promise<DailyHealthData> {
    try {
      const result = await VeepooSDKNativeModule.readSportStep(dayOffset);
      return this.normalizeSportData(result);
    } catch (error) {
      console.error('[VeepooSDK] Failed to read sport step:', error);
      throw error;
    }
  }

  async readOriginData(dayOffset: number = 0): Promise<void> {
    try {
      await VeepooSDKNativeModule.readOriginData(dayOffset);
    } catch (error) {
      console.error('[VeepooSDK] Failed to read origin data:', error);
      throw error;
    }
  }

  async startDetectHeart(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.startDetectHeart();
    } catch (error) {
      console.error('[VeepooSDK] Failed to start heart rate detection:', error);
      throw error;
    }
  }

  async stopDetectHeart(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.stopDetectHeart();
    } catch (error) {
      console.error('[VeepooSDK] Failed to stop heart rate detection:', error);
      throw error;
    }
  }

  async startDetectBP(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.startDetectBP();
    } catch (error) {
      console.error('[VeepooSDK] Failed to start blood pressure detection:', error);
      throw error;
    }
  }

  async stopDetectBP(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.stopDetectBP();
    } catch (error) {
      console.error('[VeepooSDK] Failed to stop blood pressure detection:', error);
      throw error;
    }
  }

  async startDetectSPO2H(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.startDetectSPO2H();
    } catch (error) {
      console.error('[VeepooSDK] Failed to start SpO2 detection:', error);
      throw error;
    }
  }

  async stopDetectSPO2H(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.stopDetectSPO2H();
    } catch (error) {
      console.error('[VeepooSDK] Failed to stop SpO2 detection:', error);
      throw error;
    }
  }

  async startDetectTemperature(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.startDetectTempture();
    } catch (error) {
      console.error('[VeepooSDK] Failed to start temperature detection:', error);
      throw error;
    }
  }

  async stopDetectTemperature(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.stopDetectTempture();
    } catch (error) {
      console.error('[VeepooSDK] Failed to stop temperature detection:', error);
      throw error;
    }
  }

  async measurePressure(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.measurePressure();
    } catch (error) {
      console.error('[VeepooSDK] Failed to measure pressure:', error);
      throw error;
    }
  }

  async cancelMeasurePressure(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.cancelMeasurePressure();
    } catch (error) {
      console.error('[VeepooSDK] Failed to cancel pressure measurement:', error);
      throw error;
    }
  }

  async measureBloodGlucose(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.measureBloodGlucose();
    } catch (error) {
      console.error('[VeepooSDK] Failed to measure blood glucose:', error);
      throw error;
    }
  }

  async cancelMeasureBloodGlucose(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.cancelMeasureBloodGlucose();
    } catch (error) {
      console.error('[VeepooSDK] Failed to cancel blood glucose measurement:', error);
      throw error;
    }
  }

  async measureStress(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.measurePressure();
    } catch (error) {
      console.error('[VeepooSDK] Failed to measure stress:', error);
      throw error;
    }
  }

  async cancelMeasureStress(deviceId: string): Promise<void> {
    try {
      await VeepooSDKNativeModule.cancelMeasurePressure();
    } catch (error) {
      console.error('[VeepooSDK] Failed to cancel stress measurement:', error);
      throw error;
    }
  }

  addListener(event: VeepooEvent): void {
    VeepooSDKNativeModule.addListener(event);
  }

  removeListeners(count: number): void {
    VeepooSDKNativeModule.removeListeners(count);
  }

  private normalizeBatteryInfo(rawData: any): BatteryInfo {
    if (!rawData) {
      return {
        level: 0,
        percent: false,
        powerModel: 0,
        state: 0,
        bat: 0,
        isLowBattery: false,
      };
    }

    const batteryLevel = rawData.level ?? 0;
    const isPercent = rawData.isPercent ?? false;
    const powerModel = rawData.powerModel ?? 0;
    const state = rawData.state ?? 0;
    const bat = rawData.bat ?? 0;
    const isLowBattery = rawData.isLowBattery ?? false;

    return {
      level: batteryLevel,
      percent: isPercent,
      powerModel: powerModel,
      state: state,
      bat: bat,
      isLowBattery: isLowBattery,
    };
  }

  private normalizeAutoMeasureSettings(rawData: any): AutoMeasureSetting[] {
    if (!rawData || !Array.isArray(rawData)) {
      return [];
    }

    return rawData.map((item: any) => ({
      type: item.type || '',
      enabled: Boolean(item.enabled),
    }));
  }

  private normalizeSleepData(rawData: any): SleepData[] {
    if (!rawData || !Array.isArray(rawData)) {
      return [];
    }

    return rawData.map((item: any) => ({
      date: item.date || '',
      deepSleepDuration: item.deepSleepDuration ?? 0,
      lightSleepDuration: item.lightSleepDuration ?? 0,
      remSleepDuration: item.remSleepDuration ?? 0,
      awakeDuration: item.awakeDuration ?? 0,
      totalSleepDuration: item.totalSleepDuration ?? 0,
      sleepEfficiency: item.sleepEfficiency ?? 0,
      sleepScore: item.sleepScore,
      napDuration: item.napDuration,
    }));
  }

  private normalizeSportData(rawData: any): DailyHealthData {
    if (!rawData) {
      return {
        date: '',
        stepCount: 0,
        distance: 0,
        calories: 0,
      };
    }

    const date = rawData.date || '';
    const stepCount = rawData.Step || 0;
    const distance = parseFloat(rawData.Dis || '0');
    const calories = parseFloat(rawData.Cal || '0');

    return {
      date: date,
      stepCount,
      distance,
      calories,
    };
  }
}

export default new VeepooSDK();
