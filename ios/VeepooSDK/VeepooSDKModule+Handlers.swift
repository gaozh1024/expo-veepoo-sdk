import ExpoModulesCore
import VeepooBleSDK

// 辅助类：用于在闭包间共享可变状态
private class ProgressWrapper {
  var value: Int = 0
}

private class ValueWrapper<T> {
  var value: T
  init(value: T) {
    self.value = value
  }
}

// MARK: - 数据读取和测试方法的实现
extension VeepooSDKModule {
  
  // MARK: 读取原始数据
  func handleStartReadOriginData(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard self.isInitialized else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
      return
    }
    
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected or address unavailable")
      return
    }
    
    self.sendEvent(READ_ORIGIN_PROGRESS, [
      "deviceId": self.connectedDeviceId ?? "",
      "progress": [
        "readState": "start",
        "totalDays": 1,
        "currentDay": 1,
        "progress": 0.0
      ]
    ])
    
    let dateStr = self.getDateString(dayOffset: 0)
    
    var oxygenMap: [String: [String: Any]] = [:]
    if let oxygenArray = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
      for item in oxygenArray {
        if let time = item["Time"] as? String {
          oxygenMap[time] = item
        }
      }
    }
    
    var bloodGlucoseMap: [String: [String: Any]] = [:]
    if let bloodGlucoseArray = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
      for item in bloodGlucoseArray {
        if let time = item["time"] as? String {
          bloodGlucoseMap[time] = item
        }
      }
    }
    
    if let originData = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: Any]] {
      // 按时间排序后遍历，确保数据按时间顺序发送
      for (time, data) in originData.sorted(by: { $0.key < $1.key }) {
        var item: [String: Any] = [
          "time": time,
          "heartValue": data["heartValue"] ?? 0,
          "stepValue": data["stepValue"] ?? 0,
          "calValue": data["calValue"] ?? 0,
          "disValue": data["disValue"] ?? 0,
          "sportValue": data["sportValue"] ?? 0,
          "systolic": data["systolic"] ?? data["highValue"] ?? 0,
          "diastolic": data["diastolic"] ?? data["lowValue"] ?? 0,
          "spo2Value": (data["oxygens"] as? [Int])?.max() ?? data["spo2Value"] ?? 0,
          "tempValue": data["tempValue"] ?? 0,
          "stressValue": data["stress"] ?? data["stressValue"] ?? 0,
          "met": data["met"] ?? 0
        ]
        
        if let oxyData = oxygenMap[time] {
          let oxygenValue = self.getInt(oxyData["OxygenValue"])
          if oxygenValue > 0 {
            item["spo2Value"] = oxygenValue
          }
          item["respirationRate"] = self.getInt(oxyData["RespirationRate"])
          item["isHypoxia"] = self.getInt(oxyData["IsHypoxia"])
          item["cardiacLoad"] = self.getDouble(oxyData["CardiacLoad"])
        }
        
        // 合并血糖数据
        if let bgData = bloodGlucoseMap[time] {
          // SDK 返回的 bloodGlucoses 是 [String] 类型，需要正确转换
          if let bgValue = bgData["bloodGlucoses"] as? [String],
             let firstStr = bgValue.first,
             let first = Int(firstStr), first > 0 {
            item["bloodGlucose"] = first
            item["glucose"] = Double(first)
          } else if let bgValue = bgData["bloodGlucose"] as? Int, bgValue > 0 {
            item["bloodGlucose"] = bgValue
            item["glucose"] = Double(bgValue)
          }
          item["bloodGlucoseLevel"] = bgData["bloodGlucoseLevels"]
          item["bloodGlucoses"] = bgData["bloodGlucoses"]
        }
        
        // 处理原始数据中的血糖字段（如果上面的合并没有成功）
        if let bloodGlucose = data["bloodGlucose"] as? Int, item["bloodGlucose"] == nil {
          item["bloodGlucose"] = bloodGlucose
          item["glucose"] = Double(bloodGlucose)
        }
        
        if let ppgs = data["ppgs"] as? [Int] {
          item["ppgs"] = ppgs
        }
        if let ecgs = data["ecgs"] as? [Int] {
          item["ecgs"] = ecgs
        }
        if let oxygens = data["oxygens"] as? [Int] {
          item["oxygens"] = oxygens
        }

        // 处理扩展数组类型的原始数据（与 Android 保持一致）
        if let resRates = data["resRates"] as? [Int] {
          item["resRates"] = resRates
        }
        if let sleepStates = data["sleepStates"] as? [Int] {
          item["sleepStates"] = sleepStates
        }
        if let apneaResults = data["apneaResults"] as? [Int] {
          item["apneaResults"] = apneaResults
        }
        if let hypoxiaTimes = data["hypoxiaTimes"] as? [Int] {
          item["hypoxiaTimes"] = hypoxiaTimes
        }
        if let cardiacLoads = data["cardiacLoads"] as? [Int] {
          item["cardiacLoads"] = cardiacLoads
        }

        self.sendEvent(ORIGIN_FIVE_MINUTE_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": item
        ])
      }
      
      self.sendEvent(READ_ORIGIN_PROGRESS, [
        "deviceId": self.connectedDeviceId ?? "",
        "progress": [
          "readState": "reading",
          "totalDays": 1,
          "currentDay": 1,
          "progress": 0.5
        ]
      ])
    }
    
    if let halfHourResult = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: String]] {
      // 按时间排序后遍历，确保数据按时间顺序发送
      for (time, item) in halfHourResult.sorted(by: { $0.key < $1.key }) {
        var dataItem: [String: Any] = ["time": time]
        
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

        // sportValue 和 met（从数据源读取）
        if let sportStr = item["sportValue"], let sport = Double(sportStr) {
          dataItem["sportValue"] = Int(sport)
        }
        if let metStr = item["met"], let met = Double(metStr) {
          dataItem["met"] = met
        }

        if let highStr = item["highValue"], let high = Int(highStr), high > 0 {
          dataItem["systolic"] = high
        } else if let highStr = item["systolic"], let high = Int(highStr), high > 0 {
          dataItem["systolic"] = high
        }
        if let lowStr = item["lowValue"], let low = Int(lowStr), low > 0 {
          dataItem["diastolic"] = low
        } else if let lowStr = item["diastolic"], let low = Int(lowStr), low > 0 {
          dataItem["diastolic"] = low
        }
        if let spo2Str = item["spo2Value"], let spo2 = Int(spo2Str), spo2 > 0 {
          dataItem["spo2Value"] = spo2
        }
        if let bgStr = item["bloodGlucose"], let bg = Int(bgStr), bg > 0 {
          dataItem["bloodGlucose"] = bg
          dataItem["glucose"] = Double(bg)
        }
        if let stressStr = item["stress"], let stress = Int(stressStr), stress > 0 {
          dataItem["stressValue"] = stress
        } else if let stressStr = item["pressure"], let stress = Int(stressStr), stress > 0 {
          dataItem["stressValue"] = stress
        }
        if let tempStr = item["tempValue"], let temp = Double(tempStr), temp > 0 {
          dataItem["tempValue"] = temp
        }
        
        if let oxyData = oxygenMap[time] {
          let oxygenValue = self.getInt(oxyData["OxygenValue"])
          if oxygenValue > 0 {
            dataItem["spo2Value"] = oxygenValue
          }
        }
        
        // 合并血糖数据
        if let bgData = bloodGlucoseMap[time] {
          // SDK 返回的 bloodGlucoses 是 [String] 类型，需要正确转换
          if let bgValue = bgData["bloodGlucoses"] as? [String],
             let firstStr = bgValue.first,
             let first = Int(firstStr), first > 0 {
            dataItem["bloodGlucose"] = first
            dataItem["glucose"] = Double(first)
          } else if let bgValue = bgData["bloodGlucose"] as? Int, bgValue > 0 {
            dataItem["bloodGlucose"] = bgValue
            dataItem["glucose"] = Double(bgValue)
          }
          dataItem["bloodGlucoseLevel"] = bgData["bloodGlucoseLevels"]
          dataItem["bloodGlucoses"] = bgData["bloodGlucoses"]
        }
        
        self.sendEvent(ORIGIN_HALF_HOUR_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": dataItem
        ])
      }
    }
    
    self.sendEvent(READ_ORIGIN_PROGRESS, [
      "deviceId": self.connectedDeviceId ?? "",
      "progress": [
        "readState": "complete",
        "totalDays": 1,
        "currentDay": 1,
        "progress": 1.0
      ]
    ])
    
    self.sendEvent(READ_ORIGIN_COMPLETE, [
      "deviceId": self.connectedDeviceId ?? "",
      "success": true
    ])
    
    promise.resolve(nil)
    #endif
  }
  
  // MARK: 读取睡眠数据
  func handleReadSleepData(date: String?, promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected")
      return
    }
    
    let queryDate = date ?? self.getDateString(dayOffset: 0)
    var items: [[String: Any]] = []
    let sleepType = manager.peripheralModel?.sleepType ?? 0
    
    if sleepType > 0 {
      if let sleepItems = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: queryDate, andTableID: deviceAddress) {
        for item in sleepItems {
          let deepMinutes = Int(Double(item.deepDuration ?? "0") ?? 0)
          let lightMinutes = Int(Double(item.lightDuration ?? "0") ?? 0)
          let totalMinutes = Int(Double(item.sleepDuration ?? "0") ?? 0)
          let quality = Int(Double(item.sleepQuality ?? "0") ?? 0)
          let wakeCount = Int(Double(item.insomniaTimes ?? "0") ?? 0)
          
          let dict: [String: Any] = [
            "date": String(item.wakeTime.prefix(10)),
            "sleepTime": item.sleepTime.count > 16 ? item.sleepTime : (item.sleepTime + ":00"),
            "wakeTime": item.wakeTime.count > 16 ? item.wakeTime : (item.wakeTime + ":00"),
            "deepSleepMinutes": deepMinutes,
            "lightSleepMinutes": lightMinutes,
            "totalSleepMinutes": totalMinutes,
            "sleepQuality": quality,
            "sleepLine": item.sleepLine ?? "",
            "wakeUpCount": wakeCount
          ]
          items.append(dict)
        }
      }
    } else {
      if let sleepItems = VPDataBaseOperation.veepooSDKGetSleepData(withDate: queryDate, andTableID: deviceAddress) as? [[String: Any]] {
        items = self.formatOrdinarySleepToNewFormat(sleepItems)
      }
    }
    
    var totalDeep = 0
    var totalLight = 0
    var totalMinutes = 0
    var totalQuality = 0
    var totalWake = 0
    
    for item in items {
      totalDeep += (item["deepSleepMinutes"] as? Int) ?? 0
      totalLight += (item["lightSleepMinutes"] as? Int) ?? 0
      totalMinutes += (item["totalSleepMinutes"] as? Int) ?? 0
      totalQuality += (item["sleepQuality"] as? Int) ?? 0
      totalWake += (item["wakeUpCount"] as? Int) ?? 0
    }
    
    let avgQuality = items.count > 0 ? totalQuality / items.count : 0
    
    let result: [String: Any] = [
      "date": queryDate,
      "items": items,
      "summary": [
        "totalDeepSleepMinutes": totalDeep,
        "totalLightSleepMinutes": totalLight,
        "totalSleepMinutes": totalMinutes,
        "averageSleepQuality": avgQuality,
        "totalWakeUpCount": totalWake
      ]
    ]
    
    self.sendEvent(SLEEP_DATA, [
      "deviceId": self.connectedDeviceId ?? "",
      "date": queryDate,
      "data": result
    ])
    
    let resultList = [result]
    promise.resolve(resultList)
    #endif
  }
  
  // MARK: 读取运动步数数据
  func handleReadSportStepData(date: String?, promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let manager = VPBleCentralManage.sharedBleManager(),
          let deviceAddress = manager.peripheralModel?.deviceAddress else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected or address unavailable")
      return
    }
    
    let queryDate = date ?? self.getDateString(dayOffset: 0)
    let userStature: UInt = manager.peripheralModel?.deviceStature ?? 170
    
    DispatchQueue.main.async {
      VPDataBaseOperation.veepooSDKGetStepData(withDate: queryDate, andTableID: deviceAddress, changeUserStature: userStature) { stepDict in
        guard let dict = stepDict as? [String: Any] else {
          let emptyResult: [String: Any] = [
            "date": queryDate,
            "stepCount": 0,
            "distance": 0.0,
            "calories": 0.0
          ]
          promise.resolve(emptyResult)
          return
        }
        
        let stepValue: Any = dict["Step"]
        let disValue: Any = dict["Dis"]
        let calValue: Any = dict["Cal"]
        
        let step = self.getInt(stepValue)
        let disKm = self.getDouble(disValue)
        let cal = self.getDouble(calValue)
        
        let result: [String: Any] = [
          "date": queryDate,
          "stepCount": step,
          "distance": disKm,
          "calories": cal
        ]
        
        self.sendEvent(SPORT_STEP_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "date": queryDate,
          "data": result
        ])
        
        promise.resolve(result)
      }
    }
    #endif
  }
  
  // MARK: 读取原始数据（按天）
  func handleReadOriginData(dayOffset: Int, promise: Promise) {
    #if !targetEnvironment(simulator)
    guard self.isInitialized else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
      return
    }
    
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected or address unavailable")
      return
    }
    
    let dateStr = self.getDateString(dayOffset: dayOffset)
    var resultList: [[String: Any]] = []
    
    var oxygenMap: [String: [String: Any]] = [:]
    if let oxygenArray = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
      for item in oxygenArray {
        if let time = item["Time"] as? String {
          oxygenMap[time] = item
        }
      }
    }
    
    var bloodGlucoseMap: [String: [String: Any]] = [:]
    if let bloodGlucoseArray = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
      for item in bloodGlucoseArray {
        if let time = item["time"] as? String {
          bloodGlucoseMap[time] = item
        }
      }
    }
    
    if let originData = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: Any]] {
      for (time, data) in originData {
        var item: [String: Any] = [
          "time": time,
          "heartValue": data["heartValue"] ?? 0,
          "stepValue": data["stepValue"] ?? 0,
          "calValue": data["calValue"] ?? 0,
          "disValue": data["disValue"] ?? 0,
          "sportValue": data["sportValue"] ?? 0,
          "systolic": data["systolic"] ?? data["highValue"] ?? 0,
          "diastolic": data["diastolic"] ?? data["lowValue"] ?? 0,
          "spo2Value": (data["oxygens"] as? [Int])?.max() ?? data["spo2Value"] ?? 0,
          "tempValue": data["tempValue"] ?? 0,
          "stressValue": data["stress"] ?? data["stressValue"] ?? 0,
          "met": data["met"] ?? 0
        ]
        
        if let oxyData = oxygenMap[time] {
          let oxygenValue = self.getInt(oxyData["OxygenValue"])
          if oxygenValue > 0 {
            item["spo2Value"] = oxygenValue
          }
          item["respirationRate"] = self.getInt(oxyData["RespirationRate"])
          item["isHypoxia"] = self.getInt(oxyData["IsHypoxia"])
          item["cardiacLoad"] = self.getDouble(oxyData["CardiacLoad"])
        }
        
        // 合并血糖数据
        if let bgData = bloodGlucoseMap[time] {
          // SDK 返回的 bloodGlucoses 是 [String] 类型，需要正确转换
          if let bgValue = bgData["bloodGlucoses"] as? [String],
             let firstStr = bgValue.first,
             let first = Int(firstStr), first > 0 {
            item["bloodGlucose"] = first
            item["glucose"] = Double(first)
          } else if let bgValue = bgData["bloodGlucose"] as? Int, bgValue > 0 {
            item["bloodGlucose"] = bgValue
            item["glucose"] = Double(bgValue)
          }
          item["bloodGlucoseLevel"] = bgData["bloodGlucoseLevels"]
          item["bloodGlucoses"] = bgData["bloodGlucoses"]
        }
        
        // 处理原始数据中的血糖字段（如果上面的合并没有成功）
        if let bloodGlucose = data["bloodGlucose"] as? Int, item["bloodGlucose"] == nil {
          item["bloodGlucose"] = bloodGlucose
          item["glucose"] = Double(bloodGlucose)
        }
        
        if let ppgs = data["ppgs"] as? [Int] {
          item["ppgs"] = ppgs
        }
        if let ecgs = data["ecgs"] as? [Int] {
          item["ecgs"] = ecgs
        }
        if let oxygens = data["oxygens"] as? [Int] {
          item["oxygens"] = oxygens
        }

        // 处理扩展数组类型的原始数据（与 Android 保持一致）
        if let resRates = data["resRates"] as? [Int] {
          item["resRates"] = resRates
        }
        if let sleepStates = data["sleepStates"] as? [Int] {
          item["sleepStates"] = sleepStates
        }
        if let apneaResults = data["apneaResults"] as? [Int] {
          item["apneaResults"] = apneaResults
        }
        if let hypoxiaTimes = data["hypoxiaTimes"] as? [Int] {
          item["hypoxiaTimes"] = hypoxiaTimes
        }
        if let cardiacLoads = data["cardiacLoads"] as? [Int] {
          item["cardiacLoads"] = cardiacLoads
        }

        resultList.append(item)
      }
    }
    
    let sortedResult = resultList.sorted { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
    promise.resolve(sortedResult)
    #endif
  }
  
  // MARK: 读取每日汇总数据
  func handleReadDaySummaryData(dayOffset: Int, promise: Promise) {
    #if !targetEnvironment(simulator)
    guard self.isInitialized else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
      return
    }
    
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected or address unavailable")
      return
    }
    
    let dateStr = self.getDateString(dayOffset: dayOffset)
    
    var sportList: [[String: Any]] = []
    var rateList: [[String: Any]] = []
    var bpList: [[String: Any]] = []
    var allStep = 0
    
    if let halfHourResult = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: String]] {
      for (time, item) in halfHourResult {
        var sportItem: [String: Any] = ["time": time, "step": 0, "cal": 0.0, "dis": 0.0]
        var rateItem: [String: Any] = ["time": time, "rate": 0]
        
        if let stepStr = item["stepValue"], let step = Int(stepStr) {
          sportItem["step"] = step
          allStep += step
        }
        if let calStr = item["calValue"], let cal = Double(calStr) {
          sportItem["cal"] = cal
        }
        if let disStr = item["disValue"], let dis = Double(disStr) {
          sportItem["dis"] = dis
        }
        if let hrStr = item["heartValue"], let hr = Int(hrStr), hr > 0 {
          rateItem["rate"] = hr
          rateList.append(rateItem)
        }
        
        // 读取血压数据（与 Android 保持一致）
        let highValue = item["highValue"] ?? item["systolic"] ?? "0"
        let lowValue = item["lowValue"] ?? item["diastolic"] ?? "0"
        if let high = Int(highValue), let low = Int(lowValue), high > 0 || low > 0 {
          bpList.append([
            "time": time,
            "high": high,
            "low": low
          ])
        }
        
        sportList.append(sportItem)
      }
    }
    
    let sortedSportList = sportList.sorted { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
    let sortedRateList = rateList.sorted { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
    let sortedBpList = bpList.sorted { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
    
    let result: [String: Any] = [
      "date": dateStr,
      "allStep": allStep,
      "sportList": sortedSportList,
      "rateList": sortedRateList,
      "bpList": sortedBpList
    ]
    
    promise.resolve(result)
    #endif
  }
  
  // MARK: 读取自动测量设置
  func handleReadAutoMeasureSetting(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard self.isInitialized else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
      return
    }
    
    guard let manager = self.bleManager,
          let peripheralManage = manager.peripheralManage else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected")
      return
    }
    
    peripheralManage.veepooSDKReadAutoMonitSwitchInfo { settingList in
      guard let list = settingList as? [VPAutoMonitTestModel] else {
        promise.reject("READ_FAILED", "Failed to read auto measure settings")
        return
      }
      
      let result = list.map { model -> [String: Any] in
        return [
          "protocolType": 1,
          "funType": Int(model.type.rawValue),
          "isSwitchOpen": model.on,
          "stepUnit": Int(model.minStepValue),
          "isSlotModify": model.supportRangeTime,
          "isIntervalModify": true,
          "supportStartMinute": Int(model.startHourRef) * 60 + Int(model.startMinuteRef),
          "supportEndMinute": Int(model.endHourRef) * 60 + Int(model.endMinuteRef),
          "measureInterval": Int(model.timeInterval),
          "currentStartMinute": Int(model.startHour) * 60 + Int(model.startMinute),
          "currentEndMinute": Int(model.endHour) * 60 + Int(model.endMinute)
        ]
      }
      
      promise.resolve(result)
    }
    #endif
  }
  
  // MARK: 修改自动测量设置
  func handleModifyAutoMeasureSetting(setting: [String: Any], promise: Promise) {
    #if !targetEnvironment(simulator)
    guard self.isInitialized else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
      return
    }
    
    guard let manager = self.bleManager,
          let peripheralManage = manager.peripheralManage else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected")
      return
    }
    
    peripheralManage.veepooSDKReadAutoMonitSwitchInfo { settingList in
      guard let list = settingList as? [VPAutoMonitTestModel] else {
        promise.reject("READ_FAILED", "Failed to read settings before modifying")
        return
      }
      
      guard let funTypeInt = setting["funType"] as? Int,
            let targetType = VPAutoMonitTestType(rawValue: UInt(funTypeInt)),
            let model = list.first(where: { $0.type == targetType }) else {
        promise.reject("INVALID_TYPE", "Function type not found or invalid")
        return
      }
      
      if let isOpen = setting["isSwitchOpen"] as? Bool {
        model.on = isOpen
      }
      if let measureInterval = setting["measureInterval"] as? Int {
        model.timeInterval = UInt16(measureInterval)
      }
      if let currentStartMinute = setting["currentStartMinute"] as? Int {
        model.startHour = UInt8(currentStartMinute / 60)
        model.startMinute = UInt8(currentStartMinute % 60)
      }
      if let currentEndMinute = setting["currentEndMinute"] as? Int {
        model.endHour = UInt8(currentEndMinute / 60)
        model.endMinute = UInt8(currentEndMinute % 60)
      }
      
      peripheralManage.veepooSDKSetAutoMonitSwitch(with: model) { (success, resultModel) in
        guard success else {
          promise.reject("MODIFY_FAILED", "Device returned failure")
          return
        }
        
        var finalList = list
        if let updatedModel = resultModel,
           let index = finalList.firstIndex(where: { $0.type == updatedModel.type }) {
          finalList[index] = updatedModel
        }
        
        let result = finalList.map { model -> [String: Any] in
          return [
            "protocolType": 1,
            "funType": Int(model.type.rawValue),
            "isSwitchOpen": model.on,
            "stepUnit": Int(model.minStepValue),
            "isSlotModify": model.supportRangeTime,
            "isIntervalModify": true,
            "supportStartMinute": Int(model.startHourRef) * 60 + Int(model.startMinuteRef),
            "supportEndMinute": Int(model.endHourRef) * 60 + Int(model.endMinuteRef),
            "measureInterval": Int(model.timeInterval),
            "currentStartMinute": Int(model.startHour) * 60 + Int(model.startMinute),
            "currentEndMinute": Int(model.endHour) * 60 + Int(model.endMinute)
          ]
        }
        
        promise.resolve(result)
      }
    }
    #endif
  }
  
  // MARK: 开始心率测试
  func handleStartHeartRateTest(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let peripheralManage = self.peripheralManage else {
      promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
      return
    }
    
    // 检查设备是否支持心率功能
    if let manager = self.bleManager {
      let heartRateType = manager.peripheralModel?.deviceFuctionData[18] ?? 0
      print("[HeartRate] Starting test - Device heartRate support: \(heartRateType == 0 ? "support" : "unsupported")")
    }
    
    let progressWrapper = ProgressWrapper()
    let heartRateValueWrapper = ValueWrapper<Int>(value: 0)  // 保存最后的心率值
    var progressTimer: Timer?
    
    // 25秒完成，每0.5秒触发一次，共50次，每次增长2
    // 使用主线程创建 Timer，确保 RunLoop 正确
    DispatchQueue.main.async {
      progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
      progressWrapper.value += 2
      let currentProgress = progressWrapper.value
      let currentHeartRate = heartRateValueWrapper.value
      
      print("[HeartRate] Timer - progress: \(currentProgress), heartRate: \(currentHeartRate)")
      
      if currentProgress >= 100 {
        timer.invalidate()
        // 如果 Timer 到达 100 但 SDK 还没有返回 over，自动停止测试
        print("[HeartRate] Timer reached 100, auto-stopping test, final heartRate: \(currentHeartRate)")
        peripheralManage.veepooSDKTestHeartStart(false) { _, _ in }
        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "over",
            "value": currentHeartRate,
            "progress": 100
          ]
        ])
        return
      }
      
      self.sendEvent(HEART_RATE_TEST_RESULT, [
        "deviceId": self.connectedDeviceId ?? "",
        "result": [
          "state": "testing",
          "value": currentHeartRate,
          "progress": currentProgress
        ]
      ])
    }
    }
    
    peripheralManage.veepooSDKTestHeartStart(true) { [weak self] state, heartValue in
      guard let self = self else { return }
      print("[HeartRate] SDK callback - state: \(state.rawValue), heartValue: \(heartValue)")
      
      switch state {
      case .start:
        print("[HeartRate] Test started")
        
      case .testing:
        // 测试中获得实时心率值，保存并发送事件
        print("[HeartRate] Testing - BPM: \(heartValue)")
        heartRateValueWrapper.value = Int(heartValue)  // 保存心率值
        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "testing",
            "value": heartValue,
            "progress": progressWrapper.value
          ]
        ])
        
      case .notWear:
        print("[HeartRate] Device not worn")
        progressTimer?.invalidate()
        heartRateValueWrapper.value = Int(heartValue)
        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "notWear",
            "value": heartValue,
            "progress": progressWrapper.value
          ]
        ])
        
      case .deviceBusy:
        print("[HeartRate] Device is busy")
        progressTimer?.invalidate()
        heartRateValueWrapper.value = Int(heartValue)
        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "deviceBusy",
            "value": heartValue,
            "progress": progressWrapper.value
          ]
        ])
        
      case .over:
        print("[HeartRate] Test completed - BPM: \(heartValue)")
        heartRateValueWrapper.value = Int(heartValue)
        progressTimer?.invalidate()
        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "over",
            "value": heartValue,
            "progress": 100
          ]
        ])
        
      default:
        print("[HeartRate] Unknown state: \(state.rawValue)")
        break
      }
    }
    
    promise.resolve(nil)
    #endif
  }
  
  // MARK: 开始血压测试
  func handleStartBloodPressureTest(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let peripheralManage = self.peripheralManage else {
      promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
      return
    }
    
    // 检查设备是否支持血压功能
    if let manager = self.bleManager {
      let bpType = manager.peripheralModel?.bloodPressureType ?? 0
      print("[BloodPressure] Starting test - Device bloodPressureType: \(bpType)")
    }
    
    peripheralManage.veepooSDKTestBloodStart(true, testMode: 0) { [weak self] state, progress, high, low in
      guard let self = self else { return }
      
      print("[BloodPressure] SDK callback - state: \(state.rawValue), progress: \(progress), high: \(high), low: \(low)")
      
      // 当进度到达 100% 或出现错误状态时自动停止（与 Android 一致）
      if progress >= 100 || state == .deviceBusy || state == .testFail || state == .testInterrupt || state == .noFunction {
        // 停止血压测量
        peripheralManage.veepooSDKTestBloodStart(false, testMode: 0) { _, _, _, _ in }
        
        let statusStr: String
        switch state {
        case .deviceBusy: statusStr = "deviceBusy"
        case .testFail: statusStr = "testFail"
        case .testInterrupt: statusStr = "testInterrupt"
        case .noFunction: statusStr = "noFunction"
        case .complete: statusStr = "over"
        default: statusStr = "over"  // progress >= 100 时状态为 "over"
        }
        
        self.sendEvent(BLOOD_PRESSURE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": statusStr,
            "systolic": high,
            "diastolic": low,
            "progress": 100,
            "isEnd": true
          ]
        ])
        return
      }
      
      // 测量过程中的事件
      let statusStr: String
      switch state {
      case .testing: statusStr = "testing"
      case .complete: statusStr = "over"
      default: statusStr = "testing"
      }
      
      self.sendEvent(BLOOD_PRESSURE_TEST_RESULT, [
        "deviceId": self.connectedDeviceId ?? "",
        "result": [
          "state": statusStr,
          "systolic": high,
          "diastolic": low,
          "progress": progress,
          "isEnd": false
        ]
      ])
    }
    
    promise.resolve(nil)
    #endif
  }
  
  // MARK: 开始血氧测试
  func handleStartBloodOxygenTest(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let peripheralManage = self.peripheralManage else {
      promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
      return
    }
    
    // 检查设备是否支持血氧功能
    if let manager = self.bleManager {
      let oxygenType = manager.peripheralModel?.oxygenType ?? 0
      print("[BloodOxygen] Starting test - Device oxygenType: \(oxygenType)")
      if oxygenType == 0 {
        print("[BloodOxygen] Warning: Device may not support blood oxygen function")
      }
    }

    let progressWrapper = ProgressWrapper()
    let spo2ValueWrapper = ValueWrapper<Int>(value: 0)
    let rateValueWrapper = ValueWrapper<Int>(value: 0)
    var progressTimer: Timer?

    // 启动模拟进度定时器（与 Android 一致：每秒增加 4%，25 秒完成）
    // 使用主线程创建 Timer，确保 RunLoop 正确
    DispatchQueue.main.async {
      progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
        progressWrapper.value += 4
        if progressWrapper.value >= 100 {
          timer.invalidate()
          return
        }

        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "testing",
            "value": spo2ValueWrapper.value,
            "rate": rateValueWrapper.value,
            "progress": progressWrapper.value
          ]
        ])
      }
    }

    peripheralManage.veepooSDKTestOxygenStart(true) { state, value in
      // 与 Android 一致：设备回调只更新数值，不发送事件
      // 进度和事件由 Timer 独立更新
      print("[BloodOxygen] SDK callback - state: \(state.rawValue), value: \(value)")
      
      switch state {
      case .start:
        print("[BloodOxygen] Test started")
        
      case .calibration:
        // 校准阶段：value 表示校准进度（0-100）
        print("[BloodOxygen] Calibrating - progress: \(value)")
        // 可以选择发送校准进度到前端
        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "calibration",
            "value": 0,
            "rate": 0,
            "progress": Int(value),
            "isEnd": false
          ]
        ])
        
      case .calibrationComplete:
        print("[BloodOxygen] Calibration complete")
        
      case .testing:
        // 测试阶段：value 表示血氧值
        spo2ValueWrapper.value = Int(value)
        print("[BloodOxygen] Testing - SpO2: \(value)")
        
      case .notWear:
        print("[BloodOxygen] Device not worn")
        progressTimer?.invalidate()
        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "notWear",
            "value": Int(value),
            "rate": rateValueWrapper.value,
            "progress": progressWrapper.value,
            "isEnd": true
          ]
        ])
      case .deviceBusy:
        print("[BloodOxygen] Device is busy")
        progressTimer?.invalidate()
        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "deviceBusy",
            "value": Int(value),
            "rate": rateValueWrapper.value,
            "progress": progressWrapper.value,
            "isEnd": true
          ]
        ])
      case .over:
        print("[BloodOxygen] Test completed - SpO2: \(value)")
        progressTimer?.invalidate()
        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "over",
            "value": Int(value),
            "rate": rateValueWrapper.value,
            "progress": 100,
            "isEnd": true
          ]
        ])
      case .noFunction:
        print("[BloodOxygen] Device does not support blood oxygen function")
        progressTimer?.invalidate()
        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "noFunction",
            "value": Int(value),
            "rate": rateValueWrapper.value,
            "progress": progressWrapper.value,
            "isEnd": true
          ]
        ])
      case .invalid:
        print("[BloodOxygen] Invalid state received")
        progressTimer?.invalidate()
        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": "invalid",
            "value": Int(value),
            "rate": rateValueWrapper.value,
            "progress": progressWrapper.value,
            "isEnd": true
          ]
        ])
      default:
        // 其他状态不处理，由 Timer 持续更新进度
        print("[BloodOxygen] Unknown state: \(state.rawValue)")
        break
      }
    }

    promise.resolve(nil)
    #endif
  }
  
  // MARK: 开始体温测试
  func handleStartTemperatureTest(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let peripheralManage = self.peripheralManage else {
      promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
      return
    }
    
    // 检查设备是否支持体温功能
    if let manager = self.bleManager {
      let tempType = manager.peripheralModel?.temperatureType ?? 0
      print("[Temperature] Starting test - Device temperatureType: \(tempType)")
    }
    
    peripheralManage.veepooSDK_temperatureTestStart(true) { state, enable, progress, tempValue, originalTempValue in
      print("[Temperature] SDK callback - state: \(state.rawValue), progress: \(progress), temp: \(tempValue)")
      var statusStr = "unknown"
      var isEnd = false
      
      switch state {
      case .unsupported: statusStr = "unsupported"; isEnd = true
      case .open: statusStr = "testing"
      case .close: statusStr = "over"; isEnd = true
      @unknown default: statusStr = "testing"
      }
      
      var result: [String: Any] = [
        "state": statusStr,
        "value": tempValue > 0 ? Double(tempValue) / 10.0 : nil,
        "progress": progress,
        "isEnd": isEnd
      ]
      
      if tempValue > 0 {
        result["originalTemp"] = Double(originalTempValue) / 10.0
      }
      result["enable"] = enable
      
      self.sendEvent(TEMPERATURE_TEST_RESULT, [
        "deviceId": self.connectedDeviceId ?? "",
        "result": result
      ])
    }
    
    promise.resolve(nil)
    #endif
  }
  
  // MARK: 开始压力测试
  func handleStartStressTest(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let peripheralManage = self.peripheralManage else {
      promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
      return
    }
    
    // 检查设备是否支持压力功能
    if let manager = self.bleManager {
      let stressType = manager.peripheralModel?.stressType ?? 0
      print("[Stress] Starting test - Device stressType: \(stressType)")
    }
    
    peripheralManage.veepooSDK_stressTestStart(true) { state, progress, stress in
      print("[Stress] SDK callback - state: \(state.rawValue), progress: \(progress), stress: \(stress)")
      var statusStr = "unknown"
      var isEnd = false
      
      switch state {
      case .noFunction: statusStr = "unsupported"; isEnd = true
      case .deviceBusy: statusStr = "deviceBusy"; isEnd = true
      case .over: statusStr = "over"; isEnd = true
      case .lowPower: statusStr = "lowPower"; isEnd = true
      case .notWear: statusStr = "notWear"; isEnd = true
      case .complete: statusStr = "complete"; isEnd = true
      @unknown default: statusStr = "testing"
      }
      
      self.sendEvent(STRESS_DATA, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": [
          "stress": stress,
          "progress": progress,
          "status": statusStr,
          "isEnd": isEnd
        ]
      ])
    }
    
    promise.resolve(nil)
    #endif
  }
  
  // MARK: 开始血糖测试
  func handleStartBloodGlucoseTest(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let peripheralManage = self.peripheralManage else {
      promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
      return
    }
    
    // 检查设备是否支持血糖功能
    if let manager = self.bleManager {
      let bgType = manager.peripheralModel?.bloodGlucoseType ?? 0
      print("[BloodGlucose] Starting test - Device bloodGlucoseType: \(bgType)")
    }
    
    peripheralManage.veepooSDKTestBloodGlucoseStart(true, isPersonalModel: false) { [weak self] state, progress, value, level in
      guard let self = self else { return }
      
      print("[BloodGlucose] SDK callback - state: \(state.rawValue), progress: \(progress), value: \(value), level: \(level)")
      
      // 当进度到达 100% 或出现错误状态时自动停止（与血压测试一致）
      if progress >= 100 || state == .deviceBusy || state == .lowPower || state == .notWear || state == .unsupported {
        // 停止血糖测量
        peripheralManage.veepooSDKTestBloodGlucoseStart(false, isPersonalModel: false) { _, _, _, _ in }
        
        let statusStr: String
        var finalValue = Double(value) / 100.0
        
        switch state {
        case .deviceBusy: statusStr = "deviceBusy"
        case .lowPower: statusStr = "lowPower"
        case .notWear: statusStr = "notWear"
        case .unsupported: statusStr = "unsupported"
        case .close: statusStr = "over"
        default: statusStr = "over"  // progress >= 100 时状态为 "over"
        }
        
        // 如果是完成状态，确保血糖值有效
        if statusStr == "over" && finalValue <= 0 {
          // 如果最终值为0，可能需要从前面的回调中获取，这里先保持0
          print("[BloodGlucose] Warning: Final glucose value is 0")
        }
        
        self.sendEvent(BLOOD_GLUCOSE_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": [
            "glucose": finalValue,
            "progress": 100,
            "level": level,
            "state": statusStr,
            "status": statusStr,
            "isEnd": true
          ]
        ])
        return
      }
      
      // 测量过程中的事件
      let statusStr: String
      switch state {
      case .open: statusStr = "testing"
      case .close: statusStr = "over"
      default: statusStr = "testing"
      }
      
      let finalValue = Double(value) / 100.0
      
      self.sendEvent(BLOOD_GLUCOSE_DATA, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": [
          "glucose": finalValue,
          "progress": progress,
          "level": level,
          "state": statusStr,
          "status": statusStr,
          "isEnd": false
        ]
      ])
    }
    
    promise.resolve(nil)
    #endif
  }
}
