# iOS 5分钟和30分钟原始数据字段对比报告

## 📊 对比概览

| 数据类型 | 文档定义 | iOS 代码实现 | 状态 |
|---------|---------|------------|------|
| **5分钟数据 (OriginData)** | ✅ 完整 | ✅ 完整 | **通过** |
| **30分钟数据 (HalfHourData)** | ✅ 定义 | ⚠️ 部分缺失 | **需要修复** |

---

## ✅ 5分钟数据 (OriginData) - 检查通过

### TypeScript 类型定义 vs iOS 代码实现

| 字段名 | 类型定义 | iOS 代码实现 | 数据来源 | 状态 |
|--------|---------|-------------|---------|------|
| `time` | string | ✅ | `originData` key | ✅ 正确 |
| `heartValue` | number | ✅ | `data["heartValue"]` | ✅ 正确 |
| `stepValue` | number | ✅ | `data["stepValue"]` | ✅ 正确 |
| `calValue` | number | ✅ | `data["calValue"]` | ✅ 正确 |
| `disValue` | number | ✅ | `data["disValue"]` | ✅ 正确 |
| `sportValue` | number | ✅ | `data["sportValue"]` | ✅ 正确 |
| `systolic` | number | ✅ | `data["systolic"]` 或 `data["highValue"]` | ✅ 正确（兼容两种key） |
| `diastolic` | number | ✅ | `data["diastolic"]` 或 `data["lowValue"]` | ✅ 正确（兼容两种key） |
| `spo2Value` | number | ✅ | `data["oxygens"]` max 或 `oxygenMap` | ✅ 正确（多数据源合并） |
| `tempValue` | number | ✅ | `data["tempValue"]` | ✅ 正确 |
| `stressValue` | number | ✅ | `data["stress"]` 或 `data["stressValue"]` | ✅ 正确（兼容两种key） |
| `met` | number | ✅ | `data["met"]` | ✅ 正确 |
| `oxygens` | number[] | ✅ | `data["oxygens"]` | ✅ 正确 |
| `ppgs` | number[] | ✅ | `data["ppgs"]` | ✅ 正确 |
| `ecgs` | number[] | ✅ | `data["ecgs"]` | ✅ 正确 |
| `bloodGlucose` | number | ✅ | `data["bloodGlucose"]` 或 `bloodGlucoseMap` | ✅ 正确（多数据源合并） |
| `respirationRate` | number | ✅ | `oxygenMap["RespirationRate"]` | ✅ 正确 |
| `isHypoxia` | number | ✅ | `oxygenMap["IsHypoxia"]` | ✅ 正确 |
| `cardiacLoad` | number | ✅ | `oxygenMap["CardiacLoad"]` | ✅ 正确 |
| `glucose` | number | ✅ | Double(bloodGlucose) | ✅ 正确（转换值） |
| `bloodGlucoseLevel` | any | ✅ | `bgData["bloodGlucoseLevels"]` | ✅ 正确 |

### 5分钟数据总结

**✅ 状态：完全正确，无需修改**

iOS 代码实现完整覆盖了 TypeScript 类型定义的所有字段，并且正确处理了：
1. 多数据源合并（原始数据 + 血氧表 + 血糖表）
2. 字段名兼容性（如 `highValue`/`systolic`）
3. 数值类型转换
4. 数组类型处理

---

## ⚠️ 30分钟数据 (HalfHourData) - 需要修复

### TypeScript 类型定义 vs iOS 代码实现

