# @gaozh1024/expo-veepoo-sdk

Expo 模块，用于 Veepoo 设备蓝牙连接和数据交互。封装了 Veepoo 原生 SDK，提供统一的 TypeScript API。

## 特性

- 完整的蓝牙 LE 功能支持
- 跨平台支持（iOS 和 Android）
- TypeScript 类型完整
- 事件驱动架构
- 健康数据读取（心率、血压、血氧、体温、压力、血糖等）

## 安装

```bash
npm install @gaozh1024/expo-veepoo-sdk
# 或
yarn add @gaozh1024/expo-veepoo-sdk
```

## 平台要求

| 平台 | 最低版本 | 备注 |
|------|----------|------|
| iOS | 13.4+ | 需要开发构建，不支持 Expo Go |
| Android | 6.0+ (API 23+) | 支持 Expo Go |

## 配置

### iOS

在 `app.json` 或 `app.config.js` 中添加蓝牙权限：

```json
{
  "expo": {
    "plugins": [
      [
        "@gaozh1024/expo-veepoo-sdk",
        {
          "bluetoothAlwaysPermission": "需要蓝牙权限来连接设备",
          "bluetoothPeripheralPermission": "需要蓝牙权限来扫描设备"
        }
      ]
    ]
  }
}
```

然后运行：
```bash
npx expo prebuild --clean
```

### Android

权限已自动配置，无需额外操作。

## 快速开始

```typescript
import VeepooSDK from '@gaozh1024/expo-veepoo-sdk';

// 初始化 SDK
await VeepooSDK.init();

// 检查蓝牙状态
const isEnabled = await VeepooSDK.checkBluetoothStatus();
if (!isEnabled) {
  console.log('请开启蓝牙');
  return;
}

// 请求权限
const hasPermission = await VeepooSDK.requestPermissions();

// 监听设备发现事件
VeepooSDK.on('deviceFound', (result) => {
  console.log('发现设备:', result.device);
});

// 开始扫描
await VeepooSDK.startScan({ timeout: 10000 });

// 连接设备
await VeepooSDK.connect(deviceId, { password: '0000' });

// 监听连接状态
VeepooSDK.on('deviceConnected', (payload) => {
  console.log('设备已连接:', payload.deviceId);
});

VeepooSDK.on('deviceReady', (payload) => {
  console.log('设备准备就绪:', payload.deviceId);
});
```

## API 文档

### 方法

#### 初始化与状态

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `init()` | - | `Promise<void>` | 初始化 SDK |
| `checkBluetoothStatus()` | - | `Promise<boolean>` | 检查蓝牙是否开启 |
| `requestPermissions()` | - | `Promise<boolean>` | 请求蓝牙权限 |
| `isSDKInitialized()` | - | `boolean` | SDK 是否已初始化 |
| `isScanningActive()` | - | `boolean` | 是否正在扫描 |
| `getConnectedDeviceId()` | - | `string \| null` | 获取已连接设备 ID |

#### 扫描与连接

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `startScan(options?)` | `ScanOptions` | `Promise<void>` | 开始扫描设备 |
| `stopScan()` | - | `Promise<void>` | 停止扫描 |
| `connect(deviceId, options?)` | `string, ConnectOptions` | `Promise<void>` | 连接设备 |
| `disconnect(deviceId?)` | `string?` | `Promise<void>` | 断开连接 |
| `getConnectionStatus(deviceId?)` | `string?` | `Promise<ConnectionStatus>` | 获取连接状态 |

#### 设备信息

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `verifyPassword(password?, is24Hour?)` | `string, boolean` | `Promise<PasswordData>` | 验证密码 |
| `readBattery()` | - | `Promise<BatteryInfo>` | 读取电量 |
| `readDeviceFunctions()` | - | `Promise<DeviceFunctions>` | 读取设备功能 |
| `readSocialMsgData()` | - | `Promise<SocialMsgData>` | 读取社交消息功能 |
| `syncPersonalInfo(info)` | `PersonalInfo` | `Promise<boolean>` | 同步个人信息 |
| `setLanguage(language)` | `Language` | `Promise<boolean>` | 设置语言 |

