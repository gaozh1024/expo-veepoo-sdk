import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  Button,
  FlatList,
  StyleSheet,
  ScrollView,
  Alert,
  ActivityIndicator,
  PermissionsAndroid,
  Platform,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import VeepooSDK, {
  VeepooDevice,
  VeepooError,
  HeartRateTestResult,
  BloodPressureTestResult,
  BloodOxygenTestResult,
  TemperatureTestResult,
  StressData,
  BloodGlucoseData,
  BatteryInfo,
  ReadOriginProgress,
  HalfHourData,
  SleepData,
  SportStepData,
} from '@gaozh1024/expo-veepoo-sdk';

const SAVED_DEVICES_KEY = '@veepoo_saved_devices';

interface SavedDevice {
  id: string;
  name: string;
  mac?: string;
  uuid?: string;
  lastConnected: number;
}

export default function HomeScreen() {
  const [isInitialized, setIsInitialized] = useState(false);
  const [devices, setDevices] = useState<VeepooDevice[]>([]);
  const [savedDevices, setSavedDevices] = useState<SavedDevice[]>([]);
  const [isScanning, setIsScanning] = useState(false);
  const [connectedDeviceId, setConnectedDeviceId] = useState<string | null>(null);
  const [isDeviceReady, setIsDeviceReady] = useState(false);
  const [status, setStatus] = useState('准备就绪');
  const [battery, setBattery] = useState<BatteryInfo | null>(null);

  const [heartRateResult, setHeartRateResult] = useState<HeartRateTestResult | null>(null);
  const [bloodPressureResult, setBloodPressureResult] = useState<BloodPressureTestResult | null>(null);
  const [bloodOxygenResult, setBloodOxygenResult] = useState<BloodOxygenTestResult | null>(null);
  const [temperatureResult, setTemperatureResult] = useState<TemperatureTestResult | null>(null);
  const [stressData, setStressData] = useState<StressData | null>(null);
  const [bloodGlucoseData, setBloodGlucoseData] = useState<BloodGlucoseData | null>(null);

  const [isTesting, setIsTesting] = useState<string | null>(null);

  const [isLoadingData, setIsLoadingData] = useState(false);
  const [loadDataProgress, setLoadDataProgress] = useState(0);
  const [originDataList, setOriginDataList] = useState<HalfHourData[]>([]);
  const [sleepDataList, setSleepDataList] = useState<SleepData[]>([]);
  const [sportStepData, setSportStepData] = useState<SportStepData | null>(null);
  
  const sportSummary = React.useMemo(() => {
    const totalSteps = originDataList.reduce((sum, d) => sum + (d.stepValue || 0), 0);
    const totalDistance = originDataList.reduce((sum, d) => sum + (d.disValue || 0), 0);
    const totalCalories = originDataList.reduce((sum, d) => sum + (d.calValue || 0), 0);
    const avgHeartRate = originDataList.filter(d => d.heartValue && d.heartValue > 0).length > 0
      ? Math.round(originDataList.filter(d => d.heartValue && d.heartValue > 0).reduce((sum, d) => sum + (d.heartValue || 0), 0) / originDataList.filter(d => d.heartValue && d.heartValue > 0).length)
      : 0;
    return { totalSteps, totalDistance, totalCalories, avgHeartRate };
  }, [originDataList]);

  // 加载已保存的设备列表
  const loadSavedDevices = async () => {
    try {
      const json = await AsyncStorage.getItem(SAVED_DEVICES_KEY);
      if (json) {
        const devices: SavedDevice[] = JSON.parse(json);
        setSavedDevices(devices);
        console.log('[loadSavedDevices] 已加载保存的设备:', devices.length, '个');
      }
    } catch (error) {
      console.error('[loadSavedDevices] 加载失败:', error);
    }
  };

  // 保存设备到缓存
  const saveDevice = async (device: VeepooDevice) => {
    try {
      const savedDevice: SavedDevice = {
        id: device.id,
        name: device.name,
        mac: device.mac,
        uuid: device.uuid,
        lastConnected: Date.now(),
      };
      
      let devices = savedDevices.filter(d => d.id !== device.id);
      devices.unshift(savedDevice);
      devices = devices.slice(0, 5);
      
      await AsyncStorage.setItem(SAVED_DEVICES_KEY, JSON.stringify(devices));
      setSavedDevices(devices);
      console.log('[saveDevice] 已保存设备:', device.name);
    } catch (error) {
      console.error('[saveDevice] 保存失败:', error);
    }
  };

  // 删除已保存的设备
  const removeSavedDevice = async (deviceId: string) => {
    try {
      const devices = savedDevices.filter(d => d.id !== deviceId);
      await AsyncStorage.setItem(SAVED_DEVICES_KEY, JSON.stringify(devices));
      setSavedDevices(devices);
      console.log('[removeSavedDevice] 已删除设备:', deviceId);
    } catch (error) {
      console.error('[removeSavedDevice] 删除失败:', error);
    }
  };

  useEffect(() => {
    initializeSDK();
    setupEventListeners();
    loadSavedDevices();
    return () => {
      VeepooSDK.removeAllListeners();
    };
  }, []);

  const requestBluetoothPermissions = async (): Promise<boolean> => {
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
  };

  const initializeSDK = async () => {
    try {
      setStatus('正在请求权限...');
      
      const hasPermission = await requestBluetoothPermissions();
      if (!hasPermission) {
        setStatus('权限被拒绝');
        return;
      }

      setStatus('正在初始化 SDK...');
      await VeepooSDK.init();
      setIsInitialized(true);
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
  };

  const setupEventListeners = () => {
    VeepooSDK.on('deviceFound', (result) => {
      console.log('[deviceFound]', JSON.stringify(result, null, 2));
      setDevices((prev) => {
        const exists = prev.find((d) => d.id === result.device.id);
        return exists ? prev : [...prev, result.device];
      });
    });

    VeepooSDK.on('deviceConnected', (payload) => {
      console.log('[deviceConnected]', JSON.stringify(payload, null, 2));
      setConnectedDeviceId(payload.deviceId);
      setIsScanning(false);
      setStatus('设备已连接，等待验证...');
    });

    VeepooSDK.on('deviceDisconnected', (payload) => {
      console.log('[deviceDisconnected]', JSON.stringify(payload, null, 2));
      setConnectedDeviceId(null);
      setIsDeviceReady(false);
      setBattery(null);
      setStatus('设备已断开');
      setIsLoadingData(false);
      setLoadDataProgress(0);
      setOriginDataList([]);
    });

    VeepooSDK.on('deviceReady', (payload) => {
      console.log('[deviceReady]', JSON.stringify(payload, null, 2));
      setIsDeviceReady(true);
      setStatus('设备准备就绪，正在读取历史数据...');
      readBattery();
      startReadOriginData();
    });

    VeepooSDK.on('batteryData', (payload) => {
      console.log('[batteryData]', JSON.stringify(payload, null, 2));
      setBattery(payload.data);
    });

    VeepooSDK.on('heartRateTestResult', (payload) => {
      console.log('[heartRateTestResult]', JSON.stringify(payload, null, 2));
      setHeartRateResult(payload.result);
      setHeartRateProgress(payload.result.progress ?? 0);
      if (payload.result.state === 'over') {
        setIsTesting(null);
        setHeartRateProgress(0);
      }
    });

    VeepooSDK.on('bloodPressureTestResult', (payload) => {
      console.log('[bloodPressureTestResult]', JSON.stringify(payload, null, 2));
      setBloodPressureResult(payload.result);
      if (payload.result.state === 'over') {
        setIsTesting(null);
      }
    });

    VeepooSDK.on('bloodOxygenTestResult', (payload) => {
      console.log('[bloodOxygenTestResult]', JSON.stringify(payload, null, 2));
      setBloodOxygenResult(payload.result);
      if (payload.result.state === 'over') {
        setIsTesting(null);
      }
    });

    VeepooSDK.on('temperatureTestResult', (payload) => {
      console.log('[temperatureTestResult]', JSON.stringify(payload, null, 2));
      setTemperatureResult(payload.result);
      if (payload.result.state === 'over') {
        setIsTesting(null);
      }
    });

    VeepooSDK.on('stressData', (payload) => {
      console.log('[stressData]', JSON.stringify(payload, null, 2));
      setStressData(payload.data);
      setIsTesting(null);
    });

    VeepooSDK.on('bloodGlucoseData', (payload) => {
      console.log('[bloodGlucoseData]', JSON.stringify(payload, null, 2));
      setBloodGlucoseData(payload.data);
      setIsTesting(null);
    });

    VeepooSDK.on('error', (error: VeepooError) => {
      console.error('[error]', JSON.stringify(error, null, 2));
      setIsTesting(null);
      setIsLoadingData(false);
      Alert.alert('错误', error.message);
    });

    VeepooSDK.on('readOriginProgress', (payload) => {
      console.log('[readOriginProgress]', JSON.stringify(payload, null, 2));
      const progress = payload.progress as ReadOriginProgress;
      if (progress.progress !== undefined) {
        const percent = Math.round(progress.progress * 100);
        setLoadDataProgress(percent);
        setStatus(`正在读取历史数据... ${percent}%`);
      }
    });

    VeepooSDK.on('readOriginComplete', (payload) => {
      console.log('[readOriginComplete]', JSON.stringify(payload, null, 2));
      setIsLoadingData(false);
      setLoadDataProgress(100);
      setStatus('历史数据读取完成');
      console.log('[历史数据读取完成] 共读取', originDataList.length, '条数据');
    });

    VeepooSDK.on('originHalfHourData', (payload) => {
      console.log('[originHalfHourData]', JSON.stringify(payload, null, 2));
      const data = payload.data as HalfHourData;
      setOriginDataList((prev) => [...prev, data]);
    });

    VeepooSDK.on('sleepData', (payload) => {
      console.log('[sleepData]', JSON.stringify(payload, null, 2));
      if (payload.data && Array.isArray(payload.data)) {
        setSleepDataList(payload.data);
      }
    });

    VeepooSDK.on('sportStepData', (payload) => {
      console.log('[sportStepData]', JSON.stringify(payload, null, 2));
      if (payload.data) {
        setSportStepData(payload.data);
      }
    });
  };

  const startScan = async () => {
    if (!isInitialized) {
      Alert.alert('提示', 'SDK 未初始化');
      return;
    }

    setDevices([]);
    setIsScanning(true);
    setStatus('正在扫描...');

    try {
      console.log('[startScan] 开始扫描...');
      await VeepooSDK.startScan({ timeout: 10000 });
    } catch (error) {
      console.error('[startScan] 扫描失败:', error);
      setStatus(`扫描失败: ${error}`);
      setIsScanning(false);
    }
  };

  const stopScan = async () => {
    console.log('[stopScan] 停止扫描');
    await VeepooSDK.stopScan();
    setIsScanning(false);
    setStatus('扫描已停止');
  };

  const connectDevice = async (device: VeepooDevice) => {
    try {
      console.log('[connectDevice] 连接设备:', device);
      setStatus(`正在连接 ${device.name}...`);
      await VeepooSDK.connect(device.id, { password: '0000' });
      await saveDevice(device);
      console.log('[connectDevice] 连接命令已发送');
    } catch (error) {
      console.error('[connectDevice] 连接失败:', error);
      setStatus(`连接失败: ${error}`);
    }
  };

  const connectSavedDevice = async (savedDevice: SavedDevice) => {
    try {
      console.log('[connectSavedDevice] 连接历史设备:', savedDevice);
      setStatus(`正在连接 ${savedDevice.name}...`);
      await VeepooSDK.connect(savedDevice.id, { 
        password: '0000',
        uuid: savedDevice.uuid || savedDevice.id
      });
      console.log('[connectSavedDevice] 连接命令已发送');
    } catch (error) {
      console.error('[connectSavedDevice] 连接失败:', error);
      setStatus(`连接失败: ${error}`);
      Alert.alert('连接失败', '请确保设备已开启并在附近，或重新扫描设备');
    }
  };

  const disconnect = async () => {
    if (connectedDeviceId) {
      console.log('[disconnect] 断开设备:', connectedDeviceId);
      await VeepooSDK.disconnect(connectedDeviceId);
    }
  };

  const readBattery = async () => {
    try {
      console.log('[readBattery] 读取电量...');
      const batteryInfo = await VeepooSDK.readBattery();
      console.log('[readBattery] 电量数据:', JSON.stringify(batteryInfo, null, 2));
      setBattery(batteryInfo);
    } catch (error) {
      console.error('[readBattery] 读取电量失败:', error);
    }
  };

  const startReadOriginData = async () => {
    try {
      console.log('[startReadOriginData] 开始读取历史数据...');
      setIsLoadingData(true);
      setLoadDataProgress(0);
      setOriginDataList([]);
      setSleepDataList([]);
      setSportStepData(null);
      
      await VeepooSDK.startReadOriginData();
      
      const sleepData = await VeepooSDK.readSleepData();
      console.log('[readSleepData] 睡眠数据:', sleepData);
      if (sleepData && sleepData.length > 0) {
        setSleepDataList(sleepData);
      }
      
      const sportData = await VeepooSDK.readSportStepData();
      console.log('[readSportStepData] 运动数据:', sportData);
      if (sportData) {
        setSportStepData(sportData);
      }
      
      console.log('[startReadOriginData] 读取历史数据命令已发送');
    } catch (error) {
      console.error('[startReadOriginData] 读取历史数据失败:', error);
      setIsLoadingData(false);
    }
  };

  const syncAllData = async () => {
    try {
      console.log('[syncAllData] 开始同步所有数据...');
      setIsLoadingData(true);
      setLoadDataProgress(0);
      setOriginDataList([]);
      setSleepDataList([]);
      setSportStepData(null);
      setStatus('正在同步设备数据...');
      
      const success = await VeepooSDK.readDeviceAllData();
      console.log('[syncAllData] 同步结果:', success);
      
      if (success) {
        setStatus('数据同步完成，正在读取...');
        
        const sleepData = await VeepooSDK.readSleepData();
        console.log('[syncAllData] 睡眠数据:', sleepData);
        if (sleepData && sleepData.length > 0) {
          setSleepDataList(sleepData);
        }
        
        const sportData = await VeepooSDK.readSportStepData();
        console.log('[syncAllData] 运动数据:', sportData);
        if (sportData) {
          setSportStepData(sportData);
        }
        
        setStatus('数据读取完成');
      } else {
        setStatus('数据同步失败');
      }
    } catch (error) {
      console.error('[syncAllData] 同步数据失败:', error);
      setStatus(`同步失败: ${error}`);
    } finally {
      setIsLoadingData(false);
    }
  };

  const refreshSportData = async () => {
    try {
      console.log('[refreshSportData] 重新获取运动数据...');
      setStatus('正在获取运动数据...');
      
      const sportData = await VeepooSDK.readSportStepData();
      console.log('[refreshSportData] 运动数据:', sportData);
      if (sportData) {
        setSportStepData(sportData);
        setStatus('运动数据获取成功');
      } else {
        setStatus('暂无运动数据');
      }
    } catch (error) {
      console.error('[refreshSportData] 获取运动数据失败:', error);
      setStatus(`获取失败: ${error}`);
    }
  };

  const [heartRateProgress, setHeartRateProgress] = useState<number>(0);

  const startTest = async (testType: string) => {
    if (!isDeviceReady) {
      Alert.alert('提示', '设备未准备就绪');
      return;
    }

    console.log(`[startTest] 开始 ${testType} 测试`);
    setIsTesting(testType);

    try {
      switch (testType) {
        case 'heartRate':
          await VeepooSDK.startHeartRateTest();
          break;
        case 'bloodPressure':
          await VeepooSDK.startBloodPressureTest();
          break;
        case 'bloodOxygen':
          await VeepooSDK.startBloodOxygenTest();
          break;
        case 'temperature':
          await VeepooSDK.startTemperatureTest();
          break;
        case 'stress':
          await VeepooSDK.startStressTest();
          break;
        case 'bloodGlucose':
          await VeepooSDK.startBloodGlucoseTest();
          break;
      }
      console.log(`[startTest] ${testType} 测试命令已发送`);
    } catch (error) {
      console.error(`[startTest] ${testType} 测试失败:`, error);
      setIsTesting(null);
    }
  };

  const stopTest = async (testType: string) => {
    console.log(`[stopTest] 停止 ${testType} 测试`);
    setIsTesting(null);

    try {
      switch (testType) {
        case 'heartRate':
          await VeepooSDK.stopHeartRateTest();
          break;
        case 'bloodPressure':
          await VeepooSDK.stopBloodPressureTest();
          break;
        case 'bloodOxygen':
          await VeepooSDK.stopBloodOxygenTest();
          break;
        case 'temperature':
          await VeepooSDK.stopTemperatureTest();
          break;
        case 'stress':
          await VeepooSDK.stopStressTest();
          break;
        case 'bloodGlucose':
          await VeepooSDK.stopBloodGlucoseTest();
          break;
      }
      console.log(`[stopTest] ${testType} 停止命令已发送`);
    } catch (error) {
      console.error(`[stopTest] ${testType} 停止失败:`, error);
    }
  };

  const renderDevice = useCallback(
    ({ item }: { item: VeepooDevice }) => (
      <View style={styles.deviceItem}>
        <View style={styles.deviceInfo}>
          <Text style={styles.deviceName}>{item.name}</Text>
          <Text style={styles.deviceMac}>MAC: {item.mac || item.id}</Text>
          <Text style={styles.deviceRssi}>信号: {item.rssi} dBm</Text>
        </View>
        <Button
          title="连接"
          onPress={() => connectDevice(item)}
          disabled={connectedDeviceId !== null}
        />
      </View>
    ),
    [connectedDeviceId]
  );

  const renderSavedDevice = useCallback(
    ({ item }: { item: SavedDevice }) => (
      <View style={styles.savedDeviceItem}>
        <View style={styles.deviceInfo}>
          <Text style={styles.deviceName}>{item.name}</Text>
          <Text style={styles.deviceMac}>ID: {item.id}</Text>
          <Text style={styles.savedDeviceTime}>
            上次连接: {new Date(item.lastConnected).toLocaleDateString()}
          </Text>
        </View>
        <View style={styles.savedDeviceButtons}>
          <Button
            title="连接"
            onPress={() => connectSavedDevice(item)}
            disabled={connectedDeviceId !== null}
          />
          <Button
            title="删除"
            onPress={() => removeSavedDevice(item.id)}
            color="#FF3B30"
          />
        </View>
      </View>
    ),
    [connectedDeviceId]
  );

  const renderTestResult = (label: string, value: string | null | undefined, unit: string = '') => {
    if (value === null || value === undefined) return <></>;
    return (
      <View style={styles.resultRow}>
        <Text style={styles.resultLabel}>{label}:</Text>
        <Text style={styles.resultValue}>{value} {unit}</Text>
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        <Text style={styles.title}>Veepoo SDK 测试</Text>
        <Text style={styles.status}>状态: {status}</Text>

        {(isLoadingData || (connectedDeviceId && isDeviceReady && loadDataProgress < 100)) && (
          <View style={styles.loadingDataContainer}>
            <ActivityIndicator size="large" color="#007AFF" />
            <Text style={styles.loadingDataText}>正在读取历史数据...</Text>
            <View style={styles.progressBarContainer}>
              <View style={[styles.progressBarFill, { width: `${loadDataProgress}%` }]} />
            </View>
            <Text style={styles.progressText}>{loadDataProgress}%</Text>
          </View>
        )}

        {battery && !isLoadingData && (
          <View style={styles.batteryInfo}>
            <Text>
              电量: {battery.percent > 0 ? battery.percent : battery.level}%{battery.isLowBattery ? ' 电量低' : ''}
            </Text>
          </View>
        )}

        {!connectedDeviceId ? (
          <>
            <View style={styles.buttonContainer}>
              {!isScanning ? (
                <Button title="开始扫描" onPress={startScan} disabled={!isInitialized} />
              ) : (
                <Button title="停止扫描" onPress={stopScan} />
              )}
            </View>

            {savedDevices.length > 0 && (
              <>
                <Text style={styles.sectionTitle}>📱 历史设备 ({savedDevices.length})</Text>
                <FlatList
                  data={savedDevices}
                  keyExtractor={(item) => item.id}
                  renderItem={renderSavedDevice}
                  style={styles.deviceList}
                  scrollEnabled={false}
                />
              </>
            )}

            <Text style={styles.sectionTitle}>扫描到的设备 ({devices.length})</Text>
            <FlatList
              data={devices}
              keyExtractor={(item) => item.id}
              renderItem={renderDevice}
              style={styles.deviceList}
              scrollEnabled={false}
            />
          </>
        ) : (
          <>
            <View style={styles.connectedInfo}>
              <Text style={styles.connectedText}>已连接: {connectedDeviceId}</Text>
              <Button title="断开连接" onPress={disconnect} />
            </View>

            {isDeviceReady && (
              <View style={styles.testSection}>
                <Text style={styles.sectionTitle}>📊 健康数据</Text>
                
                <View style={styles.testButtonRow}>
                  <Button
                    title={isLoadingData ? '同步中...' : '同步设备数据'}
                    onPress={syncAllData}
                    disabled={isLoadingData}
                  />
                  <Button
                    title="刷新数据"
                    onPress={startReadOriginData}
                    disabled={isLoadingData}
                  />
                </View>
              </View>
            )}

            {isDeviceReady && (
              <View style={styles.testSection}>
                <Text style={styles.sectionTitle}>健康测试</Text>

                <View style={styles.testButtonRow}>
                  <Button
                    title={isTesting === 'heartRate' ? '测试中...' : '心率测试'}
                    onPress={() => startTest('heartRate')}
                    disabled={isTesting !== null && isTesting !== 'heartRate'}
                  />
                  <Button
                    title={isTesting === 'heartRate' ? '停止' : '停止'}
                    onPress={() => stopTest('heartRate')}
                    disabled={isTesting !== 'heartRate'}
                  />
                </View>
                {heartRateResult && (
                  <View style={styles.resultBox}>
                    {renderTestResult('状态', heartRateResult.state)}
                    {heartRateResult.value && renderTestResult('心率', String(heartRateResult.value), 'bpm')}
                    {heartRateResult.progress !== undefined && renderTestResult('进度', String(heartRateResult.progress))}
                  </View>
                )}

                <View style={styles.testButtonRow}>
                  <Button
                    title={isTesting === 'bloodPressure' ? '测试中...' : '血压测试'}
                    onPress={() => startTest('bloodPressure')}
                    disabled={isTesting !== null}
                  />
                  <Button
                    title={isTesting === 'bloodPressure' ? '停止' : '停止'}
                    onPress={() => stopTest('bloodPressure')}
                    disabled={isTesting !== 'bloodPressure'}
                  />
                </View>
                {bloodPressureResult && (
                  <View style={styles.resultBox}>
                    {renderTestResult('状态', bloodPressureResult.state)}
                    {bloodPressureResult.progress !== undefined && renderTestResult('进度', String(bloodPressureResult.progress))}
                    {bloodPressureResult.systolic && renderTestResult('收缩压', String(bloodPressureResult.systolic), 'mmHg')}
                    {bloodPressureResult.diastolic && renderTestResult('舒张压', String(bloodPressureResult.diastolic), 'mmHg')}
                    {bloodPressureResult.pulse && renderTestResult('脉搏', String(bloodPressureResult.pulse), 'bpm')}
                  </View>
                )}

                <View style={styles.testButtonRow}>
                  <Button
                    title={isTesting === 'bloodOxygen' ? '测试中...' : '血氧测试'}
                    onPress={() => startTest('bloodOxygen')}
                    disabled={isTesting !== null}
                  />
                  <Button
                    title={isTesting === 'bloodOxygen' ? '停止' : '停止'}
                    onPress={() => stopTest('bloodOxygen')}
                    disabled={isTesting !== 'bloodOxygen'}
                  />
                </View>
                {bloodOxygenResult && (
                  <View style={styles.resultBox}>
                    {renderTestResult('状态', bloodOxygenResult.state)}
                    {bloodOxygenResult.value && renderTestResult('血氧', String(bloodOxygenResult.value), '%')}
                  </View>
                )}

                <View style={styles.testButtonRow}>
                  <Button
                    title={isTesting === 'temperature' ? '测试中...' : '体温测试'}
                    onPress={() => startTest('temperature')}
                    disabled={isTesting !== null}
                  />
                  <Button
                    title={isTesting === 'temperature' ? '停止' : '停止'}
                    onPress={() => stopTest('temperature')}
                    disabled={isTesting !== 'temperature'}
                  />
                </View>
                {temperatureResult && (
                  <View style={styles.resultBox}>
                    {renderTestResult('状态', temperatureResult.state)}
                    {temperatureResult.value && renderTestResult('体温', String(temperatureResult.value.toFixed(1)), '℃')}
                  </View>
                )}

                <View style={styles.testButtonRow}>
                  <Button
                    title={isTesting === 'stress' ? '测试中...' : '压力测试'}
                    onPress={() => startTest('stress')}
                    disabled={isTesting !== null}
                  />
                  <Button
                    title={isTesting === 'stress' ? '停止' : '停止'}
                    onPress={() => stopTest('stress')}
                    disabled={isTesting !== 'stress'}
                  />
                </View>
                {stressData && (
                  <View style={styles.resultBox}>
                    {renderTestResult('压力值', String(stressData.stress))}
                  </View>
                )}

                <View style={styles.testButtonRow}>
                  <Button
                    title={isTesting === 'bloodGlucose' ? '测试中...' : '血糖测试'}
                    onPress={() => startTest('bloodGlucose')}
                    disabled={isTesting !== null}
                  />
                  <Button
                    title={isTesting === 'bloodGlucose' ? '停止' : '停止'}
                    onPress={() => stopTest('bloodGlucose')}
                    disabled={isTesting !== 'bloodGlucose'}
                  />
                </View>
                {bloodGlucoseData && (
                  <View style={styles.resultBox}>
                    {renderTestResult('血糖值', String(bloodGlucoseData.glucose), 'mmol/L')}
                  </View>
                )}
              </View>
            )}

            {isDeviceReady && !isTesting && (
              <View style={styles.dataSection}>
                <View style={styles.dataSectionHeader}>
                  <Text style={styles.sectionTitle}>📊 健康数据</Text>
                  <Button 
                    title="刷新数据" 
                    onPress={startReadOriginData} 
                    disabled={isLoadingData}
                  />
                </View>
                
                <View style={styles.sportSection}>
                  <View style={styles.dataSectionHeader}>
                    <Text style={styles.subSectionTitle}>🏃 运动数据</Text>
                    <Button 
                      title="重新获取" 
                      onPress={refreshSportData} 
                      disabled={isLoadingData}
                    />
                  </View>
                  {sportStepData ? (
                    <View style={styles.summaryGrid}>
                      <View style={styles.summaryItem}>
                        <Text style={styles.summaryValue}>{(sportStepData.stepCount || 0).toLocaleString()}</Text>
                        <Text style={styles.summaryLabel}>步数</Text>
                      </View>
                      <View style={styles.summaryItem}>
                        <Text style={styles.summaryValue}>{(sportStepData.distance || 0).toFixed(2)}</Text>
                        <Text style={styles.summaryLabel}>距离 (km)</Text>
                      </View>
                      <View style={styles.summaryItem}>
                        <Text style={styles.summaryValue}>{(sportStepData.calories || 0).toFixed(0)}</Text>
                        <Text style={styles.summaryLabel}>卡路里 (kcal)</Text>
                      </View>
                      <View style={styles.summaryItem}>
                        <Text style={styles.summaryValue}>{sportSummary.avgHeartRate || '--'}</Text>
                        <Text style={styles.summaryLabel}>平均心率</Text>
                      </View>
                    </View>
                  ) : (
                    <View style={styles.emptyDataBox}>
                      <Text style={styles.emptyDataText}>暂无运动数据</Text>
                      <Text style={styles.emptyDataHint}>点击"刷新数据"读取设备数据</Text>
                    </View>
                  )}
                </View>

                <View style={styles.sleepSection}>
                  <Text style={styles.subSectionTitle}>😴 睡眠数据</Text>
                  {sleepDataList.length > 0 ? (
                    sleepDataList.map((sleep, index) => (
                      <View key={index} style={styles.sleepCard}>
                        <View style={styles.sleepHeader}>
                          <Text style={styles.sleepTime}>
                            {sleep.sleepTime} → {sleep.wakeTime}
                          </Text>
                          <Text style={styles.sleepScore}>评分: {sleep.sleepLevel}/5</Text>
                        </View>
                        <View style={styles.sleepStats}>
                          <View style={styles.sleepStatItem}>
                            <Text style={styles.sleepStatValue}>{sleep.deepSleepDuration}</Text>
                            <Text style={styles.sleepStatLabel}>深睡(小时)</Text>
                          </View>
                          <View style={styles.sleepStatItem}>
                            <Text style={styles.sleepStatValue}>{sleep.lightSleepDuration}</Text>
                            <Text style={styles.sleepStatLabel}>浅睡(小时)</Text>
                          </View>
                          <View style={styles.sleepStatItem}>
                            <Text style={styles.sleepStatValue}>{sleep.totalSleepHours}h {sleep.totalSleepMinutes}m</Text>
                            <Text style={styles.sleepStatLabel}>总睡眠</Text>
                          </View>
                          <View style={styles.sleepStatItem}>
                            <Text style={styles.sleepStatValue}>{sleep.wakeUpCount}</Text>
                            <Text style={styles.sleepStatLabel}>清醒次数</Text>
                          </View>
                        </View>
                      </View>
                    ))
                  ) : (
                    <View style={styles.emptyDataBox}>
                      <Text style={styles.emptyDataText}>暂无睡眠数据</Text>
                      <Text style={styles.emptyDataHint}>请确保昨晚佩戴设备睡眠</Text>
                    </View>
                  )}
                </View>

                {originDataList.length > 0 && (
                  <View style={styles.halfHourSection}>
                    <Text style={styles.subSectionTitle}>📈 半小时数据 ({originDataList.length} 条)</Text>
                    <FlatList
                      data={originDataList.slice(-10).reverse()}
                      keyExtractor={(item, index) => `${item.time}-${index}`}
                      scrollEnabled={false}
                      renderItem={({ item }) => (
                        <View style={styles.dataRow}>
                          <Text style={styles.dataTime}>{item.time}</Text>
                          <View style={styles.dataMetrics}>
                            {item.heartValue !== undefined && item.heartValue > 0 && (
                              <Text style={styles.metricBadge}>❤️ {item.heartValue}</Text>
                            )}
                            {item.stepValue !== undefined && item.stepValue > 0 && (
                              <Text style={styles.metricBadge}>👟 {item.stepValue}</Text>
                            )}
                            {item.disValue !== undefined && item.disValue > 0 && (
                              <Text style={styles.metricBadge}>📏 {(item.disValue / 1000).toFixed(2)}km</Text>
                            )}
                            {item.calValue !== undefined && item.calValue > 0 && (
                              <Text style={styles.metricBadge}>🔥 {item.calValue}kcal</Text>
                            )}
                            {item.sportValue !== undefined && item.sportValue > 0 && (
                              <Text style={styles.metricBadge}>🏃 {item.sportValue}</Text>
                            )}
                            {item.spo2Value !== undefined && item.spo2Value > 0 && (
                              <Text style={styles.metricBadge}>🫁 {item.spo2Value}%</Text>
                            )}
                          </View>
                        </View>
                      )}
                    />
                    {originDataList.length > 10 && (
                      <Text style={styles.moreDataHint}>仅显示最近 10 条数据</Text>
                    )}
                  </View>
                )}

                {sleepDataList.length === 0 && !sportStepData && originDataList.length === 0 && !isLoadingData && (
                  <View style={styles.emptyDataContainer}>
                    <Text style={styles.emptyDataText}>暂无历史数据</Text>
                    <Text style={styles.emptyDataHint}>请确保设备已同步数据，然后点击"刷新数据"</Text>
                  </View>
                )}
              </View>
            )}

            {isTesting && (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color="#007AFF" />
                <Text style={styles.loadingText}>测试中，请保持佩戴...</Text>
              </View>
            )}
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  scrollView: {
    flex: 1,
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 8,
    textAlign: 'center',
  },
  status: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
    textAlign: 'center',
  },
  batteryInfo: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  lowBattery: {
    color: 'red',
    marginLeft: 8,
  },
  buttonContainer: {
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 16,
    marginBottom: 8,
  },
  deviceList: {
    flexGrow: 0,
  },
  deviceItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#f5f5f5',
    borderRadius: 8,
    marginBottom: 8,
  },
  deviceInfo: {
    flex: 1,
  },
  deviceName: {
    fontSize: 16,
    fontWeight: '500',
  },
  deviceMac: {
    fontSize: 12,
    color: '#666',
  },
  deviceRssi: {
    fontSize: 12,
    color: '#999',
  },
  savedDeviceItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#e3f2fd',
    borderRadius: 8,
    marginBottom: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#2196F3',
  },
  savedDeviceTime: {
    fontSize: 11,
    color: '#888',
    marginTop: 2,
  },
  savedDeviceButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  connectedInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#e8f5e9',
    borderRadius: 8,
    marginBottom: 16,
  },
  connectedText: {
    fontSize: 14,
    fontWeight: '500',
  },
  testSection: {
    marginTop: 16,
  },
  testButtonRow: {
    marginVertical: 8,
  },
  resultBox: {
    backgroundColor: '#f0f0f0',
    padding: 12,
    borderRadius: 8,
    marginTop: 4,
    marginBottom: 12,
  },
  resultRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  resultLabel: {
    fontSize: 14,
    color: '#666',
  },
  resultValue: {
    fontSize: 14,
    fontWeight: '500',
  },
  loadingContainer: {
    alignItems: 'center',
    marginTop: 20,
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
    color: '#666',
  },
  progressBarContainer: {
    width: '100%',
    height: 8,
    backgroundColor: '#e0e0e0',
    borderRadius: 4,
    marginTop: 12,
    overflow: 'hidden',
  },
  progressFill: {
    height: 8,
    backgroundColor: '#007AFF',
    borderRadius: 4,
  },
  progressText: {
    fontSize: 12,
    color: '#fff',
    fontWeight: '500',
  },
  loadingDataContainer: {
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f0f8ff',
    borderRadius: 12,
    marginBottom: 16,
  },
  loadingDataText: {
    marginTop: 12,
    fontSize: 16,
    fontWeight: '500',
    color: '#007AFF',
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: '#007AFF',
    borderRadius: 4,
  },
  dataSection: {
    marginTop: 16,
    padding: 12,
    backgroundColor: '#f8f9f9',
    borderRadius: 8,
  },
  summaryGrid: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    flexWrap: 'wrap',
    marginBottom: 8,
  },
  summaryItem: {
    flex: 1,
    minWidth: '45%',
    alignItems: 'center',
    padding: 8,
    backgroundColor: '#fff',
    borderRadius: 8,
    margin: 4,
  },
  summaryValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  summaryLabel: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
  dataRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 10,
    backgroundColor: '#fff',
    borderRadius: 6,
    marginBottom: 6,
  },
  dataTime: {
    fontSize: 12,
    color: '#666',
    flex: 1,
  },
  dataMetrics: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    flex: 2,
  },
  metricBadge: {
    fontSize: 11,
    color: '#333',
    backgroundColor: '#e8e8e8',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 10,
    marginRight: 4,
    marginBottom: 2,
  },
  moreDataHint: {
    fontSize: 12,
    color: '#999',
    textAlign: 'center',
    marginTop: 8,
    fontStyle: 'italic',
  },
  dataSectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  subSectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginTop: 12,
    marginBottom: 8,
    color: '#333',
  },
  emptyDataContainer: {
    alignItems: 'center',
    padding: 30,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
  },
  emptyDataText: {
    fontSize: 16,
    color: '#666',
    fontWeight: '500',
  },
  emptyDataHint: {
    fontSize: 12,
    color: '#999',
    marginTop: 8,
    textAlign: 'center',
  },
  emptyDataBox: {
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
  },
  sleepSection: {
    marginTop: 12,
  },
  sleepCard: {
    backgroundColor: '#f0f4ff',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  sleepHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sleepTime: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  sleepScore: {
    fontSize: 14,
    fontWeight: '600',
    color: '#007AFF',
  },
  sleepStats: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  sleepStatItem: {
    width: '50%',
    padding: 6,
    alignItems: 'center',
  },
  sleepStatValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  sleepStatLabel: {
    fontSize: 11,
    color: '#666',
    marginTop: 2,
  },
  sportSection: {
    marginTop: 12,
  },
  halfHourSection: {
    marginTop: 12,
  },
});