| 字段名 | 类型定义 | iOS 代码实现 | 数据来源 | 状态 | 备注 |
|--------|---------|-------------|---------|------|------|
| `time` | string | ✅ | `halfHourResult` key | ✅ 正确 | - |
| `heartValue` | number | ✅ | `item["heartValue"]` | ✅ 正确 | - |
| `stepValue` | number | ✅ | `item["stepValue"]` | ✅ 正确 | - |
| `calValue` | number | ✅ | `item["calValue"]` | ✅ 正确 | - |
| `disValue` | number | ✅ | `item["disValue"]` | ✅ 正确 | - |
| `systolic` | number | ✅ | `item["highValue"]` 或 `item["systolic"]` | ✅ 正确 | 兼容两种key |
| `diastolic` | number | ✅ | `item["lowValue"]` 或 `item["diastolic"]` | ✅ 正确 | 兼容两种key |
| **spo2Value** | number | ⚠️ **部分** | `item["spo2Value"]` 或 `oxygenMap` | ⚠️ 不完整 | 只从oxygenMap获取，缺少从item获取 |
| **tempValue** | number | ❌ **缺失** | - | ❌ **需要添加** | 代码中有字段但未从数据源获取 |
| **stressValue** | number | ✅ | `item["stress"]` 或 `item["pressure"]` | ✅ 正确 | 兼容两种key |
| **met** | number | ❌ **缺失** | - | ❌ **需要添加** | 类型定义有，但代码未处理 |
| **sportValue** | number | ❌ **缺失** | - | ❌ **需要添加** | 类型定义有，但代码未处理 |
| **bloodGlucose** | number | ⚠️ **部分** | `item["bloodGlucose"]` 或 `bloodGlucoseMap` | ⚠️ 不完整 | 已处理，但代码逻辑可以优化 |
| **glucose** | number | ⚠️ **部分** | Double(bloodGlucose) | ⚠️ 不完整 | 依赖bloodGlucose |

### 📋 30分钟数据文档定义

根据 `VeepooSDK iOS Api.md` 第 947-962 行，官方文档只定义了以下字段：
```objc
{
  "10:30" = {
    heartValue = 0;    // 半小时心率平均值
    sportValue = 108;  // 半小时运动量累加值
    stepValue = 0;     // 半小时计步数累加值
    calValue = 0;      // 半小时卡路里累加值
    disValue = 0;      // 半小时距离累加值
  };
}
```

**文档中只定义了 5 个字段：** `heartValue`, `sportValue`, `stepValue`, `calValue`, `disValue`

### ❌ 发现的问题

#### 问题 1: `sportValue` 字段缺失
**位置:** `VeepooSDKModule+ReadHelpers.swift` 第 15-23 行  
**代码:**
```swift
var dataItem: [String: Any] = [
  "time": time,
  "sportValue": 0,  // ⚠️ 硬编码为0，没有从数据源获取
  "systolic": 0,
  ...
]
```
**修复建议:**
```swift
if let sportStr = item["sportValue"], let sport = Double(sportStr) {
  dataItem["sportValue"] = Int(sport)
}
```

#### 问题 2: `met` 字段缺失
**位置:** `VeepooSDKModule+ReadHelpers.swift` 第 15-23 行  
**代码:** `met` 字段在初始化字典中不存在  
**修复建议:**
```swift
if let metStr = item["met"], let met = Double(metStr) {
  dataItem["met"] = met
}
```

#### 问题 3: `tempValue` 字段处理不完整
**位置:** `VeepooSDKModule+ReadHelpers.swift` 第 15-23 行  
**代码:** 虽然初始化为 0，但没有从 `item` 中读取  
**当前代码:**
```swift
var dataItem: [String: Any] = [
  ...
  "tempValue": 0,  // ⚠️ 硬编码
  ...
]
```
**修复建议:** 已经存在读取逻辑（第 160-162 行），但需要确认数据源是否提供该字段。

