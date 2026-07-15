import { requireNativeModule } from 'expo-modules-core';
import type { EventSubscription } from 'expo-modules-core';
import { Platform } from 'react-native';

import type {
  ConnectionStatus,
  ScanOptions,
  ConnectOptions,
  LogEntry,
  LogLevel,
  LogScope,
  BatteryInfo,
  PersonalInfo,
  DeviceFunctions,
  DeviceVersion,
  PasswordData,
  SocialMsgData,
  Language,
  AutoMeasureSetting,
  SleepData,
  SportStepData,
  SmartWearableLinkError,
  OriginData,
  DaySummaryData,
  SmartWearableLinkEvent,
  SmartWearableLinkEventPayload,
  PermissionsResult,
} from './types.js';
import type { NativeSmartWearableLinkSDKInterface } from './NativeSmartWearableLinkSDK.js';
import {
  normalizeAutoMeasureSettings,
  normalizeBatteryInfo,
  normalizeBluetoothStatus,
  normalizeBloodGlucoseData,
  normalizeBloodOxygenTestResult,
  normalizeBloodPressureTestResult,
  normalizeDaySummaryData,
  normalizeDeviceFunctions,
  normalizeDeviceVersion,
  normalizeHalfHourData,
  normalizeHeartRateTestResult,
  normalizeOriginDataList,
  normalizePasswordData,
  normalizePermissionsResult,
  normalizeReadOriginProgressPayload,
  normalizeSleepDataList,
  normalizeSocialMsgData,
  normalizeSportStepData,
  normalizeStressData,
  normalizeTemperatureTestResult,
} from './normalizers.js';

type EventListener = (payload: unknown) => void;
type LogListener = (entry: LogEntry) => void;

const LINKING_ERROR =
  "The package 'expo-smart-wearable-link' doesn't seem to be linked. Make sure:\n\n" +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go (this module requires a development build)\n';

let NativeModule: NativeSmartWearableLinkSDKInterface;
try {
  NativeModule = requireNativeModule<NativeSmartWearableLinkSDKInterface>('SmartWearableLinkSDK');
} catch {
  NativeModule = new Proxy({} as NativeSmartWearableLinkSDKInterface, {
    get() {
      throw new Error(LINKING_ERROR);
    },
  });
}

export class SmartWearableLinkSDK {
  private isScanning = false;
  private isInitialized = false;
  private connectedDeviceId: string | null = null;
  private eventListenersSetup = false;
  private lastReadOriginProgressByDevice: Map<string, number> = new Map();
  private logEnabled = false;
  private logger: LogListener | null = null;
  private listeners: Map<SmartWearableLinkEvent, Set<EventListener>> = new Map();
  private nativeSubscriptions: EventSubscription[] = [];

  private getPlatform(): LogEntry['platform'] {
    if (Platform.OS === 'ios' || Platform.OS === 'android' || Platform.OS === 'web') {
      return Platform.OS;
    }
    return 'unknown';
  }

  private log(level: LogLevel, scope: LogScope, action: string, message: string, options?: {
    deviceId?: string;
    data?: unknown;
    error?: unknown;
  }): void {
    if (!this.logEnabled && !this.logger) {
      return;
    }

    const entry: LogEntry = {
      timestamp: Date.now(),
      level,
      scope,
      action,
      platform: this.getPlatform(),
      message,
      deviceId: options?.deviceId,
      data: options?.data,
      error: options?.error instanceof Error ? options.error.message : typeof options?.error === 'string' ? options.error : undefined,
    };

    if (this.logEnabled) {
      const consoleMethod =
        level === 'error'
          ? console.error
          : level === 'warn'
            ? console.warn
            : level === 'info'
              ? console.info
              : console.debug;
      consoleMethod('[SmartWearableLinkSDK]', entry);
    }

    if (this.logger) {
      try {
        this.logger(entry);
      } catch (error) {
        if (this.logEnabled) {
          console.error('[SmartWearableLinkSDK]', {
            timestamp: Date.now(),
            level: 'error',
            scope: 'listener',
            action: 'logger.callback.failed',
            platform: this.getPlatform(),
            message: 'Logger callback failed',
            error: error instanceof Error ? error.message : String(error),
          } satisfies LogEntry);
        }
      }
    }
  }

