import React, { useState, useEffect, useCallback } from 'react';
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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
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
} from '@gaozh1024/expo-veepoo-sdk';

export default function HomeScreen() {
  const [isInitialized, setIsInitialized] = useState(false);
  const [devices, setDevices] = useState<VeepooDevice[]>([]);
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

  useEffect(() => {
    initializeSDK();
    setupEventListeners();
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
      setDevices((prev) => {
        const exists = prev.find((d) => d.id === result.device.id);
        return exists ? prev : [...prev, result.device];
      });
    });

    VeepooSDK.on('deviceConnected', (payload) => {
      setConnectedDeviceId(payload.deviceId);
      setIsScanning(false);
      setStatus('设备已连接，等待验证...');
    });

    VeepooSDK.on('deviceDisconnected', () => {
      setConnectedDeviceId(null);
      setIsDeviceReady(false);
      setBattery(null);
      setStatus('设备已断开');
    });

    VeepooSDK.on('deviceReady', (payload) => {
      setIsDeviceReady(true);
      setStatus('设备准备就绪');
      readBattery();
    });

    VeepooSDK.on('batteryData', (payload) => {
      setBattery(payload.data);
    });

    VeepooSDK.on('heartRateTestResult', (payload) => {
      setHeartRateResult(payload.result);
      setHeartRateProgress(payload.result.progress ?? 0);  // 监听进度
      if (payload.result.state === 'over') {
        setIsTesting(null);
        setHeartRateProgress(0);  // 重置进度
      }
    });

    VeepooSDK.on('bloodPressureTestResult', (payload) => {
      setBloodPressureResult(payload.result);
      if (payload.result.state === 'over') {
        setIsTesting(null);
      }
    });

    VeepooSDK.on('bloodOxygenTestResult', (payload) => {
      setBloodOxygenResult(payload.result);
      if (payload.result.state === 'over') {
        setIsTesting(null);
      }
    });

    VeepooSDK.on('temperatureTestResult', (payload) => {
      setTemperatureResult(payload.result);
      if (payload.result.state === 'over') {
        setIsTesting(null);
      }
    });

    VeepooSDK.on('stressData', (payload) => {
      setStressData(payload.data);
      setIsTesting(null);
    });

    VeepooSDK.on('bloodGlucoseData', (payload) => {
      setBloodGlucoseData(payload.data);
      setIsTesting(null);
    });

    VeepooSDK.on('error', (error: VeepooError) => {
      setIsTesting(null);
      Alert.alert('错误', error.message);
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
      await VeepooSDK.startScan({ timeout: 10000 });
    } catch (error) {
      setStatus(`扫描失败: ${error}`);
      setIsScanning(false);
    }
  };

  const stopScan = async () => {
    await VeepooSDK.stopScan();
    setIsScanning(false);
    setStatus('扫描已停止');
  };

  const connectDevice = async (device: VeepooDevice) => {
    try {
      setStatus(`正在连接 ${device.name}...`);
      await VeepooSDK.connect(device.id, { password: '0000' });
    } catch (error) {
      setStatus(`连接失败: ${error}`);
    }
  };

  const disconnect = async () => {
    if (connectedDeviceId) {
      await VeepooSDK.disconnect(connectedDeviceId);
    }
  };

  const readBattery = async () => {
    try {
      const batteryInfo = await VeepooSDK.readBattery();
      setBattery(batteryInfo);
    } catch (error) {
      console.error('读取电量失败:', error);
    }
  };

  const [heartRateProgress, setHeartRateProgress] = useState<number>(0);

  const startTest = async (testType: string) => {
    if (!isDeviceReady) {
      Alert.alert('提示', '设备未准备就绪');
      return;
    }

    setIsTesting(testType);

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
  };

  const stopTest = async (testType: string) => {
    setIsTesting(null);

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

  const renderTestResult = (label: string, value: string | null, unit: string = '') => {
    if (!value) return null;
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

        {battery && (
          <View style={styles.batteryInfo}>
            <Text>
              电量: {battery.level}%{battery.isLowBattery ? ' 电量低' : ''}
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
    alignItems: 'center',
    marginBottom: 8,
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
});