#### 数据同步

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `startReadOriginData()` | - | `Promise<void>` | 开始读取原始数据 |
| `readAutoMeasureSetting()` | - | `Promise<AutoMeasureSetting[]>` | 读取自动测量设置 |
| `modifyAutoMeasureSetting(setting)` | `AutoMeasureSetting` | `Promise<void>` | 修改自动测量设置 |

#### 健康测试

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `startHeartRateTest()` | `Promise<void>` | 开始心率测试 |
| `stopHeartRateTest()` | `Promise<void>` | 停止心率测试 |
| `startBloodPressureTest()` | `Promise<void>` | 开始血压测试 |
| `stopBloodPressureTest()` | `Promise<void>` | 停止血压测试 |
| `startBloodOxygenTest()` | `Promise<void>` | 开始血氧测试 |
| `stopBloodOxygenTest()` | `Promise<void>` | 停止血氧测试 |
| `startTemperatureTest()` | `Promise<void>` | 开始体温测试 |
| `stopTemperatureTest()` | `Promise<void>` | 停止体温测试 |
| `startStressTest()` | `Promise<void>` | 开始压力测试 |
| `stopStressTest()` | `Promise<void>` | 停止压力测试 |
| `startBloodGlucoseTest()` | `Promise<void>` | 开始血糖测试 |
| `stopBloodGlucoseTest()` | `Promise<void>` | 停止血糖测试 |

#### 事件监听

| 方法 | 说明 |
|------|------|
| `on(event, listener)` | 注册事件监听器 |
| `off(event, listener)` | 移除事件监听器 |
| `once(event, listener)` | 注册一次性监听器 |
| `removeAllListeners(event?)` | 移除所有监听器 |

### 事件

| 事件名 | Payload | 说明 |
|--------|---------|------|
| `deviceFound` | `{ device: VeepooDevice; timestamp: number }` | 发现设备 |
| `deviceConnected` | `{ deviceId: string }` | 设备已连接 |
| `deviceDisconnected` | `{ deviceId: string }` | 设备已断开 |
| `deviceConnectStatus` | `{ deviceId: string; status: ConnectionStatus; code?: number }` | 连接状态变化 |
| `deviceReady` | `{ deviceId: string; isOadModel?: boolean }` | 设备准备就绪 |
| `bluetoothStateChanged` | `BluetoothStatus` | 蓝牙状态变化 |
| `deviceFunction` | `{ deviceId: string; functions: DeviceFunctions }` | 设备功能信息 |
| `deviceVersion` | `{ deviceId: string; version: string }` | 设备版本信息 |
| `passwordData` | `{ deviceId: string; data: PasswordData }` | 密码验证结果 |
| `readOriginProgress` | `{ deviceId: string; progress: ReadOriginProgress }` | 数据读取进度 |
| `readOriginComplete` | `{ deviceId: string; success: boolean }` | 数据读取完成 |
| `heartRateTestResult` | `{ deviceId: string; result: HeartRateTestResult }` | 心率测试结果 |
| `bloodPressureTestResult` | `{ deviceId: string; result: BloodPressureTestResult }` | 血压测试结果 |
| `bloodOxygenTestResult` | `{ deviceId: string; result: BloodOxygenTestResult }` | 血氧测试结果 |
| `temperatureTestResult` | `{ deviceId: string; result: TemperatureTestResult }` | 体温测试结果 |
| `stressData` | `{ deviceId: string; data: StressData }` | 压力数据 |
| `bloodGlucoseData` | `{ deviceId: string; data: BloodGlucoseData }` | 血糖数据 |
| `batteryData` | `{ deviceId: string; data: BatteryInfo }` | 电量数据 |
| `error` | `VeepooError` | 错误事件 |

## 类型定义

### 核心类型

```typescript
// 设备信息
interface VeepooDevice {
  id: string;        // 设备 ID
  name: string;      // 设备名称
  rssi: number;      // 信号强度
  mac?: string;      // MAC 地址
  uuid?: string;     // UUID (iOS)
}

// 连接状态
type ConnectionStatus = 
  | 'disconnected'   // 未连接
  | 'connecting'     // 连接中
  | 'connected'      // 已连接
  | 'disconnecting'  // 断开中
  | 'ready'          // 准备就绪
  | 'error';         // 错误

// 扫描选项
interface ScanOptions {
  timeout?: number;         // 超时时间（毫秒）
  allowDuplicates?: boolean; // 允许重复设备
}

// 连接选项
interface ConnectOptions {
  password?: string;   // 连接密码，默认 '0000'
  is24Hour?: boolean;  // 是否24小时制
}
```