#### 问题 4: `spo2Value` 逻辑不完整
**位置:** `VeepooSDKModule+ReadHelpers.swift` 第 148-150 行  
**当前代码:**
```swift
if let spo2Str = item["spo2Value"], let spo2 = Int(spo2Str), spo2 > 0 {
  dataItem["spo2Value"] = spo2
}
```
**问题:** 只从 `item` 读取，没有从 `oxygenMap` 读取（像 5 分钟数据那样）  
**修复建议:**
```swift
// 优先从 item 读取
if let spo2Str = item["spo2Value"], let spo2 = Int(spo2Str), spo2 > 0 {
  dataItem["spo2Value"] = spo2
}
// 如果没有，从 oxygenMap 读取
if dataItem["spo2Value"] == nil, let oxyData = oxygenMap[time] {
  let oxygenValue = self.getInt(oxyData["OxygenValue"])
  if oxygenValue > 0 {
    dataItem["spo2Value"] = oxygenValue
  }
}
```

#### 问题 5: `bloodGlucose` 和 `glucose` 字段处理可以优化
**位置:** `VeepooSDKModule+ReadHelpers.swift` 第 151-154 行  
**当前代码:**
```swift
if let bgStr = item["bloodGlucose"], let bg = Int(bgStr), bg > 0 {
  dataItem["bloodGlucose"] = bg
  dataItem["glucose"] = Double(bg)
}
```
**问题:** 已经处理，但如果 `item` 没有但 `bloodGlucoseMap` 有，也应该设置 `glucose`  
**修复建议:**
```swift
if let bgData = bloodGlucoseMap[time] {
  if let bgValue = bgData["bloodGlucoses"] as? [Int], let first = bgValue.first, first > 0 {
    dataItem["bloodGlucose"] = first
    dataItem["glucose"] = Double(first)
  } else if let bgValue = bgData["bloodGlucose"] as? Int, bgValue > 0 {
    dataItem["bloodGlucose"] = bgValue
    dataItem["glucose"] = Double(bgValue)
  }
}
```

---

## 🔧 修复建议代码

### 修复 `emitHalfHourData` 函数

**文件:** `ios/VeepooSDK/VeepooSDKModule+ReadHelpers.swift`  
**行号:** 6-45

