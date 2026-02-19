import { EventEmitter } from 'events';
import NativeVeepooSDK from './NativeVeepooSDK.js';

import type {
  VeepooDevice,
  ConnectionStatus,
  ScanOptions,
  ConnectOptions,
  VeepooEvent,
  VeepooEventPayload,
  BatteryInfo,
  PersonalInfo,
  DeviceFunctions,
  PasswordData,
  SocialMsgData,
  ReadOriginProgress,
  Language,
  AutoMeasureSetting,
  HeartRateTestResult,
  BloodPressureTestResult,
  BloodOxygenTestResult,
  TemperatureTestResult,
  StressData,
  BloodGlucoseData,
  HalfHourData,
  VeepooError,
} from './types.js';

let DeviceEventEmitter: typeof import('react-native').DeviceEventEmitter | null = null;

function getDeviceEventEmitter() {
  if (!DeviceEventEmitter) {
    try {
      DeviceEventEmitter = require('react-native').DeviceEventEmitter;
    } catch {
      DeviceEventEmitter = null;
    }
  }
  return DeviceEventEmitter;
}

export class VeepooSDK extends EventEmitter {
  private isScanning = false;
  private isInitialized = false;
  private connectedDeviceId: string | null = null;
  private eventListenersSetup = false;

  constructor() {
    super();
  }

  private setupEventListeners(): void {
    if (this.eventListenersSetup) return;
    this.eventListenersSetup = true;

    const emitter = getDeviceEventEmitter();
    if (!emitter) return;

    const events: VeepooEvent[] = [
      'deviceFound',
      'deviceConnected',
      'deviceDisconnected',
      'deviceConnectStatus',
      'deviceReady',
      'bluetoothStateChanged',
      'deviceFunction',
      'deviceVersion',
      'passwordData',
      'socialMsgData',
      'readOriginProgress',
      'readOriginComplete',
      'originHalfHourData',
      'heartRateTestResult',
      'bloodPressureTestResult',
      'bloodOxygenTestResult',
      'temperatureTestResult',
      'stressData',
      'bloodGlucoseData',
      'batteryData',
      'customSettingData',
      'dataReceived',
      'connectionStatusChanged',
      'error',
    ];

    events.forEach((event) => {
      NativeVeepooSDK.addListener(event);
    });

    events.forEach((event) => {
      emitter.addListener(
        `VeepooSDK_${event}`,
        (payload: VeepooEventPayload[VeepooEvent]) => {
          this.emit(event, payload);
        }
      );
    });
  }

  private handleError(error: unknown, code: VeepooError['code'], deviceId?: string): VeepooError {
    const veepooError: VeepooError = {
      code,
      message: error instanceof Error ? error.message : String(error),
      deviceId,
    };
    this.emit('error', veepooError);
    return veepooError;
  }

  async init(): Promise<void> {
    if (this.isInitialized) return;
    this.setupEventListeners();
    await NativeVeepooSDK.init();
    this.isInitialized = true;
  }

  async checkBluetoothStatus(): Promise<boolean> {
    try {
      return await NativeVeepooSDK.isBluetoothEnabled();
    } catch (error) {
      this.handleError(error, 'UNKNOWN');
      return false;
    }
  }

  async requestPermissions(): Promise<boolean> {
    try {
      return await NativeVeepooSDK.requestPermissions();
    } catch (error) {
      this.handleError(error, 'PERMISSION_DENIED');
      return false;
    }
  }

  async startScan(options?: ScanOptions): Promise<void> {
    if (this.isScanning) return;

    try {
      this.isScanning = true;
      await NativeVeepooSDK.startScan(options);
    } catch (error) {
      this.isScanning = false;
      throw this.handleError(error, 'UNKNOWN');
    }
  }

  async stopScan(): Promise<void> {
    if (!this.isScanning) return;

    try {
      await NativeVeepooSDK.stopScan();
      this.isScanning = false;
    } catch (error) {
      this.isScanning = false;
      throw this.handleError(error, 'UNKNOWN');
    }
  }

  async connect(deviceId: string, options?: ConnectOptions): Promise<void> {
    try {
      await NativeVeepooSDK.connect(deviceId, options);
      this.connectedDeviceId = deviceId;
    } catch (error) {
      throw this.handleError(error, 'CONNECTION_FAILED', deviceId);
    }
  }