### 健康数据类型

```typescript
// 心率数据
interface HeartRateData {
  value: number;      // 心率值（bpm）
  timestamp: number;  // 时间戳
}

// 血压数据
interface BloodPressureData {
  systolic: number;   // 收缩压（mmHg）
  diastolic: number;  // 舒张压（mmHg）
  pulse: number;      // 脉搏（bpm）
  timestamp: number;
}

// 血氧数据
interface BloodOxygenData {
  spo2: number;       // 血氧值（%）
  timestamp: number;
}

// 体温数据
interface TemperatureData {
  temperature: number;   // 体温值（℃）
  timestamp: number;
  isSurface?: boolean;   // 是否体表温度
  originalTemp?: number; // 原始温度
}

// 压力数据
interface StressData {
  stress: number;     // 压力值（0-100）
  timestamp: number;
}

// 血糖数据
interface BloodGlucoseData {
  glucose: number;    // 血糖值（mmol/L）
  timestamp: number;
}

// 电量信息
interface BatteryInfo {
  level: number;      // 电量级别
  percent: boolean;   // 是否百分比
  isLowBattery: boolean; // 是否低电量
}
```

### 测试结果类型

```typescript
// 测试状态
type TestState = 
  | 'idle'        // 空闲
  | 'start'       // 开始
  | 'testing'     // 测试中
  | 'notWear'     // 未佩戴
  | 'deviceBusy'  // 设备忙
  | 'over'        // 完成
  | 'error';      // 错误

// 心率测试结果
interface HeartRateTestResult {
  state: TestState;
  value?: number;
}

// 血压测试结果
interface BloodPressureTestResult {
  state: TestState;
  systolic?: number;
  diastolic?: number;
  pulse?: number;
}

// 血氧测试结果
interface BloodOxygenTestResult {
  state: TestState;
  value?: number;
}

// 体温测试结果
interface TemperatureTestResult {
  state: TestState;
  value?: number;
  originalValue?: number;
  progress?: number;
}
```

### 错误类型

```typescript
type VeepooErrorCode =
  | 'UNKNOWN'
  | 'PERMISSION_DENIED'
  | 'CONNECTION_FAILED'
  | 'DISCONNECTION_FAILED'
  | 'BLUETOOTH_NOT_ENABLED'
  | 'DEVICE_NOT_FOUND'
  | 'OPERATION_FAILED'
  | 'SDK_NOT_INITIALIZED'
  | 'DEVICE_NOT_CONNECTED'
  | 'DEVICE_BUSY'
  | 'PASSWORD_REQUIRED'
  | 'TIMEOUT'
  | 'NOT_WEARING';

interface VeepooError {
  code: VeepooErrorCode;
  message: string;
  deviceId?: string;
}
```

## 本地开发

```bash
# 克隆仓库
git clone https://github.com/gaozh1024/expo-veepoo-sdk.git
cd expo-veepoo-sdk

# 安装依赖
npm install

# 构建
npm run build

# 类型检查
npm run typecheck
```

### 使用 yalc 本地测试

```bash
# 在 SDK 项目中
npm run build
yalc publish

# 在测试项目中
yalc add @gaozh1024/expo-veepoo-sdk
npm install

# 测试完成后
yalc remove @gaozh1024/expo-veepoo-sdk
```

## 运行示例项目

```bash
# 进入 example 目录
cd example

# 安装依赖（使用 yalc 链接本地模块）
yalc add @gaozh1024/expo-veepoo-sdk
npm install

# iOS: 预构建并安装 pods
npx expo prebuild --clean
cd ios && pod install && cd ..

# 运行
npx expo start
# 按 'i' 运行 iOS，按 'a' 运行 Android
```

## 故障排除

### iOS

**模块未链接**
```bash
npx expo prebuild --clean
npx expo run:ios
```

**Framework 未找到**
```bash
cd ios && pod install
```

### Android

**权限被拒绝**
- 确保位置权限已授予
- Android 12+ 需要运行时请求蓝牙权限

## 许可证

MIT License

## 支持

