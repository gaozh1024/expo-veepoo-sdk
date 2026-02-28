import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  Button,
  FlatList,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { VeepooDevice, TestState } from '@gaozh1024/expo-veepoo-sdk';
import { TestButtonGroup } from '../src/components/TestButtonGroup';
import { TestResultBox, TestResultItem } from '../src/components/TestResultBox';
import { EmptyDataBox } from '../src/components/EmptyDataBox';
import { DataSummaryGrid, DataSummaryItem } from '../src/components/DataSummary';
import { SleepCard } from '../src/components/SleepCard';
import { useDeviceState, useTestState, useDataState, useVeepooSDK } from '../src/hooks';
import type { SavedDevice, TestType } from '../src/types';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../src/theme';

export default function HomeScreen() {
  const [status, setStatus] = useState('准备就绪');

  const device = useDeviceState();
  const test = useTestState();
  const data = useDataState();

  const {
    startScan,
    stopScan,
    connectDevice,
    connectSavedDevice,
    disconnect,
    fetchSleepData,
    fetchSportData,
    fetchHistoryData,
    startTest,
    stopTest,
  } = useVeepooSDK({ device, test, data, setStatus });

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
          disabled={device.connectedDeviceId !== null}
        />
      </View>
    ),
    [device.connectedDeviceId, connectDevice]
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
            disabled={device.connectedDeviceId !== null}
          />
          <Button
            title="删除"
            onPress={() => device.removeSavedDevice(item.id)}
            color="#FF3B30"
          />
        </View>
      </View>
    ),
    [device.connectedDeviceId, connectSavedDevice, device]
  );

  const testTypes: TestType[] = ['heartRate', 'bloodPressure', 'bloodOxygen', 'temperature', 'stress', 'bloodGlucose'];

  const testTitles: Record<TestType, string> = {
    heartRate: '心率测试',
    bloodPressure: '血压测试',
    bloodOxygen: '血氧测试',
    temperature: '体温测试',
    stress: '压力测试',
    bloodGlucose: '血糖测试',
  };

  const formatTestState = (state: TestState | undefined): string => {
    switch (state) {
      case 'idle':
        return '空闲 (idle)';
      case 'start':
        return '开始 (start)';
      case 'testing':
        return '测试中 (testing)';
      case 'over':
        return '完成 (over)';
      case 'notWear':
        return '未佩戴 (notWear)';
      case 'deviceBusy':
        return '设备忙 (deviceBusy)';
      case 'error':
        return '错误 (error)';
      default:
        return state ?? '未知';
    }
  };

  const renderTestResult = (testType: TestType) => {
     switch (testType) {
       case 'heartRate':
         return test.heartRateResult ? (
           <TestResultBox>
             <TestResultItem label="状态" value={formatTestState(test.heartRateResult.state)} />
             {test.heartRateResult.value != null ? (
               <TestResultItem label="心率" value={String(test.heartRateResult.value)} unit="bpm" />
             ) : null}
             {test.heartRateResult.progress !== undefined ? (
               <TestResultItem label="进度" value={String(test.heartRateResult.progress)} />
             ) : null}
           </TestResultBox>
         ) : null;
       case 'bloodPressure':
         return test.bloodPressureResult ? (
           <TestResultBox>
             <TestResultItem label="状态" value={formatTestState(test.bloodPressureResult.state)} />
             {test.bloodPressureResult.progress !== undefined ? (
               <TestResultItem label="进度" value={String(test.bloodPressureResult.progress)} />
             ) : null}
             {test.bloodPressureResult.systolic != null ? (
               <TestResultItem label="收缩压" value={String(test.bloodPressureResult.systolic)} unit="mmHg" />
             ) : null}
             {test.bloodPressureResult.diastolic != null ? (
               <TestResultItem label="舒张压" value={String(test.bloodPressureResult.diastolic)} unit="mmHg" />
             ) : null}
             {test.bloodPressureResult.pulse != null ? (
               <TestResultItem label="脉搏" value={String(test.bloodPressureResult.pulse)} unit="bpm" />
             ) : null}
           </TestResultBox>
         ) : null;
       case 'bloodOxygen':
         return test.bloodOxygenResult ? (
           <TestResultBox>
             <TestResultItem label="状态" value={formatTestState(test.bloodOxygenResult.state)} />
             {test.bloodOxygenResult.value != null ? (
               <TestResultItem label="血氧" value={String(test.bloodOxygenResult.value)} unit="%" />
             ) : null}
           </TestResultBox>
         ) : null;
       case 'temperature':
         return test.temperatureResult ? (
           <TestResultBox>
             <TestResultItem label="状态" value={formatTestState(test.temperatureResult.state)} />
             {test.temperatureResult.value != null ? (
               <TestResultItem label="体温" value={String(test.temperatureResult.value.toFixed(1))} unit="℃" />
             ) : null}
           </TestResultBox>
         ) : null;
      case 'stress':
        return test.stressData ? (
          <TestResultBox>
            <TestResultItem label="压力值" value={String(test.stressData.stress)} />
          </TestResultBox>
        ) : null;
      case 'bloodGlucose':
        return test.bloodGlucoseResult ? (
          <TestResultBox>
            <TestResultItem label="状态" value={formatTestState(test.bloodGlucoseResult.state)} />
            {test.bloodGlucoseResult.glucose != null ? (
              <TestResultItem label="血糖值" value={String(test.bloodGlucoseResult.glucose)} unit="mmol/L" />
            ) : null}
            {test.bloodGlucoseResult.progress !== undefined ? (
              <TestResultItem label="进度" value={String(test.bloodGlucoseResult.progress)} />
            ) : null}
          </TestResultBox>
        ) : null;
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        <Text style={styles.title}>Veepoo SDK 测试</Text>
        <Text style={styles.status}>状态: {status}</Text>

        {(data.isLoadingData || (!!device.connectedDeviceId && device.isDeviceReady && data.loadDataProgress < 100)) ? (
          <View style={styles.loadingDataContainer}>
            <ActivityIndicator size="large" color="#007AFF" />
            <Text style={styles.loadingDataText}>正在读取历史数据...</Text>
            <View style={styles.progressBarContainer}>
              <View style={[styles.progressBarFill, { width: `${data.loadDataProgress}%` }]} />
            </View>
            <Text style={styles.progressText}>{data.loadDataProgress}%</Text>
          </View>
        ) : null}

        {device.battery && !data.isLoadingData ? (
          <View style={styles.batteryInfo}>
            <Text>
              电量: {device.battery.percent > 0 ? device.battery.percent : device.battery.level}%
              {device.battery.isLowBattery ? ' 电量低' : ''}
            </Text>
          </View>
        ) : null}

        {!device.connectedDeviceId ? (
          <>
            <View style={styles.buttonContainer}>
              {!device.isScanning ? (
                <Button title="开始扫描" onPress={startScan} disabled={!device.isInitialized} />
              ) : (
                <Button title="停止扫描" onPress={stopScan} />
              )}
            </View>

            {device.savedDevices.length > 0 && (
              <>
                <Text style={styles.sectionTitle}>📱 历史设备 ({device.savedDevices.length})</Text>
                <FlatList
                  data={device.savedDevices}
                  keyExtractor={(item) => item.id}
                  renderItem={renderSavedDevice}
                  style={styles.deviceList}
                  scrollEnabled={false}
                />
              </>
            )}

            <Text style={styles.sectionTitle}>扫描到的设备 ({device.devices.length})</Text>
            <FlatList
              data={device.devices}
              keyExtractor={(item) => item.id}
              renderItem={renderDevice}
              style={styles.deviceList}
              scrollEnabled={false}
            />
          </>
        ) : (
          <>
            <View style={styles.connectedInfo}>
              <Text style={styles.connectedText}>已连接: {device.connectedDeviceId}</Text>
              <Button title="断开连接" onPress={disconnect} />
            </View>

            {device.isDeviceReady && (
              <View style={styles.testSection}>
                <Text style={styles.sectionTitle}>📊 数据获取</Text>

                <View style={styles.testButtonRow}>
                  <Button title="获取睡眠数据" onPress={fetchSleepData} />
                </View>

                <View style={styles.testButtonRow}>
                  <Button title="获取运动数据" onPress={fetchSportData} />
                </View>

                <View style={styles.testButtonRow}>
                  <Button
                    title={data.isLoadingData ? '获取中...' : '获取历史数据'}
                    onPress={fetchHistoryData}
                    disabled={data.isLoadingData}
                  />
                </View>
              </View>
            )}

            {device.isDeviceReady && (
              <View style={styles.testSection}>
                <Text style={styles.sectionTitle}>健康测试</Text>

                {testTypes.map((testType) => (
                  <React.Fragment key={testType}>
                    <TestButtonGroup
                      testType={testType}
                      isTesting={test.isTesting}
                      startTitle={testTitles[testType]}
                      stopTitle="停止"
                      onStart={() => startTest(testType)}
                      onStop={() => stopTest(testType)}
                    />
                    {renderTestResult(testType)}
                  </React.Fragment>
                ))}
              </View>
            )}

            {device.isDeviceReady && !test.isTesting && (
              <View style={styles.dataSection}>
                <Text style={styles.sectionTitle}>📊 数据展示</Text>

                <View style={styles.sportSection}>
                  <Text style={styles.subSectionTitle}>🏃 运动数据</Text>
                  {data.sportStepData ? (
                    <DataSummaryGrid>
                      <DataSummaryItem
                        value={(data.sportStepData.stepCount || 0).toLocaleString()}
                        label="步数"
                        icon="👟"
                        color={Colors.primary}
                      />
                      <DataSummaryItem
                        value={(data.sportStepData.distance || 0).toFixed(2)}
                        label="距离 (km)"
                        icon="📏"
                        color={Colors.success}
                      />
                      <DataSummaryItem
                        value={(data.sportStepData.calories || 0).toFixed(0)}
                        label="卡路里 (kcal)"
                        icon="🔥"
                        color={Colors.danger}
                      />
                      <DataSummaryItem
                        value={data.sportSummary.avgHeartRate || '--'}
                        label="平均心率"
                        icon="❤️"
                        color={Colors.health.heart}
                      />
                    </DataSummaryGrid>
                  ) : (
                    <EmptyDataBox
                      title="暂无运动数据"
                      hint="点击获取运动数据按钮读取设备数据"
                      icon="🏃"
                    />
                  )}
                </View>

                <View style={styles.sleepSection}>
                  <Text style={styles.subSectionTitle}>😴 睡眠数据</Text>
                  {data.sleepDataList.length > 0 ? (
                    data.sleepDataList.map((sleep, index) => (
                      <SleepCard key={index} data={sleep} />
                    ))
                  ) : (
                    <EmptyDataBox
                      title="暂无睡眠数据"
                      hint="点击获取睡眠数据按钮读取设备数据"
                      icon="😴"
                    />
                  )}
                </View>

                {data.originDataList.length > 0 && (
                  <View style={styles.halfHourSection}>
                    <Text style={styles.subSectionTitle}>📈 半小时数据 ({data.originDataList.length} 条)</Text>
                    <FlatList
                      data={data.originDataList.slice(-10).reverse()}
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
                    {data.originDataList.length > 10 && (
                      <Text style={styles.moreDataHint}>仅显示最近 10 条数据</Text>
                    )}
                  </View>
                )}

                {data.sleepDataList.length === 0 && !data.sportStepData && data.originDataList.length === 0 && !data.isLoadingData && (
                  <EmptyDataBox
                    title="暂无数据"
                    hint="点击上方按钮获取对应数据"
                    icon="📊"
                  />
                )}
              </View>
            )}

            {test.isTesting && (
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
    backgroundColor: Colors.background,
  },
  scrollView: {
    flex: 1,
    padding: Spacing.lg,
  },
  title: {
    fontSize: FontSize.xxl,
    fontWeight: 'bold',
    marginBottom: Spacing.xs,
    textAlign: 'center',
    color: Colors.text.primary,
  },
  status: {
    fontSize: FontSize.md,
    color: Colors.text.secondary,
    marginBottom: Spacing.lg,
    textAlign: 'center',
  },
  batteryInfo: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing.md,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    marginBottom: Spacing.lg,
    ...Shadows.sm,
  },
  buttonContainer: {
    marginBottom: Spacing.lg,
  },
  scanButton: {
    backgroundColor: Colors.primary,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.lg,
    ...Shadows.md,
  },
  sectionTitle: {
    fontSize: FontSize.xl,
    fontWeight: '600',
    marginTop: Spacing.lg,
    marginBottom: Spacing.md,
    color: Colors.text.primary,
  },
  deviceList: {
    flexGrow: 0,
  },
  deviceItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: Spacing.md,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.sm,
    ...Shadows.sm,
  },
  deviceInfo: {
    flex: 1,
  },
  deviceName: {
    fontSize: FontSize.lg,
    fontWeight: '500',
    color: Colors.text.primary,
  },
  deviceMac: {
    fontSize: FontSize.sm,
    color: Colors.text.secondary,
    marginTop: 2,
  },
  deviceRssi: {
    fontSize: FontSize.sm,
    color: Colors.text.tertiary,
    marginTop: 2,
  },
  savedDeviceItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: Spacing.md,
    backgroundColor: Colors.card.sleep,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.sm,
    borderLeftWidth: 4,
    borderLeftColor: Colors.primary,
    ...Shadows.sm,
  },
  savedDeviceTime: {
    fontSize: FontSize.xs,
    color: Colors.text.tertiary,
    marginTop: 2,
  },
  savedDeviceButtons: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  connectedInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: Spacing.md,
    backgroundColor: Colors.successLight,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
    ...Shadows.sm,
  },
  connectedText: {
    fontSize: FontSize.md,
    fontWeight: '500',
    color: Colors.text.primary,
  },
  testSection: {
    marginTop: Spacing.lg,
    backgroundColor: Colors.surface,
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    ...Shadows.sm,
  },
  testButtonRow: {
    marginVertical: Spacing.sm,
  },
  loadingContainer: {
    alignItems: 'center',
    marginTop: Spacing.xl,
    padding: Spacing.xl,
  },
  loadingText: {
    marginTop: Spacing.md,
    fontSize: FontSize.md,
    color: Colors.text.secondary,
  },
  progressBarContainer: {
    width: '100%',
    height: 8,
    backgroundColor: Colors.divider,
    borderRadius: BorderRadius.full,
    marginTop: Spacing.md,
    overflow: 'hidden',
  },
  progressFill: {
    height: 8,
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
  },
  progressText: {
    fontSize: FontSize.sm,
    color: Colors.text.inverse,
    fontWeight: '500',
  },
  loadingDataContainer: {
    alignItems: 'center',
    padding: Spacing.xl,
    backgroundColor: Colors.card.sleep,
    borderRadius: BorderRadius.xl,
    marginBottom: Spacing.lg,
    ...Shadows.md,
  },
  loadingDataText: {
    marginTop: Spacing.md,
    fontSize: FontSize.lg,
    fontWeight: '500',
    color: Colors.primary,
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
  },
  dataSection: {
    marginTop: Spacing.lg,
    padding: Spacing.md,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    ...Shadows.sm,
  },
  sportSection: {
    marginTop: Spacing.md,
  },
  subSectionTitle: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
    color: Colors.text.primary,
  },
  sleepSection: {
    marginTop: Spacing.md,
  },
  halfHourSection: {
    marginTop: Spacing.md,
  },
  dataRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: Spacing.md,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    marginBottom: Spacing.xs,
    borderWidth: 1,
    borderColor: Colors.divider,
  },
  dataTime: {
    fontSize: FontSize.sm,
    color: Colors.text.secondary,
    flex: 1,
  },
  dataMetrics: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    flex: 2,
  },
  metricBadge: {
    fontSize: FontSize.xs,
    color: Colors.text.primary,
    backgroundColor: Colors.divider,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.full,
    marginRight: Spacing.xs,
    marginBottom: 2,
  },
  moreDataHint: {
    fontSize: FontSize.sm,
    color: Colors.text.tertiary,
    textAlign: 'center',
    marginTop: Spacing.sm,
  },
});