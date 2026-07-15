import { requireNativeModule, EventSubscription } from 'expo-modules-core';

import type {
  ConnectionStatus,
  PersonalInfo,
  SmartWearableLinkEvent,
  ScanOptions,
  ConnectOptions,
  Language,
  AutoMeasureSetting,
  PermissionsResult,
} from './types.js';

const LINKING_ERROR =
  "The package 'expo-smart-wearable-link' doesn't seem to be linked. Make sure:\n\n" +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go (this module requires a development build)\n';

export interface NativeSmartWearableLinkSDKInterface {
  init(): Promise<void>;
  isBluetoothEnabled(): Promise<boolean>;
  requestPermissions(): Promise<PermissionsResult>;
  startScan(options?: ScanOptions): Promise<void>;
  stopScan(): Promise<void>;
  connect(deviceId: string, options?: ConnectOptions): Promise<void>;
  disconnect(deviceId: string): Promise<void>;
  getConnectionStatus(deviceId: string): Promise<ConnectionStatus>;
  verifyPassword(password: string, is24Hour: boolean): Promise<unknown>;
  readBattery(): Promise<unknown>;
  syncPersonalInfo(info: PersonalInfo): Promise<boolean>;
  readDeviceFunctions(): Promise<unknown>;
  readSocialMsgData(): Promise<unknown>;
  readDeviceVersion(): Promise<unknown>;
  startReadOriginData(): Promise<void>;
  readDeviceAllData(): Promise<boolean>;
  readSleepData(date?: string): Promise<unknown>;
  readSportStepData(date?: string): Promise<unknown>;
  readOriginData(dayOffset?: number): Promise<unknown>;
  readDaySummaryData(dayOffset?: number): Promise<unknown>;
  readAutoMeasureSetting(): Promise<unknown>;
  modifyAutoMeasureSetting(setting: Partial<AutoMeasureSetting>): Promise<unknown>;
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
  addListener(event: SmartWearableLinkEvent, listener: (payload: unknown) => void): EventSubscription;
  removeListeners(count: number): void;
}

let NativeModule: NativeSmartWearableLinkSDKInterface;

try {
  NativeModule = requireNativeModule('SmartWearableLinkSDK');
} catch {
  NativeModule = new Proxy({} as NativeSmartWearableLinkSDKInterface, {
    get() {
      throw new Error(LINKING_ERROR);
    },
  });
}

export { NativeModule as NativeSmartWearableLinkSDK };

class SmartWearableLinkSDKNativeWrapper implements NativeSmartWearableLinkSDKInterface {
  private native: NativeSmartWearableLinkSDKInterface;

  constructor() {
    this.native = NativeModule;
  }

  async init(): Promise<void> {
    return this.native.init();
  }

  async isBluetoothEnabled(): Promise<boolean> {
    return this.native.isBluetoothEnabled();
  }

  async requestPermissions(): Promise<PermissionsResult> {
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

  async verifyPassword(password: string, is24Hour: boolean = false): Promise<unknown> {
    return this.native.verifyPassword(password, is24Hour);
  }

  async readBattery(): Promise<unknown> {
    return this.native.readBattery();
  }

  async syncPersonalInfo(info: PersonalInfo): Promise<boolean> {
    return this.native.syncPersonalInfo(info);
  }

  async readDeviceFunctions(): Promise<unknown> {
    return this.native.readDeviceFunctions();
  }

  async readSocialMsgData(): Promise<unknown> {
    return this.native.readSocialMsgData();
  }

  async readDeviceVersion(): Promise<unknown> {
    return this.native.readDeviceVersion();
  }

  async startReadOriginData(): Promise<void> {
    return this.native.startReadOriginData();
  }

  async readDeviceAllData(): Promise<boolean> {
    return this.native.readDeviceAllData();
  }

  async readSleepData(date?: string): Promise<unknown> {
    return this.native.readSleepData(date);
  }

  async readSportStepData(date?: string): Promise<unknown> {
    return this.native.readSportStepData(date);
  }

  async readOriginData(dayOffset: number = 0): Promise<unknown> {
    return this.native.readOriginData(dayOffset);
  }

  async readDaySummaryData(dayOffset: number = 0): Promise<unknown> {
    return this.native.readDaySummaryData(dayOffset);
  }

  async readAutoMeasureSetting(): Promise<unknown> {
    return this.native.readAutoMeasureSetting();
  }

  async modifyAutoMeasureSetting(setting: Partial<AutoMeasureSetting>): Promise<unknown> {
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

  addListener(event: SmartWearableLinkEvent, listener: (payload: unknown) => void): EventSubscription {
    return this.native.addListener(event, listener);
  }

  removeListeners(count: number): void {
    this.native.removeListeners(count);
  }
}

export default new SmartWearableLinkSDKNativeWrapper();
