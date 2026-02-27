# 统一睡眠数据返回格式

## TL;DR

> **目标**: 统一 Android 和 iOS 平台的睡眠数据返回格式，提供一致的 API 和完善的文档
> 
> **交付物**:
> - 更新后的 TypeScript 类型定义
> - 修改后的 Android 原生代码
> - 修改后的 iOS 原生代码
> - API 使用文档
> 
> **预估工时**: Short
> **并行执行**: NO - 需要按顺序执行
> **关键路径**: 类型定义 → Android 代码 → iOS 代码 → 文档

---

## 背景

当前 Android 和 iOS 平台返回的睡眠数据结构不一致：

| 字段 | Android | iOS |
|------|--------|------|
| 返回类型 | 单个对象 | 字典数组 |
| 深睡时长 | deepSleepDuration (小时) | deepSleepDuration (小时) |
| 浅睡时长 | lightSleepDuration (小时) | lightSleepDuration (小时) |
| 总睡眠 | totalSleepHours + totalSleepMinutes | totalSleepHours |
| 睡眠质量 | sleepLevel | sleepLevel |

**问题**: 应用层需要针对不同平台编写不同的处理逻辑

---

## 新的统一格式

### SleepDataItem (单条睡眠记录)

```typescript
export interface SleepDataItem {
  // 日期 (yyyy-MM-dd)
  date: string;
  
  // 入睡时间 (HH:mm 或 yyyy-MM-dd HH:mm:ss)
  sleepTime: string;
  
  // 醒来时间 (HH:mm 或 yyyy-MM-dd HH:mm:ss)
  wakeTime: string;
  
  // 深睡时长 (分钟)
  deepSleepMinutes: number;
  
  // 浅睡时长 (分钟)
  lightSleepMinutes: number;
  
  // 总睡眠时长 (分钟)
  totalSleepMinutes: number;
  
  // 睡眠质量评分 (0-100)
  sleepQuality: number;
  
  // 睡眠曲线数据 (设备返回的原始字符串)
  sleepLine: string;
  
  // 清醒次数
  wakeUpCount: number;
}
```

### SleepData (完整睡眠数据)

```typescript
export interface SleepData {
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

---

## TODOs

- [ ] 1. 更新 TypeScript 类型定义 (src/types.ts)

  **文件**: `src/types.ts`
  
  **修改内容**:
  - 删除旧的 `SleepData` 接口
  - 添加新的 `SleepDataItem` 接口
  - 添加新的 `SleepData` 接口 (包含 items 和 summary)
  
  **推荐 Agent**: quick

- [ ] 2. 修改 Android 原生代码 (VeepooSDKModule.kt)

  **文件**: `android/src/main/kotlin/expo/modules/veepoo/VeepooSDKModule.kt`
  
  **修改位置**: `readSleepData` 方法 (约 line 958-1053)
  
  **修改内容**:
  - 修改返回格式为统一结构
  - 计算 summary 汇总数据
  - 字段名统一:
    - `deepSleepDuration` → `deepSleepMinutes`
    - `lightSleepDuration` → `lightSleepMinutes`
    - `totalSleepHours/totalSleepMinutes` → `totalSleepMinutes`
    - `sleepLevel` → `sleepQuality`
  
  **推荐 Agent**: quick

- [ ] 3. 修改 iOS 原生代码 (VeepooSDK.swift)

  **文件**: `ios/VeepooSDK/VeepooSDK.swift`
  
  **修改位置**: `readSleepData` 方法 (约 line 539-591)
  
  **修改内容**:
  - 修改返回格式为统一结构
  - 计算 summary 汇总数据
  - 字段名统一 (同 Android)
  
  **推荐 Agent**: quick

- [ ] 4. 添加 API 文档 (README.md 或 docs/)

  **文件**: `README.md` 或新建 `docs/api.md`
  
  **内容**:
  - `readSleepData(date)` 方法说明
  - 参数说明
  - 返回值结构说明
  - 使用示例代码
  
  **推荐 Agent**: quick

---

## 验证计划

### 测试用例

1. **Android 构建**: `npm run build` 通过
2. **iOS 构建**: TypeScript 编译通过
3. **数据结构验证**:
   - 调用 `readSleepData('2024-02-27')`
   - 验证返回结构包含 `date`, `items`, `summary`
   - 验证 `items` 数组元素包含所有必需字段
   - 验证 `summary` 计算正确

---

## 成功标准

- [ ] TypeScript 编译无错误
- [ ] Android 代码返回统一格式
- [ ] iOS 代码返回统一格式
- [ ] 文档完整清晰
- [ ] 应用层可以直接使用统一的数据结构