- 提交 [Issue](https://github.com/gaozh1024/expo-veepoo-sdk/issues)
- 邮件：gaozh1024@gmail.com

# 2. 在测试项目中添加本地包
cd your-expo-project
yalc add @gaozh1024/expo-veepoo-sdk

# 3. 安装依赖
npm install
# 或
yarn install

# 4. 测试完成后移除
yalc remove @gaozh1024/expo-veepoo-sdk
npm install
```

## ⚙️ 配置

### iOS 配置

在你的 `app.json` 或 `app.config.js` 中添加蓝牙权限：

```json
{
  "expo": {
    "plugins": [
      [
        "@gaozh1024/expo-veepoo-sdk",
        {
          "bluetoothAlwaysPermission": "需要蓝牙权限来持续连接设备",
          "bluetoothPeripheralPermission": "需要蓝牙权限来扫描和连接设备"
        }
      ]
    ]
  }
}
```

或者手动在 `ios/Podfile` 中添加：

```ruby
target 'YourApp' do
  pod 'VeepooBleSDK'
end
```

**iOS 注意事项：**
- ⚠️ 本模块包含原生 frameworks，**不能在 Expo Go 中使用**
- 必须使用开发构建：`npx expo prebuild --clean`

### Android 配置

Android 端权限已自动配置，无需额外操作。

模块会自动请求以下权限：
- `BLUETOOTH` / `BLUETOOTH_ADMIN`
- `BLUETOOTH_CONNECT` / `BLUETOOTH_SCAN` (Android 12+)
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` (BLE 扫描需要)
- `POST_NOTIFICATIONS` (Android 13+)

**Android 注意事项：**
- ✅ 可以在 Expo Go 中使用
- ✅ 所有权限自动配置
- ⚠️ Android 12+ 需要在运行时请求蓝牙权限

## 🚀 快速开始

### 基础使用

```typescript
import VeepooSDK from '@gaozh1024/expo-veepoo-sdk';

export default function App() {
  const initializeSDK = async () => {
    try {
      // 1. 检查蓝牙状态
      const isEnabled = await VeepooSDK.checkBluetoothStatus();
      console.log('Bluetooth enabled:', isEnabled);

      if (!isEnabled) {
        alert('请开启蓝牙');
        return;
      }

      // 2. 请求权限
      const hasPermission = await VeepooSDK.requestPermissions();
      console.log('Has permission:', hasPermission);

      if (!hasPermission) {
        alert('请授予蓝牙权限');
        return;
      }

      // 3. 开始扫描设备
      await VeepooSDK.startScan({ timeout: 10000 });

    } catch (error) {
      console.error('SDK 初始化失败:', error);
    }
  };

  // 4. 监听设备发现
  VeepooSDK.on('deviceFound', (result) => {
    console.log('发现设备:', result.device);
    const { id, name, rssi } = result.device;
    console.log(`设备名称: ${name}, 信号强度: ${rssi}`);
  });

  // 5. 监听连接状态
  VeepooSDK.on('deviceConnected', (payload) => {
    console.log('设备已连接:', payload);
  });

  VeepooSDK.on('deviceDisconnected', (payload) => {
    console.log('设备已断开:', payload);
  });

  // 6. 监听错误
  VeepooSDK.on('error', (error) => {
    console.error('SDK 错误:', error);
  });

  return (
    <Button title="初始化 SDK" onPress={initializeSDK} />
  );
}
```

### 完整示例：连接设备

```typescript
import React, { useState } from 'react';
import { View, Text, Button, FlatList, StyleSheet } from 'react-native';
import VeepooSDK, { VeepooDevice } from '@gaozh1024/expo-veepoo-sdk';

export default function VeepooApp() {
  const [devices, setDevices] = useState<VeepooDevice[]>([]);
  const [isScanning, setIsScanning] = useState(false);
  const [connectedDevice, setConnectedDevice] = useState<VeepooDevice | null>(null);

  const startScan = async () => {
    try {
      setIsScanning(true);
      setDevices([]);

      await VeepooSDK.startScan({ timeout: 10000 });

    } catch (error) {
      console.error('扫描失败:', error);
      setIsScanning(false);
    }
  };

  const stopScan = async () => {
    try {
      await VeepooSDK.stopScan();
      setIsScanning(false);
    } catch (error) {
      console.error('停止扫描失败:', error);
    }
  };

  const connectDevice = async (deviceId: string) => {
    try {
      console.log('正在连接设备:', deviceId);
      await VeepooSDK.connect(deviceId);
    } catch (error) {
      console.error('连接失败:', error);
    }
  };

  const disconnectDevice = async () => {
    if (!connectedDevice) return;

    try {
      await VeepooSDK.disconnect(connectedDevice.id);
      setConnectedDevice(null);
    } catch (error) {
      console.error('断开连接失败:', error);
    }
  };

  // 监听设备发现
  VeepooSDK.on('deviceFound', (result) => {
    console.log('发现设备:', result.device);
    setDevices((prev) => {
      const exists = prev.find(d => d.id === result.device.id);
      if (!exists) {
        return [...prev, result.device];
      }
      return prev;
    });
  });

  // 监听连接成功
  VeepooSDK.on('deviceConnected', (payload) => {
    console.log('设备已连接');
    setIsScanning(false);
  });

  // 监听设备断开
  VeepooSDK.on('deviceDisconnected', (payload) => {
    console.log('设备已断开');
    setConnectedDevice(null);
  });

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Veepoo 设备扫描</Text>

      <View style={styles.buttonContainer}>
        {!isScanning ? (
          <Button title="开始扫描" onPress={startScan} />
        ) : (
          <Button title="停止扫描" onPress={stopScan} />
        )}
      </View>

      {connectedDevice ? (
        <View style={styles.connectedInfo}>
          <Text>已连接: {connectedDevice.name}</Text>
          <Button title="断开连接" onPress={disconnectDevice} />
        </View>
      ) : null}

      <FlatList
        data={devices}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={styles.deviceItem}>
            <Text style={styles.deviceName}>{item.name}</Text>
            <Text style={styles.deviceRssi}>信号: {item.rssi}</Text>
            <Button
              title="连接"
              onPress={() => connectDevice(item.id)}
              disabled={connectedDevice !== null}
            />
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  buttonContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 20,
  },
  connectedInfo: {
    padding: 15,
    backgroundColor: '#e0f7fa',
    borderRadius: 8,
    marginBottom: 20,
  },
  deviceItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  deviceName: {
    fontSize: 16,
    flex: 1,
  },
  deviceRssi: {
    fontSize: 14,
    color: '#666',
    marginRight: 10,
  },
});
```

## 📚 API 文档

### 方法

#### checkBluetoothStatus()

检查蓝牙是否已启用。

**返回值:** `Promise<boolean>`

**示例:**
```typescript
const isEnabled = await VeepooSDK.checkBluetoothStatus();
if (isEnabled) {
  console.log('蓝牙已启用');
}
```

---

#### requestPermissions()

请求蓝牙权限。

**返回值:** `Promise<boolean>`

**示例:**
```typescript
const hasPermission = await VeepooSDK.requestPermissions();
if (!hasPermission) {
  alert('请授予蓝牙权限');
}
```

---

#### startScan(options?)

开始扫描 BLE 设备。

**参数:**
```typescript
interface ScanOptions {
  timeout?: number;       // 扫描超时时间（毫秒），默认：10000
  allowDuplicates?: boolean; // 是否允许重复设备，默认：false
}
```

**返回值:** `Promise<void>`

**示例:**
```typescript
await VeepooSDK.startScan({
  timeout: 10000,
  allowDuplicates: false,
});
```

---

#### stopScan()

停止扫描。

**返回值:** `Promise<void>`

**示例:**
```typescript
await VeepooSDK.stopScan();
```

---

#### connect(deviceId, options?)

连接到指定设备。

**参数:**
```typescript
interface ConnectOptions {
  password?: string;  // 连接密码（可选）
  is24Hour?: boolean; // 是否使用24小时制，默认：false
}
```

**返回值:** `Promise<void>`

**示例:**
```typescript
await VeepooSDK.connect(deviceId, {
  password: '1234',
  is24Hour: true,
});
```

---

#### disconnect(deviceId)

断开与设备的连接。

**返回值:** `Promise<void>`

**示例:**
```typescript
await VeepooSDK.disconnect(deviceId);
```

---

#### getConnectionStatus(deviceId)

获取设备连接状态。

**参数:**
- `deviceId` (string) - 设备 ID

**返回值:** `Promise<ConnectionStatus>`

**可能的值:**
- `'disconnected'` - 未连接
- `'connecting'` - 连接中
- `'connected'` - 已连接
- `'disconnecting'` - 断开连接中
- `'ready'` - 准备就绪
- `'error'` - 错误

**示例:**
```typescript
const status = await VeepooSDK.getConnectionStatus(deviceId);
console.log('连接状态:', status);
```

---

#### sendData(deviceId, data)

向设备发送数据。

**参数:**
- `deviceId` (string) - 设备 ID
- `data` (number[]) - 字节数组

**返回值:** `Promise<void>`

**示例:**
```typescript
await VeepooSDK.sendData(deviceId, [0x01, 0x02, 0x03]);
```

---

#### isScanningActive()

检查是否正在扫描。

**返回值:** `boolean`

**示例:**
```typescript
if (VeepooSDK.isScanningActive()) {
  console.log('正在扫描中...');
}
```

---

#### on(event, listener)

监听事件。

**参数:**
- `event` (VeepooEvent) - 事件名称
- `listener` (function) - 事件处理函数

**返回值:** VeepooSDK 实例

**示例:**
```typescript
VeepooSDK.on('deviceFound', (payload) => {
  console.log('发现设备:', payload);
});
```

---

#### off(event, listener)

移除事件监听器。

**参数:**
- `event` (VeepooEvent) - 事件名称
- `listener` (function) - 事件处理函数

**返回值:** VeepooSDK 实例

**示例:**
```typescript
const listener = (payload) => console.log(payload);
VeepooSDK.on('deviceFound', listener);
VeepooSDK.off('deviceFound', listener);
```

---

## 🎯 事件

### deviceFound

发现设备时触发。

**Payload:**
```typescript
{
  device: VeepooDevice;
  timestamp: number;
}
```

**VeepooDevice:**
```typescript
interface VeepooDevice {
  id: string;      // 设备 ID（通常是 MAC 地址）
  name: string;    // 设备名称
  rssi: number;    // 信号强度
  mac?: string;     // MAC 地址
  uuid?: string;    // UUID（iOS）
}
```

---

### deviceConnected

成功连接到设备时触发。

**Payload:**
```typescript
{
  deviceId: string;
  deviceVersion?: string;
  deviceNumber?: string;
}
```

---

### deviceDisconnected

与设备断开连接时触发。

**Payload:**
```typescript
{
  deviceId: string;
}
```

---

### deviceConnectStatus

设备连接状态变化时触发。

**Payload:**
```typescript
{
  deviceId: string;
  status: ConnectionStatus;
  code?: number;
}
```

---

### deviceReady

设备准备就绪时触发。

**Payload:**
```typescript
{
  deviceId: string;
  isOadModel?: boolean;
}
```

---

### bluetoothStateChanged

蓝牙状态变化时触发。

**Payload:**
```typescript
{
  state: 'unknown' | 'resetting' | 'unsupported' | 'unauthorized' | 'poweredOff' | 'poweredOn';
  stateName: string;
  authorization: 'notDetermined' | 'restricted' | 'denied' | 'allowedAlways';
  authorizationName: string;
  isScanning: boolean;
  pendingScanStart: boolean;
}
```

---

### deviceFunction

设备功能信息时触发。

**Payload:**
```typescript
{
  deviceId: string;
  functions: DeviceFunctions;
}
```

---

### deviceVersion

设备版本信息时触发。

**Payload:**
```typescript
{
  deviceId: string;
  version: string;
  deviceNumber: string;
}
```

---

### readOriginProgress

读取原始数据进度时触发。

**Payload:**
```typescript
{
  deviceId: string;
  readState: 'idle' | 'start' | 'reading' | 'complete' | 'invalid';
  totalDays: number;
  currentDay: number;
  progress: number;
}
```

---

### readOriginComplete

原始数据读取完成时触发。

**Payload:**
```typescript
{
  deviceId: string;
  success: boolean;
}
```

---

### originHalfHourData

半小时间隔数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  data: any;
}
```

---

### heartRateData

心率数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  value: number;
  timestamp: number;
}
```