```swift
func emitHalfHourData(dayOffset: Int) {
  #if !targetEnvironment(simulator)
  guard let manager = self.bleManager,
        let deviceAddress = manager.peripheralModel?.deviceAddress else { return }
  
  let dateStr = self.getDateString(dayOffset: dayOffset)
  
  // 加载氧气数据映射（用于补充 spo2Value）
  var oxygenMap: [String: [String: Any]] = [:]
  if let oxygenArray = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
    for item in oxygenArray {
      if let time = item["Time"] as? String {
        oxygenMap[time] = item
      }
    }
  }
  
  // 加载血糖数据映射（用于补充 bloodGlucose）
  var bloodGlucoseMap: [String: [String: Any]] = [:]
  if let bloodGlucoseArray = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
    for item in bloodGlucoseArray {
      if let time = item["time"] as? String {
        bloodGlucoseMap[time] = item
      }
    }
  }
  
  if let halfHourResult = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: String]] {
    for (time, item) in halfHourResult {
      var dataItem: [String: Any] = [
        "time": time
      ]
      
      // 基础字段
      if let hrStr = item["heartValue"], let hr = Double(hrStr), hr > 0 {
        dataItem["heartValue"] = Int(hr)
      }
      if let stepStr = item["stepValue"], let step = Double(stepStr) {
        dataItem["stepValue"] = Int(step)
      }
      if let calStr = item["calValue"], let cal = Double(calStr) {
        dataItem["calValue"] = cal
      }
      if let disStr = item["disValue"], let dis = Double(disStr) {
        dataItem["disValue"] = dis
      }
      
      // ⚠️ 新增：从数据源读取 sportValue（之前缺失）
      if let sportStr = item["sportValue"], let sport = Double(sportStr) {
        dataItem["sportValue"] = Int(sport)
      } else {
        dataItem["sportValue"] = 0
      }
      
      // ⚠️ 新增：从数据源读取 met（之前缺失）
      if let metStr = item["met"], let met = Double(metStr) {
        dataItem["met"] = met
      } else {
        dataItem["met"] = 0
      }
      
      // 血压字段（兼容两种 key 名）
      if let highStr = item["highValue"], let high = Int(highStr), high > 0 {
        dataItem["systolic"] = high
      } else if let highStr = item["systolic"], let high = Int(highStr), high > 0 {
        dataItem["systolic"] = high
      } else {
        dataItem["systolic"] = 0
      }
      
      if let lowStr = item["lowValue"], let low = Int(lowStr), low > 0 {
        dataItem["diastolic"] = low
      } else if let lowStr = item["diastolic"], let low = Int(lowStr), low > 0 {
        dataItem["diastolic"] = low
      } else {
        dataItem["diastolic"] = 0
      }
      
      // SpO2 字段（优先从 item，其次从 oxygenMap）
      if let spo2Str = item["spo2Value"], let spo2 = Int(spo2Str), spo2 > 0 {
        dataItem["spo2Value"] = spo2
      } else if let oxyData = oxygenMap[time] {
        let oxygenValue = self.getInt(oxyData["OxygenValue"])
        if oxygenValue > 0 {
          dataItem["spo2Value"] = oxygenValue
        }
      } else {
        dataItem["spo2Value"] = 0
      }
      
      // 血糖字段（优先从 item，其次从 bloodGlucoseMap）
      if let bgStr = item["bloodGlucose"], let bg = Int(bgStr), bg > 0 {
        dataItem["bloodGlucose"] = bg
        dataItem["glucose"] = Double(bg)
      } else if let bgData = bloodGlucoseMap[time] {
        if let bgValue = bgData["bloodGlucoses"] as? [Int], let first = bgValue.first, first > 0 {
          dataItem["bloodGlucose"] = first
          dataItem["glucose"] = Double(first)
        } else if let bgValue = bgData["bloodGlucose"] as? Int, bgValue > 0 {
          dataItem["bloodGlucose"] = bgValue
          dataItem["glucose"] = Double(bgValue)
        }
      }
      
      // 压力字段（兼容两种 key 名）
      if let stressStr = item["stress"], let stress = Int(stressStr), stress > 0 {
        dataItem["stressValue"] = stress
      } else if let stressStr = item["pressure"], let stress = Int(stressStr), stress > 0 {
        dataItem["stressValue"] = stress
      } else {
        dataItem["stressValue"] = 0
      }
      
      // 体温字段
      if let tempStr = item["tempValue"], let temp = Double(tempStr), temp > 0 {
        dataItem["tempValue"] = temp
      } else {
        dataItem["tempValue"] = 0
      }
      
      self.sendEvent(ORIGIN_HALF_HOUR_DATA, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": dataItem
      ])
    }
  }
  #endif
}
```

---

## 📊 Android vs iOS 对比

### 字段一致性检查

| 字段名 | Android 实现 | iOS 实现 | 一致性 |
|--------|-------------|---------|--------|
| **5分钟数据** |
| time | ✅ | ✅ | ✅ 一致 |
| heartValue | ✅ | ✅ | ✅ 一致 |
| stepValue | ✅ | ✅ | ✅ 一致 |
| calValue | ✅ | ✅ | ✅ 一致 |
| disValue | ✅ | ✅ | ✅ 一致 |
| sportValue | ✅ | ✅ | ✅ 一致 |
| systolic | ✅ | ✅ | ✅ 一致 |
| diastolic | ✅ | ✅ | ✅ 一致 |
| spo2Value | ✅ | ✅ | ✅ 一致 |
| tempValue | ✅ | ✅ | ✅ 一致 |
| stressValue | ✅ | ✅ | ✅ 一致 |
| met | ✅ | ✅ | ✅ 一致 |
| bloodGlucose | ✅ | ✅ | ✅ 一致 |
| **30分钟数据** |
| time | ✅ | ✅ | ✅ 一致 |
| heartValue | ✅ | ✅ | ✅ 一致 |
| stepValue | ✅ | ✅ | ✅ 一致 |
| calValue | ✅ | ✅ | ✅ 一致 |
| disValue | ✅ | ✅ | ✅ 一致 |
| systolic | ✅ | ✅ | ✅ 一致 |
| diastolic | ✅ | ✅ | ✅ 一致 |
| spo2Value | ✅ | ⚠️ 部分 | ❌ **不一致** |
| tempValue | ✅ | ✅ | ✅ 一致 |
| stressValue | ✅ | ✅ | ✅ 一致 |
| met | ✅ | ❌ 缺失 | ❌ **不一致** |
| sportValue | ✅ | ❌ 缺失 | ❌ **不一致** |