  async disconnect(deviceId?: string): Promise<void> {
    const id = deviceId || this.connectedDeviceId;
    if (!id) return;

    try {
      await NativeVeepooSDK.disconnect(id);
      if (this.connectedDeviceId === id) {
        this.connectedDeviceId = null;
      }
    } catch (error) {
      throw this.handleError(error, 'DISCONNECTION_FAILED', id);
    }
  }

  async getConnectionStatus(deviceId?: string): Promise<ConnectionStatus> {
    const id = deviceId || this.connectedDeviceId;
    if (!id) return 'disconnected';

    try {
      return await NativeVeepooSDK.getConnectionStatus(id);
    } catch (error) {
      this.handleError(error, 'UNKNOWN', id);
      return 'disconnected';
    }
  }

  async verifyPassword(password: string = '0000', is24Hour: boolean = false): Promise<PasswordData> {
    return NativeVeepooSDK.verifyPassword(password, is24Hour);
  }

  async readBattery(): Promise<BatteryInfo> {
    return NativeVeepooSDK.readBattery();
  }

  async syncPersonalInfo(info: PersonalInfo): Promise<boolean> {
    return NativeVeepooSDK.syncPersonalInfo(info);
  }

  async readDeviceFunctions(): Promise<DeviceFunctions> {
    return NativeVeepooSDK.readDeviceFunctions();
  }

  async readSocialMsgData(): Promise<SocialMsgData> {
    return NativeVeepooSDK.readSocialMsgData();
  }

  async startReadOriginData(): Promise<void> {
    return NativeVeepooSDK.startReadOriginData();
  }

  async readAutoMeasureSetting(): Promise<AutoMeasureSetting[]> {
    return NativeVeepooSDK.readAutoMeasureSetting();
  }

  async modifyAutoMeasureSetting(setting: AutoMeasureSetting): Promise<void> {
    return NativeVeepooSDK.modifyAutoMeasureSetting(setting);
  }

  async setLanguage(language: Language): Promise<boolean> {
    return NativeVeepooSDK.setLanguage(language);
  }

  async startHeartRateTest(): Promise<void> {
    return NativeVeepooSDK.startHeartRateTest();
  }

  async stopHeartRateTest(): Promise<void> {
    return NativeVeepooSDK.stopHeartRateTest();
  }

  async startBloodPressureTest(): Promise<void> {
    return NativeVeepooSDK.startBloodPressureTest();
  }

  async stopBloodPressureTest(): Promise<void> {
    return NativeVeepooSDK.stopBloodPressureTest();
  }

  async startBloodOxygenTest(): Promise<void> {
    return NativeVeepooSDK.startBloodOxygenTest();
  }

  async stopBloodOxygenTest(): Promise<void> {
    return NativeVeepooSDK.stopBloodOxygenTest();
  }

  async startTemperatureTest(): Promise<void> {
    return NativeVeepooSDK.startTemperatureTest();
  }

  async stopTemperatureTest(): Promise<void> {
    return NativeVeepooSDK.stopTemperatureTest();
  }

  async startStressTest(): Promise<void> {
    return NativeVeepooSDK.startStressTest();
  }

  async stopStressTest(): Promise<void> {
    return NativeVeepooSDK.stopStressTest();
  }

  async startBloodGlucoseTest(): Promise<void> {
    return NativeVeepooSDK.startBloodGlucoseTest();
  }

  async stopBloodGlucoseTest(): Promise<void> {
    return NativeVeepooSDK.stopBloodGlucoseTest();
  }

  isScanningActive(): boolean {
    return this.isScanning;
  }

  isSDKInitialized(): boolean {
    return this.isInitialized;
  }

  getConnectedDeviceId(): string | null {
    return this.connectedDeviceId;
  }

  on<K extends VeepooEvent>(
    event: K,
    listener: (payload: VeepooEventPayload[K]) => void
  ): this {
    super.on(event, listener as (...args: unknown[]) => void);
    return this;
  }

  off<K extends VeepooEvent>(
    event: K,
    listener: (payload: VeepooEventPayload[K]) => void
  ): this {
    super.off(event, listener as (...args: unknown[]) => void);
    return this;
  }

  once<K extends VeepooEvent>(
    event: K,
    listener: (payload: VeepooEventPayload[K]) => void
  ): this {
    super.once(event, listener as (...args: unknown[]) => void);
    return this;
  }

  removeAllListeners(event?: VeepooEvent): this {
    super.removeAllListeners(event);
    return this;
  }
}

const sdk = new VeepooSDK();
export default sdk;