---

### bloodPressureData

血压数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  systolic: number;   // 收缩压
  diastolic: number;  // 舒张压
  pulse: number;      // 脉搏
  timestamp: number;
}
```

---

### bloodOxygenData

血氧数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  spo2: number;       // 血氧值
  timestamp: number;
}
```

---

### temperatureData

体温数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  temperature: number;
  timestamp: number;
  isSurface?: boolean;
}
```

---

### stressData

压力数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  stress: number;
  timestamp: number;
}
```

---

### bloodGlucoseData

血糖数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  glucose: number;
  timestamp: number;
}
```

---

### batteryData

电池数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  level: number;
  percent: boolean;
  powerModel: number;
  state: number;
  bat: number;
  isLowBattery: boolean;
}
```

---

### customSettingData

自定义设置数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  data: CustomSettingData;
}
```

---

### dataReceived

接收到原始数据时触发。

**Payload:**
```typescript
{
  deviceId: string;
  data: any;
}
```

---

### connectionStatusChanged

连接状态变化时触发。

**Payload:**
```typescript
{
  deviceId: string;
  status: ConnectionStatus;
}
```

---

### error

错误发生时触发。

**Payload:**
```typescript
{
  code: VeepooErrorCode;
  message: string;
  deviceId?: string;
}
```

**VeepooErrorCode:**
- `'UNKNOWN'` - 未知错误
- `'PERMISSION_DENIED'` - 权限被拒绝
- `'CONNECTION_FAILED'` - 连接失败
- `'DISCONNECTION_FAILED'` - 断开连接失败
- `'BLUETOOTH_NOT_ENABLED'` - 蓝牙未启用
- `'DEVICE_NOT_FOUND'` - 设备未找到
- `'OPERATION_FAILED'` - 操作失败

---

## 📝 类型定义

### VeepooDevice

```typescript
interface VeepooDevice {
  id: string;
  name: string;
  rssi: number;
  mac?: string;
  uuid?: string;
}
```

### ConnectionStatus

```typescript
type ConnectionStatus =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'disconnecting'
  | 'ready'
  | 'error';