### 差异总结

**Android 优势:**
- 使用 `buildHalfHourItems` 函数统一构建 30 分钟数据
- 正确处理 `halfHourSportDatas`, `halfHourRateDatas`, `halfHourBps` 三个数据源
- 字段默认值处理完善

**iOS 问题:**
- 直接从字典读取，没有数据源合并逻辑
- `sportValue` 和 `met` 字段缺失
- `spo2Value` 没有使用 oxygenMap 作为备选

---

## 🎯 修复优先级

### 🔴 高优先级（必须修复）

1. **添加 `sportValue` 字段读取**
   - 影响：类型定义中有该字段，JS 代码可能依赖它
   - 文件：`VeepooSDKModule+ReadHelpers.swift`
   - 工作量：小（添加 3 行代码）

2. **添加 `met` 字段读取**
   - 影响：类型定义中有该字段
   - 文件：`VeepooSDKModule+ReadHelpers.swift`
   - 工作量：小（添加 3 行代码）

### 🟡 中优先级（建议修复）

3. **完善 `spo2Value` 读取逻辑**
   - 影响：数据完整性
   - 文件：`VeepooSDKModule+ReadHelpers.swift`
   - 工作量：小（添加 6 行代码）

4. **统一 `emitHalfHourData` 和 `handleStartReadOriginData` 中的 30 分钟数据处理**
   - 影响：代码维护性
   - 文件：`VeepooSDKModule+ReadHelpers.swift`, `VeepooSDKModule+Handlers.swift`
   - 工作量：中（重构重复代码）

### 🟢 低优先级（可选优化）

5. **添加默认值处理确保所有字段都存在**
   - 影响：JS 端类型安全
   - 工作量：小

---

## ✅ 结论

### 5分钟数据
**状态：✅ 完全正确**

iOS 代码正确实现了所有 TypeScript 类型定义的字段，并且：
- 正确处理了多数据源合并（原始数据 + 血氧表 + 血糖表）
- 字段名兼容性处理完善
- 数值类型转换正确

### 30分钟数据
**状态：⚠️ 需要修复**

发现以下字段缺失或不完善：
1. ❌ `sportValue` - 硬编码为 0，没有从数据源读取
2. ❌ `met` - 完全缺失
3. ⚠️ `spo2Value` - 没有使用 oxygenMap 作为备选数据源

**建议立即修复**以确保 iOS 和 Android 返回的数据结构一致。

---

## 📝 修复检查清单

- [ ] 修复 `sportValue` 字段读取（`VeepooSDKModule+ReadHelpers.swift` 第 15-23 行）
- [ ] 添加 `met` 字段读取（`VeepooSDKModule+ReadHelpers.swift` 第 15-23 行）
- [ ] 完善 `spo2Value` 读取逻辑，添加 oxygenMap 备选（`VeepooSDKModule+ReadHelpers.swift` 第 148-168 行）
- [ ] 同步修复 `VeepooSDKModule+Handlers.swift` 中的 30 分钟数据处理逻辑（第 121-185 行）
- [ ] 测试验证 30 分钟数据的所有字段都能正确返回
- [ ] 对比 Android 和 iOS 返回的数据结构一致性