  private setupEventListeners(): void {
    if (this.eventListenersSetup) return;
    this.eventListenersSetup = true;

    const events: SmartWearableLinkEvent[] = [
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
      'originFiveMinuteData',
      'originHalfHourData',
      'sleepData',
      'sportStepData',
      'heartRateTestResult',
      'bloodPressureTestResult',
      'bloodOxygenTestResult',
      'temperatureTestResult',
      'stressData',
      'bloodGlucoseData',
      'batteryData',
      'connectionStatusChanged',
      'error',
    ];

    events.forEach((event) => {
      const subscription = (NativeModule as unknown as { addListener: (event: string, listener: (payload: unknown) => void) => EventSubscription }).addListener(
        event,
        (payload: unknown) => {
          this.emitLocal(event, payload);
        }
      );
      this.nativeSubscriptions.push(subscription);
    });
  }

  private emitLocal(event: SmartWearableLinkEvent, payload: unknown): void {
    const normalizedPayload =
      event === 'bluetoothStateChanged'
        ? normalizeBluetoothStatus(payload)
        : event === 'readOriginProgress'
          ? normalizeReadOriginProgressPayload(payload)
          : event === 'deviceFunction' && this.isEventRecord(payload)
            ? {
                ...payload,
                data: normalizeDeviceFunctions(payload.data ?? payload.functions),
                functions: normalizeDeviceFunctions(payload.functions ?? payload.data),
              }
            : event === 'deviceVersion' && this.isEventRecord(payload)
              ? { ...payload, version: normalizeDeviceVersion(payload.version) }
              : event === 'passwordData' && this.isEventRecord(payload)
                ? { ...payload, data: normalizePasswordData(payload.data) }
                : event === 'socialMsgData' && this.isEventRecord(payload)
                  ? { ...payload, data: normalizeSocialMsgData(payload.data) }
                  : event === 'originFiveMinuteData' && this.isEventRecord(payload)
                    ? {
                        ...payload,
                        data: normalizeOriginDataList([payload.data])[0],
                      }
                    : event === 'originHalfHourData' && this.isEventRecord(payload)
                      ? { ...payload, data: normalizeHalfHourData(payload.data) }
                      : event === 'sleepData' && this.isEventRecord(payload)
                        ? {
                            ...payload,
                            data: normalizeSleepDataList(payload.data)[0],
                          }
                        : event === 'sportStepData' && this.isEventRecord(payload)
                          ? { ...payload, data: normalizeSportStepData(payload.data) }
                          : event === 'heartRateTestResult' && this.isEventRecord(payload)
                            ? { ...payload, result: normalizeHeartRateTestResult(payload.result) }
                            : event === 'bloodPressureTestResult' && this.isEventRecord(payload)
                              ? {
                                  ...payload,
                                  result: normalizeBloodPressureTestResult(payload.result),
                                }
                              : event === 'bloodOxygenTestResult' && this.isEventRecord(payload)
                                ? {
                                    ...payload,
                                    result: normalizeBloodOxygenTestResult(payload.result),
                                  }
                                : event === 'temperatureTestResult' && this.isEventRecord(payload)
                                  ? {
                                      ...payload,
                                      result: normalizeTemperatureTestResult(payload.result),
                                    }
                                  : event === 'stressData' && this.isEventRecord(payload)
                                    ? { ...payload, data: normalizeStressData(payload.data) }
                                    : event === 'bloodGlucoseData' && this.isEventRecord(payload)
                                      ? {
                                          ...payload,
                                          data: normalizeBloodGlucoseData(payload.data),
                                        }
                                      : event === 'batteryData' && this.isEventRecord(payload)
                                        ? { ...payload, data: normalizeBatteryInfo(payload.data) }
          : payload;

    if (event === 'readOriginProgress' && this.isEventRecord(normalizedPayload) && this.isEventRecord(normalizedPayload.progress)) {
      const deviceId = this.getPayloadDeviceId(normalizedPayload) ?? '__default__';
      const progressValue = normalizedPayload.progress.progress;
      const readState = normalizedPayload.progress.readState;
      const lastProgress = this.lastReadOriginProgressByDevice.get(deviceId);

      if (typeof progressValue === 'number' && Number.isFinite(progressValue)) {
        if (readState === 'start' || lastProgress === undefined || progressValue < lastProgress) {
          this.lastReadOriginProgressByDevice.set(deviceId, progressValue);
        } else if (progressValue === lastProgress) {
          return;
        } else {
          this.lastReadOriginProgressByDevice.set(deviceId, progressValue);
        }
      }
    }

    this.log('debug', this.getEventScope(event), `event.${event}`, `Received ${event} event`, {
      deviceId: this.getPayloadDeviceId(normalizedPayload),
      data: normalizedPayload,
    });

    if (event === 'bluetoothStateChanged') {
      const bluetoothStatus = normalizedPayload as { isScanning?: boolean };
      if (typeof bluetoothStatus.isScanning === 'boolean') {
        this.isScanning = bluetoothStatus.isScanning;
      }
    }

    if (event === 'deviceConnected') {
      const device = normalizedPayload as { deviceId?: string };
      if (typeof device.deviceId === 'string' && device.deviceId.length > 0) {
        this.connectedDeviceId = device.deviceId;
      }
    }

    if (event === 'deviceDisconnected') {
      const device = normalizedPayload as { deviceId?: string };
      if (!device.deviceId || this.connectedDeviceId === device.deviceId) {
        this.connectedDeviceId = null;
      }
      if (device.deviceId) {
        this.lastReadOriginProgressByDevice.delete(device.deviceId);
      }
      this.isScanning = false;
    }

    if (event === 'deviceConnectStatus' || event === 'connectionStatusChanged') {
      const connection = normalizedPayload as { deviceId?: string; status?: ConnectionStatus };
      if (connection.status === 'disconnected' && (!connection.deviceId || this.connectedDeviceId === connection.deviceId)) {
        this.connectedDeviceId = null;
      }
    }

    const eventListeners = this.listeners.get(event);
    if (eventListeners) {
      eventListeners.forEach((listener) => {
        try {
          listener(normalizedPayload);
        } catch (e) {
          this.log('error', 'listener', `listener.${event}.failed`, `Event listener for ${event} threw`, {
            deviceId: this.getPayloadDeviceId(normalizedPayload),
            error: e,
            data: normalizedPayload,
          });
          console.error(`Error in event listener for ${event}:`, e);
        }
      });
    }
  }

