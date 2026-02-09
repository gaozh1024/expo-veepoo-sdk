import { EventEmitter } from 'events';
import NativeVeepooSDK, { NativeVeepooSDKInterface } from './NativeVeepooSDK';
import type {
  VeepooDevice,
  ConnectionStatus,
  ScanOptions,
  ConnectOptions,
  DeviceData,
  VeepooEvent,
  VeepooEventPayload,
} from './types';

export class VeepooSDK extends EventEmitter {
  private native: NativeVeepooSDKInterface;
  private isScanning = false;
  private connectedDevices: Map<string, VeepooDevice> = new Map();

  constructor() {
    super();
    this.native = NativeVeepooSDK;
    this.setupEventListeners();
  }

  private setupEventListeners(): void {
    const events: VeepooEvent[] = [
      'deviceFound',
      'deviceConnected',
      'deviceDisconnected',
      'dataReceived',
      'connectionStatusChanged',
      'error',
    ];

    events.forEach((event) => {
      this.native.addListener(event);
    });

    if (this.native.addListener && typeof this.native.addListener === 'function') {
      this.native.addListener = this.native.addListener.bind(this.native);
    }

    const DeviceEventEmitter = require('react-native').DeviceEventEmitter;

    events.forEach((event) => {
      DeviceEventEmitter.addListener(
        `VeepooSDK_${event}`,
        (payload: VeepooEventPayload[VeepooEvent]) => {
          this.emit(event, payload);
        }
      );
    });
  }

  async checkBluetoothStatus(): Promise<boolean> {
    try {
      return await this.native.isBluetoothEnabled();
    } catch (error) {
      this.emit('error', {
        code: 'UNKNOWN',
        message: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }

  async requestPermissions(): Promise<boolean> {
    try {
      return await this.native.requestPermissions();
    } catch (error) {
      this.emit('error', {
        code: 'PERMISSION_DENIED',
        message: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }

  async startScan(options?: ScanOptions): Promise<void> {
    if (this.isScanning) {
      return;
    }

    try {
      this.isScanning = true;
      await this.native.startScanning(options);
    } catch (error) {
      this.isScanning = false;
      this.emit('error', {
        code: 'UNKNOWN',
        message: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  async stopScan(): Promise<void> {
    if (!this.isScanning) {
      return;
    }

    try {
      await this.native.stopScanning();
      this.isScanning = false;
    } catch (error) {
      this.emit('error', {
        code: 'UNKNOWN',
        message: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  async connect(deviceId: string, options?: ConnectOptions): Promise<void> {
    try {
      await this.native.connectToDevice(deviceId, options);
    } catch (error) {
      this.emit('error', {
        code: 'CONNECTION_FAILED',
        message: error instanceof Error ? error.message : String(error),
        deviceId,
      });
      throw error;
    }
  }

  async disconnect(deviceId: string): Promise<void> {
    try {
      await this.native.disconnectFromDevice(deviceId);
    } catch (error) {
      this.emit('error', {
        code: 'DISCONNECTION_FAILED',
        message: error instanceof Error ? error.message : String(error),
        deviceId,
      });
      throw error;
    }
  }

  async getConnectionStatus(deviceId: string): Promise<ConnectionStatus> {
    try {
      return await this.native.getConnectionStatus(deviceId);
    } catch (error) {
      this.emit('error', {
        code: 'UNKNOWN',
        message: error instanceof Error ? error.message : String(error),
        deviceId,
      });
      return 'disconnected';
    }
  }

  async sendData(deviceId: string, data: number[]): Promise<void> {
    try {
      await this.native.sendData(deviceId, data);
    } catch (error) {
      this.emit('error', {
        code: 'UNKNOWN',
        message: error instanceof Error ? error.message : String(error),
        deviceId,
      });
      throw error;
    }
  }

  isScanningActive(): boolean {
    return this.isScanning;
  }

  on(event: VeepooEvent, listener: (payload: VeepooEventPayload[VeepooEvent]) => void): this {
    super.on(event, listener);
    return this;
  }

  off(event: VeepooEvent, listener: (payload: VeepooEventPayload[VeepooEvent]) => void): this {
    super.off(event, listener);
    return this;
  }
}

const sdk = new VeepooSDK();

export default sdk;
