import { useEffect, useCallback, useRef } from 'react';
import { PermissionsAndroid, Platform, Alert } from 'react-native';
import VeepooSDK from '@gaozh1024/expo-veepoo-sdk';
import type { ReadOriginProgress, HalfHourData } from '@gaozh1024/expo-veepoo-sdk';
import type { UseDeviceState } from './useDeviceState';
import type { UseTestState } from './useTestState';
import type { UseDataState } from './useDataState';
import type { SleepDataItem, TestType } from '../types';

export interface UseVeepooSDKOptions {
  device: UseDeviceState;
  test: UseTestState;
  data: UseDataState;
  setStatus: (status: string) => void;
}

export const useVeepooSDK = ({ device, test, data, setStatus }: UseVeepooSDKOptions) => {
  const deviceRef = useRef(device);
  const testRef = useRef(test);
  const dataRef = useRef(data);

  useEffect(() => {
    deviceRef.current = device;
    testRef.current = test;
    dataRef.current = data;
  });

  const requestBluetoothPermissions = useCallback(async (): Promise<boolean> => {
    if (Platform.OS !== 'android') {
      return true;
    }

    try {
      if (Number(Platform.Version) >= 31) {
        const granted = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
        ]);

        const allGranted =
          granted['android.permission.BLUETOOTH_SCAN'] === PermissionsAndroid.RESULTS.GRANTED &&
          granted['android.permission.BLUETOOTH_CONNECT'] === PermissionsAndroid.RESULTS.GRANTED &&
          granted['android.permission.ACCESS_FINE_LOCATION'] === PermissionsAndroid.RESULTS.GRANTED;

        if (!allGranted) {
          Alert.alert('权限不足', '需要蓝牙和位置权限才能扫描和连接设备');
          return false;
        }
      } else {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
        );

        if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
          Alert.alert('权限不足', '需要位置权限才能扫描蓝牙设备');
          return false;
        }
      }

      return true;
    } catch (error) {
      console.error('请求权限失败:', error);
      return false;
    }
  }, []);

  const initializeSDK = useCallback(async () => {
    try {
      setStatus('正在请求权限...');

      const hasPermission = await requestBluetoothPermissions();
      if (!hasPermission) {
        setStatus('权限被拒绝');
        return;
      }

      setStatus('正在初始化 SDK...');
      await VeepooSDK.init();
      device.setIsInitialized(true);
      setStatus('SDK 已初始化');

      const isEnabled = await VeepooSDK.checkBluetoothStatus();
      if (!isEnabled) {
        setStatus('请开启蓝牙');
        return;
      }

      setStatus('准备就绪');
    } catch (error) {
      setStatus(`初始化失败: ${error}`);
    }
  }, [requestBluetoothPermissions, device, setStatus]);

  const setupEventListeners = useCallback(() => {
    const handlers = {
      deviceFound: (result: { device: Parameters<typeof device.addDevice>[0] }) => {
        deviceRef.current.addDevice(result.device);
      },

      deviceConnected: (payload: { deviceId: string }) => {
        deviceRef.current.setConnectedDeviceId(payload.deviceId);
        deviceRef.current.setIsScanning(false);
        setStatus('设备已连接，等待验证...');
      },

      deviceDisconnected: () => {
        deviceRef.current.resetOnDisconnect();
        dataRef.current.clearAllData();
        setStatus('设备已断开');
      },

      deviceReady: () => {
        deviceRef.current.setIsDeviceReady(true);
        setStatus('设备准备就绪');
        VeepooSDK.readBattery();
      },

      batteryData: (payload: { data: Parameters<typeof device.setBattery>[0] }) => {
        deviceRef.current.setBattery(payload.data);
      },

      heartRateTestResult: (payload: { result: { state: string; progress?: number } }) => {
        testRef.current.setHeartRateResult(payload.result as Parameters<typeof test.setHeartRateResult>[0]);
        testRef.current.setHeartRateProgress(payload.result.progress ?? 0);
        if (payload.result.state === 'over') {
          testRef.current.setIsTesting(null);
          testRef.current.setHeartRateProgress(0);
        }
      },

      bloodPressureTestResult: (payload: { result: { state: string } }) => {
        testRef.current.setBloodPressureResult(payload.result as Parameters<typeof test.setBloodPressureResult>[0]);
        if (payload.result.state === 'over') {
          testRef.current.setIsTesting(null);
        }
      },

      bloodOxygenTestResult: (payload: { result: { state: string } }) => {
        testRef.current.setBloodOxygenResult(payload.result as Parameters<typeof test.setBloodOxygenResult>[0]);
        if (payload.result.state === 'over') {
          testRef.current.setIsTesting(null);
        }
      },

      temperatureTestResult: (payload: { result: { state: string } }) => {
        testRef.current.setTemperatureResult(payload.result as Parameters<typeof test.setTemperatureResult>[0]);
        if (payload.result.state === 'over') {
          testRef.current.setIsTesting(null);
        }
      },

      stressData: (payload: { data: Parameters<typeof test.setStressData>[0] }) => {
        testRef.current.setStressData(payload.data);
        testRef.current.setIsTesting(null);
      },

      bloodGlucoseData: (payload: { data: Parameters<typeof test.setBloodGlucoseData>[0] }) => {
        testRef.current.setBloodGlucoseData(payload.data);
        testRef.current.setIsTesting(null);
      },

      error: (error: { message: string }) => {
        testRef.current.setIsTesting(null);
        dataRef.current.setIsLoadingData(false);
        Alert.alert('错误', error.message);
      },

      readOriginProgress: (payload: { progress: ReadOriginProgress }) => {
        if (payload.progress.progress !== undefined) {
          const percent = Math.round(payload.progress.progress * 100);
          dataRef.current.setLoadDataProgress(percent);
          setStatus(`正在读取历史数据... ${percent}%`);
        }
      },

      readOriginComplete: () => {
        dataRef.current.setIsLoadingData(false);
        dataRef.current.setLoadDataProgress(100);
        setStatus('历史数据读取完成');
      },

      originHalfHourData: (payload: { data: HalfHourData }) => {
        dataRef.current.addOriginData(payload.data);
      },

      sleepData: (payload: { data: { items: SleepDataItem[] }[] }) => {
        if (payload.data && Array.isArray(payload.data)) {
          const allItems = payload.data.flatMap((d: { items: SleepDataItem[] }) => d.items);
          dataRef.current.setSleepDataList(allItems);
        }
      },

      sportStepData: (payload: { data: Parameters<typeof data.setSportStepData>[0] }) => {
        if (payload.data) {
          dataRef.current.setSportStepData(payload.data);
        }
      },
    };

    Object.entries(handlers).forEach(([event, handler]) => {
      VeepooSDK.on(event as never, handler as never);
    });

    return () => {
      VeepooSDK.removeAllListeners();
    };
  }, [setStatus]);

  useEffect(() => {
    initializeSDK();
    const cleanup = setupEventListeners();
    device.loadSavedDevices();

    return () => {
      cleanup();
    };
  }, []);

  const startScan = useCallback(async () => {
    if (!device.isInitialized) {
      Alert.alert('提示', 'SDK 未初始化');
      return;
    }

    device.clearDevices();
    device.setIsScanning(true);
    setStatus('正在扫描...');

    try {
      await VeepooSDK.startScan({ timeout: 10000 });
    } catch (error) {
      setStatus(`扫描失败: ${error}`);
      device.setIsScanning(false);
    }
  }, [device, setStatus]);

  const stopScan = useCallback(async () => {
    await VeepooSDK.stopScan();
    device.setIsScanning(false);
    setStatus('扫描已停止');
  }, [device, setStatus]);

  const connectDevice = useCallback(async (veepooDevice: { id: string; name: string; mac?: string; uuid?: string }) => {
    try {
      setStatus(`正在连接 ${veepooDevice.name}...`);
      await VeepooSDK.connect(veepooDevice.id, { password: '0000' });
      await device.saveDevice(veepooDevice as Parameters<typeof device.saveDevice>[0]);
    } catch (error) {
      setStatus(`连接失败: ${error}`);
    }
  }, [device, setStatus]);

  const connectSavedDevice = useCallback(async (savedDevice: { id: string; name: string; uuid?: string }) => {
    try {
      setStatus(`正在连接 ${savedDevice.name}...`);
      await VeepooSDK.connect(savedDevice.id, {
        password: '0000',
        uuid: savedDevice.uuid || savedDevice.id,
      });
    } catch (error) {
      setStatus(`连接失败: ${error}`);
      Alert.alert('连接失败', '请确保设备已开启并在附近，或重新扫描设备');
    }
  }, [setStatus]);

  const disconnect = useCallback(async () => {
    if (device.connectedDeviceId) {
      await VeepooSDK.disconnect(device.connectedDeviceId);
    }
  }, [device.connectedDeviceId]);

  const readBattery = useCallback(async () => {
    try {
      const batteryInfo = await VeepooSDK.readBattery();
      device.setBattery(batteryInfo);
    } catch (error) {
      console.error('[readBattery] 读取电量失败:', error);
    }
  }, [device]);

  const fetchSleepData = useCallback(async () => {
    if (!device.isDeviceReady) {
      Alert.alert('提示', '设备未准备就绪');
      return;
    }
    try {
      setStatus('正在获取睡眠数据...');
      const sleepData = await VeepooSDK.readSleepData();
      if (sleepData && sleepData.length > 0) {
        const allItems = sleepData.flatMap(d => d.items);
        data.setSleepDataList(allItems);
        setStatus('睡眠数据获取成功');
      } else {
        setStatus('暂无睡眠数据');
      }
    } catch (error) {
      setStatus(`获取失败: ${error}`);
    }
  }, [device.isDeviceReady, data, setStatus]);

  const fetchSportData = useCallback(async () => {
    if (!device.isDeviceReady) {
      Alert.alert('提示', '设备未准备就绪');
      return;
    }
    try {
      setStatus('正在获取运动数据...');
      const sportData = await VeepooSDK.readSportStepData();
      if (sportData) {
        data.setSportStepData(sportData);
        setStatus('运动数据获取成功');
      } else {
        setStatus('暂无运动数据');
      }
    } catch (error) {
      setStatus(`获取失败: ${error}`);
    }
  }, [device.isDeviceReady, data, setStatus]);

  const fetchHistoryData = useCallback(async () => {
    if (!device.isDeviceReady) {
      Alert.alert('提示', '设备未准备就绪');
      return;
    }
    try {
      setStatus('正在获取历史数据...');
      data.setIsLoadingData(true);
      data.setLoadDataProgress(0);
      data.clearOriginData();
      await VeepooSDK.startReadOriginData();
      setStatus('历史数据获取成功');
    } catch (error) {
      setStatus(`获取失败: ${error}`);
    } finally {
      data.setIsLoadingData(false);
    }
  }, [device.isDeviceReady, data, setStatus]);

  const TEST_ACTIONS: Record<TestType, { start: () => Promise<void>; stop: () => Promise<void> }> = {
    heartRate: { start: VeepooSDK.startHeartRateTest, stop: VeepooSDK.stopHeartRateTest },
    bloodPressure: { start: VeepooSDK.startBloodPressureTest, stop: VeepooSDK.stopBloodPressureTest },
    bloodOxygen: { start: VeepooSDK.startBloodOxygenTest, stop: VeepooSDK.stopBloodOxygenTest },
    temperature: { start: VeepooSDK.startTemperatureTest, stop: VeepooSDK.stopTemperatureTest },
    stress: { start: VeepooSDK.startStressTest, stop: VeepooSDK.stopStressTest },
    bloodGlucose: { start: VeepooSDK.startBloodGlucoseTest, stop: VeepooSDK.stopBloodGlucoseTest },
  };

  const startTest = useCallback(async (testType: TestType) => {
    if (!device.isDeviceReady) {
      Alert.alert('提示', '设备未准备就绪');
      return;
    }

    test.setIsTesting(testType);

    try {
      await TEST_ACTIONS[testType].start();
    } catch (error) {
      test.setIsTesting(null);
    }
  }, [device.isDeviceReady, test]);

  const stopTest = useCallback(async (testType: TestType) => {
    test.setIsTesting(null);

    try {
      await TEST_ACTIONS[testType].stop();
    } catch (error) {
      console.error(`[stopTest] ${testType} 停止失败:`, error);
    }
  }, [test]);

  return {
    startScan,
    stopScan,
    connectDevice,
    connectSavedDevice,
    disconnect,
    readBattery,
    fetchSleepData,
    fetchSportData,
    fetchHistoryData,
    startTest,
    stopTest,
  };
};