  private getEventScope(event: SmartWearableLinkEvent): LogScope {
    if (event === 'deviceFound') return 'scan';
    if (event === 'bluetoothStateChanged') return 'bluetooth';
    if (event === 'deviceConnected' || event === 'deviceDisconnected' || event === 'deviceConnectStatus' || event === 'deviceReady' || event === 'connectionStatusChanged') {
      return 'connection';
    }
    if (event === 'readOriginProgress' || event === 'readOriginComplete' || event === 'originFiveMinuteData' || event === 'originHalfHourData' || event === 'sleepData' || event === 'sportStepData') {
      return 'read';
    }
    if (event === 'heartRateTestResult' || event === 'bloodPressureTestResult' || event === 'bloodOxygenTestResult' || event === 'temperatureTestResult' || event === 'stressData' || event === 'bloodGlucoseData') {
      return 'test';
    }
    if (event === 'error') return 'sdk';
    return 'device';
  }

  private getPayloadDeviceId(payload: unknown): string | undefined {
    if (typeof payload !== 'object' || payload === null) {
      return undefined;
    }
    const deviceId = (payload as { deviceId?: unknown }).deviceId;
    return typeof deviceId === 'string' && deviceId.length > 0 ? deviceId : undefined;
  }

  private isEventRecord(payload: unknown): payload is Record<string, any> {
    return typeof payload === 'object' && payload !== null;
  }

