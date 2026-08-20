# @gaozh1024/expo-smart-wearable-link

[![npm version](https://badge.fury.io/js/@gaozh1024%2Fexpo-smart-wearable-link.svg)](https://badge.fury.io/js/@gaozh1024%2Fexpo-smart-wearable-link)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey.svg)](https://github.com/gaozh1024/expo-smart-wearable-link)

Expo 模块，用于智能穿戴设备的蓝牙连接、数据读取和健康测试。

当前最新版本：`1.2.7`

- 使用文档：当前 `README.md`
- 升级说明：[1.2.7.md](docs/release-notes/1.2.7.md)
- 历史版本：[docs/README.md](docs/README.md)

这个包的原则是：

- Android 和 iOS 原生层尽量贴近各自 SDK 文档
- 对 App 暴露时，统一在 TypeScript 层做返回值归一化
- App 侧通过 `SmartWearableLinkSDK` 使用时，拿到的是统一后的返回结构

## 平台要求

| 平台 | 最低版本 | Expo Go 支持 | 备注 |
| --- | --- | --- | --- |
| iOS | 15.1+ | 不支持 | 需要开发构建，Simulator 可编译但不支持真实蓝牙能力 |
| Android | 6.0+ (API 23+) | 不支持 | 需要开发构建 |

## 安装

```bash
npm install @gaozh1024/expo-smart-wearable-link
```

或

```bash
yarn add @gaozh1024/expo-smart-wearable-link
```

## Expo 配置

### iOS

在 `app.json` 或 `app.config.js` 中添加插件配置：

```json
{
  "expo": {
    "plugins": [
      [
        "@gaozh1024/expo-smart-wearable-link",
        {
          "bluetoothAlwaysPermission": "需要蓝牙权限来连接设备",
          "bluetoothPeripheralPermission": "需要蓝牙权限来扫描设备"
        }
      ]
    ]
  }
}
```

然后重新预构建：

```bash
npx expo prebuild --clean
cd ios && pod install && cd ..
npx expo run:ios
```

iOS 说明：

- 真机支持完整蓝牙能力
- Simulator 现在支持编译和启动开发构建
- 但由于上游厂商二进制仅提供 device slice，Simulator 下走的是框架内置 stub/no-op 路径，不能用于真实蓝牙联调
- `1.2.1` 修复了 iOS 设备构建下 `FRAMEWORK_SEARCH_PATHS` 对 `$(inherited)` 的错误引用问题
- `1.2.2` 修复了 iOS 真机构建下动态 frameworks 未自动 embed 导致的启动崩溃问题
- `1.2.3` 修复了 iOS embed 脚本在部分构建环境下 `FRAMEWORKS_FOLDER_PATH` 未定义导致的构建失败

### Android

Android 权限会自动注入。首次接入后也需要重新构建：

```bash
npx expo prebuild --clean
npx expo run:android
```

## 快速开始

```ts
import SmartWearableLinkSDK from '@gaozh1024/expo-smart-wearable-link';

await SmartWearableLinkSDK.init();

const enabled = await SmartWearableLinkSDK.checkBluetoothStatus();
if (!enabled) {
  throw new Error('Bluetooth is disabled');
}

const permission = await SmartWearableLinkSDK.requestPermissions();
if (!permission.granted) {
  throw new Error(`Permission denied: ${permission.status}`);
}

SmartWearableLinkSDK.on('deviceFound', ({ device }) => {
  console.log('deviceFound', device.id, device.name, device.rssi);
});

await SmartWearableLinkSDK.startScan({ timeout: 10000 });
```

连接设备：

```ts
await SmartWearableLinkSDK.connect(deviceId, {
  password: '0000',
  is24Hour: true,
});

SmartWearableLinkSDK.on('deviceConnected', ({ deviceId }) => {
  console.log('deviceConnected', deviceId);
});

SmartWearableLinkSDK.on('deviceReady', ({ deviceId }) => {
  console.log('deviceReady', deviceId);
});
```

读取数据：

```ts
const battery = await SmartWearableLinkSDK.readBattery();
const version = await SmartWearableLinkSDK.readDeviceVersion();
const sleepList = await SmartWearableLinkSDK.readSleepData();
const sport = await SmartWearableLinkSDK.readSportStepData();

console.log(battery.chargeState, battery.level);
console.log(version.deviceNumber, version.hardwareVersion);
console.log(sleepList);
console.log(sport.stepCount, sport.distance);
```

## 统一返回说明

App 侧请使用：

```ts
import SmartWearableLinkSDK from '@gaozh1024/expo-smart-wearable-link';
```

不要直接依赖 `NativeSmartWearableLinkSDK`。`SmartWearableLinkSDK` 会在 TS 层统一这些返回：

- `requestPermissions`
- `verifyPassword`
- `readBattery`
- `readDeviceFunctions`
- `readSocialMsgData`
- `readDeviceVersion`
- `readSleepData`
- `readSportStepData`
- `readOriginData`
- `readDaySummaryData`
- `readAutoMeasureSetting`
- `modifyAutoMeasureSetting`

也会统一这些事件 payload：

- `bluetoothStateChanged`
- `readOriginProgress`
- `deviceFunction`
- `deviceVersion`
- `passwordData`
- `socialMsgData`
- `originFiveMinuteData`
- `originHalfHourData`
- `sleepData`
- `sportStepData`
- `heartRateTestResult`
- `bloodPressureTestResult`
- `bloodOxygenTestResult`
- `temperatureTestResult`
- `stressData`
- `bloodGlucoseData`
- `batteryData`

其中 `readOriginProgress` 当前统一语义为：

- `progress` 返回 `0-100` 的整数百分比
- 小数部分直接截断，不做四舍五入
- 只有数值变化时才会继续派发事件
- 完成时固定返回 `100`

## 日志

框架内置了一层轻量日志，默认关闭。开启后会把关键链路输出为统一结构，适合排查扫描、连接、读数据和测试流程问题。

```ts
import SmartWearableLinkSDK, { type LogEntry } from '@gaozh1024/expo-smart-wearable-link';

SmartWearableLinkSDK
  .setLogEnabled(true)
  .setLogger((entry: LogEntry) => {
    console.log('[smart-wearable-link-log]', entry.level, entry.scope, entry.action, entry);
  });
```

可用方法：

- `setLogEnabled(enabled: boolean): SmartWearableLinkSDK`
- `isLogEnabled(): boolean`
- `setLogger(logger: ((entry: LogEntry) => void) | null): SmartWearableLinkSDK`

日志字段：

- `timestamp`
- `level`
- `scope`
- `action`
- `platform`
- `message`
- `deviceId`
- `data`
- `error`

## 蓝牙与连接监听

系统蓝牙状态：

```ts
SmartWearableLinkSDK.on('bluetoothStateChanged', (payload) => {
  console.log(payload.state, payload.authorization);
});
```

设备断开与连接状态变化：

```ts
SmartWearableLinkSDK.on('deviceDisconnected', ({ deviceId }) => {
  console.log('deviceDisconnected', deviceId);
});

SmartWearableLinkSDK.on('connectionStatusChanged', ({ deviceId, status }) => {
  console.log('connectionStatusChanged', deviceId, status);
});

SmartWearableLinkSDK.on('deviceConnectStatus', ({ deviceId, status, code }) => {
  console.log('deviceConnectStatus', deviceId, status, code);
});
```

建议同时监听这三类事件，以覆盖设备断开和系统蓝牙关闭。

## 常用 API

### 初始化

- `init(): Promise<void>`
- `isSDKInitialized(): boolean`
- `checkBluetoothStatus(): Promise<boolean>`
- `requestPermissions(): Promise<PermissionsResult>`
- `setLogEnabled(enabled: boolean): SmartWearableLinkSDK`
- `isLogEnabled(): boolean`
- `setLogger(logger: ((entry: LogEntry) => void) | null): SmartWearableLinkSDK`

### 扫描与连接

- `startScan(options?: ScanOptions): Promise<void>`
- `stopScan(): Promise<void>`
- `connect(deviceId: string, options?: ConnectOptions): Promise<void>`
- `disconnect(deviceId?: string): Promise<void>`
- `getConnectionStatus(deviceId?: string): Promise<ConnectionStatus>`
- `getConnectedDeviceId(): string | null`
- `isScanningActive(): boolean`

### 设备信息

- `verifyPassword(password?: string, is24Hour?: boolean): Promise<PasswordData>`
- `readBattery(): Promise<BatteryInfo>`
- `readDeviceFunctions(): Promise<DeviceFunctions>`
- `readSocialMsgData(): Promise<SocialMsgData>`
- `readDeviceVersion(): Promise<DeviceVersion>`
- `syncPersonalInfo(info: PersonalInfo): Promise<boolean>`
- `setLanguage(language: Language): Promise<boolean>`

### 数据读取

- `startReadOriginData(): Promise<void>`
- `readDeviceAllData(): Promise<boolean>`
- `readSleepData(date?: string): Promise<SleepData[]>`
- `readSportStepData(date?: string): Promise<SportStepData>`
- `readOriginData(dayOffset?: number): Promise<OriginData[]>`
- `readDaySummaryData(dayOffset?: number): Promise<DaySummaryData>`
- `readAutoMeasureSetting(): Promise<AutoMeasureSetting[]>`
- `modifyAutoMeasureSetting(setting: Partial<AutoMeasureSetting>): Promise<AutoMeasureSetting[]>`

历史数据进度事件示例：

```ts
SmartWearableLinkSDK.on('readOriginProgress', ({ progress }) => {
  console.log(progress.progress); // 0..100，整数
});
```

### 健康测试

- `startHeartRateTest(): Promise<void>`
- `stopHeartRateTest(): Promise<void>`
- `startBloodPressureTest(): Promise<void>`
- `stopBloodPressureTest(): Promise<void>`
- `startBloodOxygenTest(): Promise<void>`
- `stopBloodOxygenTest(): Promise<void>`
- `startTemperatureTest(): Promise<void>`
- `stopTemperatureTest(): Promise<void>`
- `startStressTest(): Promise<void>`
- `stopStressTest(): Promise<void>`
- `startBloodGlucoseTest(): Promise<void>`
- `stopBloodGlucoseTest(): Promise<void>`

## 事件列表

- `deviceFound`
- `deviceConnected`
- `deviceDisconnected`
- `deviceConnectStatus`
- `connectionStatusChanged`
- `deviceReady`
- `bluetoothStateChanged`
- `deviceFunction`
- `deviceVersion`
- `passwordData`
- `socialMsgData`
- `batteryData`
- `readOriginProgress`
- `readOriginComplete`
- `originFiveMinuteData`
- `originHalfHourData`
- `sleepData`
- `sportStepData`
- `heartRateTestResult`
- `bloodPressureTestResult`
- `bloodOxygenTestResult`
- `temperatureTestResult`
- `stressData`
- `bloodGlucoseData`
- `error`

## 使用建议

- 所有调用都从 `await SmartWearableLinkSDK.init()` 开始
- 在连接前先检查蓝牙和权限
- 连接相关请同时监听 `deviceDisconnected`、`connectionStatusChanged`、`bluetoothStateChanged`
- 如果业务依赖统一返回，只通过 `SmartWearableLinkSDK` 调用，不直接使用 native module
- iOS 端包含原生 frameworks，不能在 Expo Go 中运行

## 本地开发

```bash
npm run typecheck
npm test -- --runInBand
npm run build
```

## 发布前检查

建议发布前执行：

```bash
npm run typecheck
npm test -- --runInBand
npm run build
npm pack --dry-run
```

如果要正式发布：

```bash
npm publish
```

## 参考文档

Vendor SDK 文档保存在仓库内：

- `docs/SmartWearableLinkSDK Android Api.md`
- `docs/SmartWearableLinkSDK iOS Api.md`

## 许可证

MIT