```

### ScanOptions

```typescript
interface ScanOptions {
  timeout?: number;
  allowDuplicates?: boolean;
}
```

### ConnectOptions

```typescript
interface ConnectOptions {
  password?: string;
  is24Hour?: boolean;
}
```

### BluetoothStatus

```typescript
interface BluetoothStatus {
  state: 'unknown' | 'resetting' | 'unsupported' | 'unauthorized' | 'poweredOff' | 'poweredOn';
  stateName: string;
  authorization: 'notDetermined' | 'restricted' | 'denied' | 'allowedAlways';
  authorizationName: string;
  isScanning: boolean;
  pendingScanStart: boolean;
}
```

### BatteryInfo

```typescript
interface BatteryInfo {
  level: number;
  percent: boolean;
  powerModel: number;
  state: number;
  bat: number;
  isLowBattery: boolean;
}
```

### PersonalInfo

```typescript
interface PersonalInfo {
  sex: 0 | 1;           // 性别：0=女，1=男
  height: number;         // 身高（cm）
  weight: number;         // 体重（kg）
  age: number;           // 年龄
  stepAim: number;       // 步数目标
  sleepAim: number;      // 睡眠目标（小时）
}
```

### SleepData

```typescript
interface SleepData {
  date: string;
  deepSleepDuration: number;    // 深度睡眠时长（秒）
  lightSleepDuration: number;   // 浅度睡眠时长（秒）
  remSleepDuration: number;     // REM睡眠时长（秒）
  awakeDuration: number;        // 清醒时长（秒）
  totalSleepDuration: number;   // 总睡眠时长（秒）
  sleepEfficiency: number;     // 睡眠效率
  sleepScore?: number;         // 睡眠评分
  napDuration?: number;        // 午睡时长（秒）
}
```

### HeartRateData

```typescript
interface HeartRateData {
  value: number;         // 心率值（bpm）
  timestamp: number;     // 时间戳
}
```

### BloodPressureData

```typescript
interface BloodPressureData {
  systolic: number;      // 收缩压（mmHg）
  diastolic: number;     // 舒张压（mmHg）
  pulse: number;         // 脉搏（bpm）
  timestamp: number;     // 时间戳
}
```

### BloodOxygenData

```typescript
interface BloodOxygenData {
  spo2: number;          // 血氧值（%）
  timestamp: number;      // 时间戳
}
```

### TemperatureData

```typescript
interface TemperatureData {
  temperature: number;   // 体温值（℃）
  timestamp: number;     // 时间戳
  isSurface?: boolean;  // 是否体表温度
}
```

### StressData

```typescript
interface StressData {
  stress: number;       // 压力值（0-100）
  timestamp: number;     // 时间戳
}
```

### BloodGlucoseData

```typescript
interface BloodGlucoseData {
  glucose: number;       // 血糖值（mmol/L）
  timestamp: number;     // 时间戳
}
```

---

## 📱 平台要求

### iOS
- iOS 13.4+
- 支持 Objective-C/Swift 项目
- 需要开发构建（不支持 Expo Go）

### Android
- Android 6.0+ (API 23+)
- 支持 Kotlin/Java 项目
- 支持 Expo Go

---

## 🔧 故障排除

### iOS 问题

**问题：模块未链接**
```
The package '@gaozh1024/expo-veepoo-sdk' doesn't seem to be linked.
```

**解决方法：**
```bash
npx expo prebuild --clean
npx expo run:ios
```

---

**问题：蓝牙权限未授予**

**解决方法：**
1. 在 `app.json` 中添加权限描述（见配置部分）
2. 删除应用并重新安装
3. 运行时授予权限

---

**问题：frameworks 未找到**

**解决方法：**
```bash
cd ios
pod install
```

---

### Android 问题

**问题：权限被拒绝**

**解决方法：**
1. 检查 `android/app/src/main/AndroidManifest.xml` 中是否包含权限
2. 在运行时请求权限
3. 检查目标 SDK 版本是否正确

---

**问题：蓝牙扫描失败**

**解决方法：**
1. 确保位置权限已授予
2. 确保蓝牙已启用
3. Android 12+ 需要运行时权限请求

---

**问题：连接超时**

**解决方法：**
1. 确保设备在范围内
2. 重启蓝牙
3. 尝试重新扫描

---

### 通用问题

**问题：TypeScript 类型错误**

**解决方法：**
```bash
npm run typecheck
```

---

**问题：事件监听器不工作**

**解决方法：**
```typescript
// 确保正确添加监听器
VeepooSDK.on('deviceFound', (payload) => {
  console.log('设备:', payload.device);
});