  private handleError(error: unknown, code: SmartWearableLinkError['code'], deviceId?: string): SmartWearableLinkError {
    const smartWearableLinkError: SmartWearableLinkError = {
      code,
      message: error instanceof Error ? error.message : String(error),
      deviceId,
    };
    this.log('error', 'sdk', `error.${code}`, smartWearableLinkError.message, {
      deviceId,
      error,
    });
    this.emitLocal('error', smartWearableLinkError);
    return smartWearableLinkError;
  }

  async init(): Promise<void> {
    if (this.isInitialized) return;
    this.log('info', 'sdk', 'init.start', 'Initializing SDK');
    this.setupEventListeners();
    await NativeModule.init();
    this.isInitialized = true;
    this.log('info', 'sdk', 'init.success', 'SDK initialized');
  }

  async checkBluetoothStatus(): Promise<boolean> {
    try {
      const enabled = await NativeModule.isBluetoothEnabled();
      this.log('debug', 'bluetooth', 'bluetooth.check', 'Checked Bluetooth status', {
        data: { enabled },
      });
      return enabled;
    } catch (error) {
      this.handleError(error, 'UNKNOWN');
      return false;
    }
  }

  async requestPermissions(): Promise<PermissionsResult> {
    try {
      const result = normalizePermissionsResult(await NativeModule.requestPermissions());
      this.log('info', 'permissions', 'permissions.request', 'Requested Bluetooth permissions', {
        data: result,
      });
      return result;
    } catch (error) {
      this.handleError(error, 'PERMISSION_DENIED');
      return { granted: false, status: 'denied', canAskAgain: true };
    }
  }

  async startScan(options?: ScanOptions): Promise<void> {
    if (this.isScanning) return;

    try {
      this.isScanning = true;
      this.log('info', 'scan', 'scan.start', 'Starting device scan', { data: options });
      await NativeModule.startScan(options);
    } catch (error) {
      this.isScanning = false;
      throw this.handleError(error, 'UNKNOWN');
    }
  }

  async stopScan(): Promise<void> {
    if (!this.isScanning) return;

    try {
      await NativeModule.stopScan();
      this.isScanning = false;
      this.log('info', 'scan', 'scan.stop', 'Stopped device scan');
    } catch (error) {
      this.isScanning = false;
      throw this.handleError(error, 'UNKNOWN');
    }
  }

  async connect(deviceId: string, options?: ConnectOptions): Promise<void> {
    try {
      this.log('info', 'connection', 'connect.start', 'Connecting device', {
        deviceId,
        data: options,
      });
      await NativeModule.connect(deviceId, options);
      this.connectedDeviceId = deviceId;
      this.log('info', 'connection', 'connect.success', 'Device connect request completed', {
        deviceId,
      });
    } catch (error) {
      throw this.handleError(error, 'CONNECTION_FAILED', deviceId);
    }
  }

  async disconnect(deviceId?: string): Promise<void> {
    const id = deviceId || this.connectedDeviceId;
    if (!id) return;

    try {
      this.log('info', 'connection', 'disconnect.start', 'Disconnecting device', {
        deviceId: id,
      });
      await NativeModule.disconnect(id);
      if (this.connectedDeviceId === id) {
        this.connectedDeviceId = null;
      }
      this.log('info', 'connection', 'disconnect.success', 'Device disconnected', {
        deviceId: id,
      });
    } catch (error) {
      throw this.handleError(error, 'DISCONNECTION_FAILED', id);
    }
  }

  async getConnectionStatus(deviceId?: string): Promise<ConnectionStatus> {
    const id = deviceId || this.connectedDeviceId;
    if (!id) return 'disconnected';

    try {
      const status = await NativeModule.getConnectionStatus(id);
      this.log('debug', 'connection', 'connection.status', 'Fetched connection status', {
        deviceId: id,
        data: { status },
      });
      return status;
    } catch (error) {
      this.handleError(error, 'UNKNOWN', id);
      return 'disconnected';
    }
  }

