# API 文档

## 目录

- [睡眠数据](#睡眠数据)
  - [readSleepData](#readSleepData)

---

## 睡眠数据

### readSleepData

读取指定日期的睡眠数据。

#### 方法签名

```typescript
readSleepData(date?: string): Promise<SleepData>
```

#### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| date | string | 否 | 查询日期，格式为 `yyyy-MM-dd`。默认为今天 |

#### 返回值

返回 `Promise<SleepData>`，结构如下：

```typescript
interface SleepDataItem {
  // 日期 (yyyy-MM-dd)
  date: string;
  
  // 入睡时间 (yyyy-MM-dd HH:mm:ss 或 HH:mm:ss)
  sleepTime: string;
  
  // 醒来时间 (yyyy-MM-dd HH:mm:ss 或 HH:mm:ss)
  wakeTime: string;
  
  // 深睡时长 (分钟)
  deepSleepMinutes: number;
  
  // 浅睡时长 (分钟)
  lightSleepMinutes: number;
  
  // 总睡眠时长 (分钟)
  totalSleepMinutes: number;
  
  // 睡眠质量评分 (0-100)
  sleepQuality: number;
  
  // 睡眠曲线原始数据
  sleepLine: string;
  
  // 清醒次数
  wakeUpCount: number;
}

interface SleepData {
  // 查询日期 (yyyy-MM-dd)
  date: string;
  
  // 睡眠记录列表 (一天可能有多段睡眠)
  items: SleepDataItem[];
  
  // 汇总数据
  summary: {
    // 总深睡时长 (分钟)
    totalDeepSleepMinutes: number;
    
    // 总浅睡时长 (分钟)
    totalLightSleepMinutes: number;
    
    // 总睡眠时长 (分钟)
    totalSleepMinutes: number;
    
    // 平均睡眠质量 (0-100)
    averageSleepQuality: number;
    
    // 总清醒次数
    totalWakeUpCount: number;
  };
}
```

#### 使用示例

```typescript
import VeepooSDK from '@gaozh1024/expo-veepoo-sdk';

// 读取今天的睡眠数据
const todaySleep = await VeepooSDK.readSleepData();

// 读取指定日期的睡眠数据
const sleepData = await VeepooSDK.readSleepData('2024-02-27');

// 访问汇总数据
console.log('查询日期:', sleepData.date);
console.log('总睡眠时长:', sleepData.summary.totalSleepMinutes, '分钟');
console.log('深睡时长:', sleepData.summary.totalDeepSleepMinutes, '分钟');
console.log('浅睡时长:', sleepData.summary.totalLightSleepMinutes, '分钟');
console.log('平均睡眠质量:', sleepData.summary.averageSleepQuality);
console.log('清醒次数:', sleepData.summary.totalWakeUpCount);

// 访问详细记录
sleepData.items.forEach((item, index) => {
  console.log(`--- 睡眠记录 ${index + 1} ---`);
  console.log('入睡时间:', item.sleepTime);
  console.log('醒来时间:', item.wakeTime);
  console.log('深睡:', item.deepSleepMinutes, '分钟');
  console.log('浅睡:', item.lightSleepMinutes, '分钟');
  console.log('总时长:', item.totalSleepMinutes, '分钟');
  console.log('睡眠质量:', item.sleepQuality);
  console.log('清醒次数:', item.wakeUpCount);
});

// 计算睡眠时长（小时）
const sleepHours = Math.floor(sleepData.summary.totalSleepMinutes / 60);
const sleepMins = sleepData.summary.totalSleepMinutes % 60;
console.log(`睡眠时长: ${sleepHours}小时${sleepMins}分钟`);
```

#### 返回示例

```json
{
  "date": "2024-02-27",
  "items": [
    {
      "date": "2024-02-27",
      "sleepTime": "2024-02-26 22:30:00",
      "wakeTime": "2024-02-27 07:00:00",
      "deepSleepMinutes": 90,
      "lightSleepMinutes": 330,
      "totalSleepMinutes": 480,
      "sleepQuality": 85,
      "sleepLine": "...",
      "wakeUpCount": 2
    }
  ],
  "summary": {
    "totalDeepSleepMinutes": 90,
    "totalLightSleepMinutes": 330,
    "totalSleepMinutes": 480,
    "averageSleepQuality": 85,
    "totalWakeUpCount": 2
  }
}
```

#### 注意事项

1. **设备连接**: 调用此方法前需要先连接设备并验证密码
2. **数据来源**: 数据从设备本地数据库读取，不是实时测量
3. **多段睡眠**: 一天内可能有多段睡眠记录，`items` 数组会包含多条记录
4. **空数据**: 如果当天没有睡眠数据，`items` 数组为空，`summary` 各字段为 0

#### 错误处理

```typescript
try {
  const sleepData = await VeepooSDK.readSleepData('2024-02-27');
  // 处理数据
} catch (error) {
  console.error('读取睡眠数据失败:', error.message);
  // 可能的错误:
  // - DEVICE_NOT_CONNECTED: 设备未连接
  // - SDK_NOT_INITIALIZED: SDK 未初始化
  // - NO_DEVICE_CONNECTED: iOS 设备地址不可用
}
```

---

## 事件监听

### SLEEP_DATA 事件

睡眠数据读取完成时会触发 `SLEEP_DATA` 事件。

```typescript
import VeepooSDK, { VeepooEvent } from '@gaozh1024/expo-veepoo-sdk';

// 监听睡眠数据事件
VeepooSDK.addListener(VeepooEvent.SLEEP_DATA, (event) => {
  console.log('收到睡眠数据事件:', event);
  // event 结构:
  // {
  //   deviceId: string,
  //   date: string,
  //   data: SleepData
  // }
});

// 不再需要时移除监听
VeepooSDK.removeAllListeners(VeepooEvent.SLEEP_DATA);
```