// 不要多次添加同一个监听器
```

---

## 💻 开发

### 设置开发环境

```bash
# 克隆仓库
git clone https://github.com/gaozh1024/expo-veepoo-sdk.git
cd expo-veepoo-sdk

# 安装依赖
npm install

# 构建
npm run build
```

### 可用脚本

```bash
npm run build        # 构建模块
npm run clean        # 清理构建文件
npm run test         # 运行测试
npm run lint         # 运行 linter
npm run typecheck    # TypeScript 类型检查
```

### 本地测试

```bash
# 1. 发布到 yalc
yalc publish

# 2. 在测试项目中添加
cd your-expo-project
yalc add @gaozh1024/expo-veepoo-sdk

# 3. 测试
npm install
npx expo prebuild --clean
npx expo run:ios  # iOS 测试
npx expo run:android  # Android 测试

# 4. 测试完成后移除
yalc remove @gaozh1024/expo-veepoo-sdk
npm install
```

### 项目结构

```
expo-veepoo-sdk/
├── android/               # Android 原生代码
│   ├── build.gradle      # Gradle 配置（包含本地 .aar）
│   ├── src/main/java/   # Java 源代码
│   └── libs/           # 本地 SDK 文件（.aar, .jar）
├── ios/                 # iOS 原生代码
│   ├── VeepooSDK.podspec # CocoaPods 配置（包含本地 frameworks）
│   └── VeepooSDK/
│       ├── Frameworks/  # 本地 frameworks
│       └── *.swift     # Swift 源代码
├── src/                 # TypeScript 源代码
│   ├── index.ts        # 主入口
│   ├── VeepooSDK.ts   # SDK 封装
│   ├── NativeVeepooSDK.ts  # 原生模块接口
│   └── types.ts       # 类型定义
├── package.json
├── module.json
└── README.md
```

---

## 🤝 贡献

欢迎贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

## 📞 支持

如有问题或建议，请：
- 提交 [Issue](https://github.com/gaozh1024/expo-veepoo-sdk/issues)
- 发送邮件至：gaozh1024@gmail.com

---

## 🙏 致谢

- [Veepoo SDK](https://www.veepoo.com/) - 原生 SDK
- [Expo](https://expo.dev/) - React Native 开发框架
- [React Native](https://reactnative.dev/) - 跨平台框架
