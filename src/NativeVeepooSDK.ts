import { requireNativeModule, EventSubscription } from 'expo-modules-core';

import type {
  ConnectionStatus,
  BatteryInfo,
  PersonalInfo,
  VeepooEvent,
  ScanOptions,
  ConnectOptions,
  DeviceFunctions,
  DeviceVersion,
  PasswordData,
  SocialMsgData,
  Language,
  AutoMeasureSetting,
  SleepData,
  SportStepData,
  OriginData,
} from './types.js';

const LINKING_ERROR =
  "The package 'expo-veepoo-sdk' doesn't seem to be linked. Make sure:\n\n" +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go (this module requires a development build)\n';

export interface NativeVeepooSDKInterface {
  init(): Promise<void>;
    isBluetoothEnabled(): Promise<boolean>;
    requestPermissions(): Promise<boolean>;
    startScan(options?: ScanOptions): Promise<void>;
    stopScan(): Promise<void>;
    connect(deviceId: string, options?: ConnectOptions): Promise<void>;
    disconnect(deviceId: string): Promise<void>;
    getConnectionStatus(deviceId: string): Promise<ConnectionStatus>;
    verifyPassword(password: string, is24Hour: boolean): Promise<PasswordData>;
    readBattery(): Promise<BatteryInfo>;
    syncPersonalInfo(info: PersonalInfo): Promise<boolean>;
    readDeviceFunctions(): Promise<DeviceFunctions>;
    readSocialMsgData(): Promise<SocialMsgData>;
    readDeviceVersion(): Promise<DeviceVersion>;
    startReadOriginData(): Promise<void>;
    readDeviceAllData(): Promise<boolean>;
    readSleepData(date?: string): Promise<SleepData[]>;
    readSportStepData(date?: string): Promise<SportStepData>;
    readOriginData(dayOffset?: number): Promise<OriginData[]>;
  readAutoMeasureSetting(): Promise<AutoMeasureSetting[]>;
  modifyAutoMeasureSetting(setting: Partial<AutoMeasureSetting>): Promise<AutoMeasureSetting[]>;
  setLanguage(language: Language): Promise<boolean>;
    startHeartRateTest(): Promise<void>;
    stopHeartRateTest(): Promise<void>;
    startBloodPressureTest(): Promise<void>;
    stopBloodPressureTest(): Promise<void>;
    startBloodOxygenTest(): Promise<void>;
    stopBloodOxygenTest(): Promise<void>;
    startTemperatureTest(): Promise<void>;
    stopTemperatureTest(): Promise<void>;
    startStressTest(): Promise<void>;
    stopStressTest(): Promise<void>;
    startBloodGlucoseTest(): Promise<void>;
    stopBloodGlucoseTest(): Promise<void>;
    addListener(event: VeepooEvent, listener: (payload: unknown) => void): EventSubscription;
    removeListeners(count: number): void;
}

let NativeModule: NativeVeepooSDKInterface;

try {
  NativeModule = requireNativeModule('VeepooSDK');
} catch {
  NativeModule = new Proxy({} as NativeVeepooSDKInterface, {
    get() {
      throw new Error(LINKING_ERROR);
    },
  });
}

export { NativeModule as NativeVeepooSDK };

class VeepooSDKNativeWrapper implements NativeVeepooSDKInterface {
  private native: NativeVeepooSDKInterface;

  constructor() {
    this.native = NativeModule;
  }

  async init(): Promise<void> {
    return this.native.init();
  }

  async isBluetoothEnabled(): Promise<boolean> {
    return this.native.isBluetoothEnabled();
  }

  async requestPermissions(): Promise<boolean> {
    return this.native.requestPermissions();
  }

  async startScan(options?: ScanOptions): Promise<void> {
    return this.native.startScan(options);
  }

  async stopScan(): Promise<void> {
    return this.native.stopScan();
  }

  async connect(deviceId: string, options?: ConnectOptions): Promise<void> {
    return this.native.connect(deviceId, options);
  }

  async disconnect(deviceId: string): Promise<void> {
    return this.native.disconnect(deviceId);
  }

  async getConnectionStatus(deviceId: string): Promise<ConnectionStatus> {
    return this.native.getConnectionStatus(deviceId);
  }

  async verifyPassword(password: string, is24Hour: boolean = false): Promise<PasswordData> {
    return this.native.verifyPassword(password, is24Hour);
  }

  async readBattery(): Promise<BatteryInfo> {
    return this.native.readBattery();
  }

  async syncPersonalInfo(info: PersonalInfo): Promise<boolean> {
    return this.native.syncPersonalInfo(info);
  }

  async readDeviceFunctions(): Promise<DeviceFunctions> {
    return this.native.readDeviceFunctions();
  }

  async readSocialMsgData(): Promise<SocialMsgData> {
    return this.native.readSocialMsgData();
  }

  async readDeviceVersion(): Promise<DeviceVersion> {
    return this.native.readDeviceVersion();
  }

  async startReadOriginData(): Promise<void> {
    return this.native.startReadOriginData();
  }

  async readDeviceAllData(): Promise<boolean> {
    return this.native.readDeviceAllData();
  }

  async readSleepData(date?: string): Promise<SleepData[]> {
    return this.native.readSleepData(date);
  }

  async readSportStepData(date?: string): Promise<SportStepData> {
    return this.native.readSportStepData(date);
  }

  async readOriginData(dayOffset: number = 0): Promise<OriginData[]> {
    return this.native.readOriginData(dayOffset);
  }

  async readAutoMeasureSetting(): Promise<AutoMeasureSetting[]> {
    return this.native.readAutoMeasureSetting();
  }

  async modifyAutoMeasureSetting(setting: Partial<AutoMeasureSetting>): Promise<AutoMeasureSetting[]> {
    return this.native.modifyAutoMeasureSetting(setting);
  }

  async setLanguage(language: Language): Promise<boolean> {
    return this.native.setLanguage(language);
  }

  async startHeartRateTest(): Promise<void> {
    return this.native.startHeartRateTest();
  }

  async stopHeartRateTest(): Promise<void> {
    return this.native.stopHeartRateTest();
  }

  async startBloodPressureTest(): Promise<void> {
    return this.native.startBloodPressureTest();
  }

  async stopBloodPressureTest(): Promise<void> {
    return this.native.stopBloodPressureTest();
  }

  async startBloodOxygenTest(): Promise<void> {
    return this.native.startBloodOxygenTest();
  }

  async stopBloodOxygenTest(): Promise<void> {
    return this.native.stopBloodOxygenTest();
  }

  async startTemperatureTest(): Promise<void> {
    return this.native.startTemperatureTest();
  }

  async stopTemperatureTest(): Promise<void> {
    return this.native.stopTemperatureTest();
  }

  async startStressTest(): Promise<void> {
    return this.native.startStressTest();
  }

  async stopStressTest(): Promise<void> {
    return this.native.stopStressTest();
  }

  async startBloodGlucoseTest(): Promise<void> {
    return this.native.startBloodGlucoseTest();
  }

  async stopBloodGlucoseTest(): Promise<void> {
    return this.native.stopBloodGlucoseTest();
  }

  addListener(event: VeepooEvent, listener: (payload: unknown) => void): EventSubscription {
    return this.native.addListener(event, listener);
  }

  removeListeners(count: number): void {
    this.native.removeListeners(count);
  }
}

export default new VeepooSDKNativeWrapper();
