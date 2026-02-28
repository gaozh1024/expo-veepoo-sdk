import { useState, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { VeepooDevice, BatteryInfo } from '@gaozh1024/expo-veepoo-sdk';
import type { SavedDevice } from '../types';

const SAVED_DEVICES_KEY = '@veepoo_saved_devices';

export interface DeviceState {
  isInitialized: boolean;
  isScanning: boolean;
  connectedDeviceId: string | null;
  isDeviceReady: boolean;
  devices: VeepooDevice[];
  savedDevices: SavedDevice[];
  battery: BatteryInfo | null;
}

export interface DeviceActions {
  setIsInitialized: (value: boolean) => void;
  setIsScanning: (value: boolean) => void;
  setConnectedDeviceId: (value: string | null) => void;
  setIsDeviceReady: (value: boolean) => void;
  setBattery: (value: BatteryInfo | null) => void;
  addDevice: (device: VeepooDevice) => void;
  clearDevices: () => void;
  loadSavedDevices: () => Promise<void>;
  saveDevice: (device: VeepooDevice) => Promise<void>;
  removeSavedDevice: (deviceId: string) => Promise<void>;
  resetOnDisconnect: () => void;
}

export type UseDeviceState = DeviceState & DeviceActions;

export const useDeviceState = (): UseDeviceState => {
  const [isInitialized, setIsInitialized] = useState(false);
  const [isScanning, setIsScanning] = useState(false);
  const [connectedDeviceId, setConnectedDeviceId] = useState<string | null>(null);
  const [isDeviceReady, setIsDeviceReady] = useState(false);
  const [devices, setDevices] = useState<VeepooDevice[]>([]);
  const [savedDevices, setSavedDevices] = useState<SavedDevice[]>([]);
  const [battery, setBattery] = useState<BatteryInfo | null>(null);

  const addDevice = useCallback((device: VeepooDevice) => {
    setDevices((prev) => {
      const exists = prev.find((d) => d.id === device.id);
      return exists ? prev : [...prev, device];
    });
  }, []);

  const clearDevices = useCallback(() => {
    setDevices([]);
  }, []);

  const loadSavedDevices = useCallback(async () => {
    try {
      const json = await AsyncStorage.getItem(SAVED_DEVICES_KEY);
      if (json) {
        const loaded: SavedDevice[] = JSON.parse(json);
        setSavedDevices(loaded);
      }
    } catch (error) {
      console.error('[loadSavedDevices] 加载失败:', error);
    }
  }, []);

  const saveDevice = useCallback(async (device: VeepooDevice) => {
    try {
      const savedDevice: SavedDevice = {
        id: device.id,
        name: device.name,
        mac: device.mac,
        uuid: device.uuid,
        lastConnected: Date.now(),
      };

      setSavedDevices((prev) => {
        const filtered = prev.filter((d) => d.id !== device.id);
        const updated = [savedDevice, ...filtered].slice(0, 5);
        AsyncStorage.setItem(SAVED_DEVICES_KEY, JSON.stringify(updated));
        return updated;
      });
    } catch (error) {
      console.error('[saveDevice] 保存失败:', error);
    }
  }, []);

  const removeSavedDevice = useCallback(async (deviceId: string) => {
    try {
      setSavedDevices((prev) => {
        const updated = prev.filter((d) => d.id !== deviceId);
        AsyncStorage.setItem(SAVED_DEVICES_KEY, JSON.stringify(updated));
        return updated;
      });
    } catch (error) {
      console.error('[removeSavedDevice] 删除失败:', error);
    }
  }, []);

  const resetOnDisconnect = useCallback(() => {
    setConnectedDeviceId(null);
    setIsDeviceReady(false);
    setBattery(null);
  }, []);

  return {
    isInitialized,
    isScanning,
    connectedDeviceId,
    isDeviceReady,
    devices,
    savedDevices,
    battery,
    setIsInitialized,
    setIsScanning,
    setConnectedDeviceId,
    setIsDeviceReady,
    setBattery,
    addDevice,
    clearDevices,
    loadSavedDevices,
    saveDevice,
    removeSavedDevice,
    resetOnDisconnect,
  };
};