  async verifyPassword(password: string = '0000', is24Hour: boolean = false): Promise<PasswordData> {
    this.log('info', 'connection', 'password.verify.start', 'Verifying device password', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { is24Hour },
    });
    const result = normalizePasswordData(await NativeModule.verifyPassword(password, is24Hour));
    this.log('info', 'connection', 'password.verify.result', 'Device password verified', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { status: result.status, deviceNumber: result.deviceNumber, deviceVersion: result.deviceVersion },
    });
    return result;
  }

  async readBattery(): Promise<BatteryInfo> {
    this.log('debug', 'device', 'battery.read.start', 'Reading battery info', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    const result = normalizeBatteryInfo(await NativeModule.readBattery());
    this.log('debug', 'device', 'battery.read.result', 'Battery info received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: result,
    });
    return result;
  }

  async syncPersonalInfo(info: PersonalInfo): Promise<boolean> {
    return NativeModule.syncPersonalInfo(info);
  }

  async readDeviceFunctions(): Promise<DeviceFunctions> {
    const result = normalizeDeviceFunctions(await NativeModule.readDeviceFunctions());
    this.log('debug', 'device', 'device.functions.read', 'Device functions received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: result,
    });
    return result;
  }

  async readSocialMsgData(): Promise<SocialMsgData> {
    const result = normalizeSocialMsgData(await NativeModule.readSocialMsgData());
    this.log('debug', 'device', 'device.social.read', 'Social message settings received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: result,
    });
    return result;
  }

  async readDeviceVersion(): Promise<DeviceVersion> {
    const result = normalizeDeviceVersion(await NativeModule.readDeviceVersion());
    this.log('debug', 'device', 'device.version.read', 'Device version received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: result,
    });
    return result;
  }

  async startReadOriginData(): Promise<void> {
    this.log('info', 'read', 'read.origin.start', 'Starting origin data read', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startReadOriginData();
  }

  async readDeviceAllData(): Promise<boolean> {
    return NativeModule.readDeviceAllData();
  }

  async readSleepData(date?: string): Promise<SleepData[]> {
    const result = normalizeSleepDataList(await NativeModule.readSleepData(date));
    this.log('debug', 'read', 'read.sleep.result', 'Sleep data received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { date, count: result.length },
    });
    return result;
  }

  async readSportStepData(date?: string): Promise<SportStepData> {
    const result = normalizeSportStepData(await NativeModule.readSportStepData(date));
    this.log('debug', 'read', 'read.sport.result', 'Sport step data received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: result,
    });
    return result;
  }

  async readOriginData(dayOffset: number = 0): Promise<OriginData[]> {
    const result = normalizeOriginDataList(await NativeModule.readOriginData(dayOffset));
    this.log('debug', 'read', 'read.origin.result', 'Origin data received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { dayOffset, count: result.length },
    });
    return result;
  }

  async readDaySummaryData(dayOffset: number = 0): Promise<DaySummaryData> {
    const result = normalizeDaySummaryData(await NativeModule.readDaySummaryData(dayOffset));
    this.log('debug', 'read', 'read.summary.result', 'Day summary data received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { dayOffset, date: result.date },
    });
    return result;
  }

  async readAutoMeasureSetting(): Promise<AutoMeasureSetting[]> {
    const result = normalizeAutoMeasureSettings(await NativeModule.readAutoMeasureSetting());
    this.log('debug', 'device', 'autoMeasure.read', 'Auto measure settings received', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { count: result.length },
    });
    return result;
  }

  async modifyAutoMeasureSetting(setting: Partial<AutoMeasureSetting>): Promise<AutoMeasureSetting[]> {
    this.log('info', 'device', 'autoMeasure.modify.start', 'Modifying auto measure settings', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: setting,
    });
    const result = normalizeAutoMeasureSettings(await NativeModule.modifyAutoMeasureSetting(setting));
    this.log('info', 'device', 'autoMeasure.modify.result', 'Auto measure settings updated', {
      deviceId: this.connectedDeviceId ?? undefined,
      data: { count: result.length },
    });
    return result;
  }

  async setLanguage(language: Language): Promise<boolean> {
    return NativeModule.setLanguage(language);
  }

  async startHeartRateTest(): Promise<void> {
    this.log('info', 'test', 'test.heartRate.start', 'Starting heart rate test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startHeartRateTest();
  }

  async stopHeartRateTest(): Promise<void> {
    this.log('info', 'test', 'test.heartRate.stop', 'Stopping heart rate test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.stopHeartRateTest();
  }

  async startBloodPressureTest(): Promise<void> {
    this.log('info', 'test', 'test.bloodPressure.start', 'Starting blood pressure test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startBloodPressureTest();
  }

  async stopBloodPressureTest(): Promise<void> {
    this.log('info', 'test', 'test.bloodPressure.stop', 'Stopping blood pressure test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.stopBloodPressureTest();
  }

  async startBloodOxygenTest(): Promise<void> {
    this.log('info', 'test', 'test.bloodOxygen.start', 'Starting blood oxygen test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startBloodOxygenTest();
  }

  async stopBloodOxygenTest(): Promise<void> {
    this.log('info', 'test', 'test.bloodOxygen.stop', 'Stopping blood oxygen test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.stopBloodOxygenTest();
  }

  async startTemperatureTest(): Promise<void> {
    this.log('info', 'test', 'test.temperature.start', 'Starting temperature test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startTemperatureTest();
  }

  async stopTemperatureTest(): Promise<void> {
    this.log('info', 'test', 'test.temperature.stop', 'Stopping temperature test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.stopTemperatureTest();
  }

  async startStressTest(): Promise<void> {
    this.log('info', 'test', 'test.stress.start', 'Starting stress test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startStressTest();
  }

  async stopStressTest(): Promise<void> {
    this.log('info', 'test', 'test.stress.stop', 'Stopping stress test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.stopStressTest();
  }

  async startBloodGlucoseTest(): Promise<void> {
    this.log('info', 'test', 'test.bloodGlucose.start', 'Starting blood glucose test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.startBloodGlucoseTest();
  }

  async stopBloodGlucoseTest(): Promise<void> {
    this.log('info', 'test', 'test.bloodGlucose.stop', 'Stopping blood glucose test', {
      deviceId: this.connectedDeviceId ?? undefined,
    });
    return NativeModule.stopBloodGlucoseTest();
  }

  setLogEnabled(enabled: boolean): this {
    this.logEnabled = enabled;
    this.log('info', 'sdk', 'logger.toggle', enabled ? 'SDK logging enabled' : 'SDK logging disabled');
    return this;
  }

  isLogEnabled(): boolean {
    return this.logEnabled;
  }

  setLogger(logger: LogListener | null): this {
    this.logger = logger;
    this.log('debug', 'sdk', 'logger.set', logger ? 'Custom logger attached' : 'Custom logger cleared');
    return this;
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

  on<K extends SmartWearableLinkEvent>(
    event: K,
    listener: (payload: SmartWearableLinkEventPayload[K]) => void
  ): this {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(listener as EventListener);
    return this;
  }

  off<K extends SmartWearableLinkEvent>(
    event: K,
    listener: (payload: SmartWearableLinkEventPayload[K]) => void
  ): this {
    const eventListeners = this.listeners.get(event);
    if (eventListeners) {
      eventListeners.delete(listener as EventListener);
    }
    return this;
  }

  once<K extends SmartWearableLinkEvent>(
    event: K,
    listener: (payload: SmartWearableLinkEventPayload[K]) => void
  ): this {
    const onceWrapper: EventListener = (payload) => {
      this.off(event, listener);
      (listener as EventListener)(payload);
    };
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(onceWrapper);
    return this;
  }

  removeAllListeners(event?: SmartWearableLinkEvent): this {
    if (event) {
      this.listeners.delete(event);
    } else {
      this.listeners.clear();
    }
    return this;
  }

  destroy(): void {
    this.log('info', 'sdk', 'destroy', 'Destroying SDK instance');
    this.nativeSubscriptions.forEach((subscription) => {
      subscription.remove();
    });
    this.nativeSubscriptions = [];
    this.listeners.clear();
    this.lastReadOriginProgressByDevice.clear();
    this.eventListenersSetup = false;
    this.isScanning = false;
    this.connectedDeviceId = null;
    this.isInitialized = false;
    this.logger = null;
    this.logEnabled = false;
  }
}

const sdk = new SmartWearableLinkSDK();
export default sdk;
