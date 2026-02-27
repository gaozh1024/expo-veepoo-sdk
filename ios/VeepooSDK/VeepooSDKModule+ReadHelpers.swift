import ExpoModulesCore
import VeepooBleSDK

/// 读取数据辅助方法
extension VeepooSDKModule {
  func emitHalfHourData(dayOffset: Int) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else { return }
    
    let dateStr = self.getDateString(dayOffset: dayOffset)
    
    if let halfHourResult = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: String]] {
      for (time, item) in halfHourResult {
        var dataItem: [String: Any] = [
          "time": time,
          "sportValue": 0,
          "systolic": 0,
          "diastolic": 0,
          "spo2Value": 0,
          "tempValue": 0,
          "stressValue": 0
        ]
        
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
        
        self.sendEvent(ORIGIN_HALF_HOUR_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": dataItem
        ])
      }
    }
    #endif
  }
  
  func handleReadDeviceAllData(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let _ = manager.peripheralModel?.deviceAddress else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected")
      return
    }
    
    self.sendEvent(READ_ORIGIN_PROGRESS, [
      "deviceId": self.connectedDeviceId ?? "",
      "progress": [
        "readState": "start" as NSString,
        "totalDays": 1,
        "currentDay": 1,
        "progress": 0.0
      ]
    ])
    
    manager.peripheralManage.veepooSdkStartReadDeviceAllData { [weak self] readState, totalDay, currentReadDayNumber, readCurrentDayProgress in
      guard let self = self else { return }
      
      switch readState {
      case .reading:
        let progress = Double(currentReadDayNumber) + Double(readCurrentDayProgress) / 100.0
        let overallProgress = totalDay > 0 ? progress / Double(totalDay) : 0.0
        
        self.sendEvent(READ_ORIGIN_PROGRESS, [
          "deviceId": self.connectedDeviceId ?? "",
          "progress": [
            "readState": "reading" as NSString,
            "totalDays": totalDay,
            "currentDay": currentReadDayNumber,
            "progress": overallProgress
          ]
        ])
        
      case .complete:
        self.sendEvent(READ_ORIGIN_PROGRESS, [
          "deviceId": self.connectedDeviceId ?? "",
          "progress": [
            "readState": "complete" as NSString,
            "totalDays": totalDay,
            "currentDay": totalDay,
            "progress": 1.0
          ]
        ])
        
        let days = max(Int(totalDay), 1)
        for i in 0..<days {
          self.emitHalfHourData(dayOffset: i)
        }
        
        self.sendEvent(READ_ORIGIN_COMPLETE, [
          "deviceId": self.connectedDeviceId ?? "",
          "success": true
        ])
        
        promise.resolve(true)
        
      case .invalid:
        self.sendEvent(READ_ORIGIN_PROGRESS, [
          "deviceId": self.connectedDeviceId ?? "",
          "progress": [
            "readState": "invalid" as NSString,
            "totalDays": 1,
            "currentDay": 1,
            "progress": 0.0
          ]
        ])
        
        promise.reject("READ_FAILED", "Read device data failed")
        
      default:
        break
      }
    }
    #endif
  }

  func cacheDeviceFunctions() {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let device = manager.peripheralModel else {
      return
    }
    
    let package1: [String: Any] = [
      "type": "DeviceFunctionPackage1",
      "bloodPressure": device.bloodPressureType > 0 ? "support" : "unsupported",
      "heartRateDetect": device.deviceFuctionData[18] == 0 ? "support" : "unsupported",
      "spoH": device.oxygenType > 0 ? "support" : "unsupported",
      "temperatureFunction": device.temperatureType > 0 ? "support" : "unsupported"
    ]
    
    let package2: [String: Any] = [
      "type": "DeviceFunctionPackage2",
      "ecgFunction": device.ecgType > 0 ? "support" : "unsupported",
      "precisionSleep": device.sleepType > 0 ? "support" : "unsupported",
      "hrvFunction": device.hrvType > 0 ? "support" : "unsupported"
    ]
    
    let package3: [String: Any] = [
      "type": "DeviceFunctionPackage3",
      "stressFunction": device.stressType > 1 ? "support" : "unsupported",
      "bloodGlucose": device.bloodGlucoseType > 0 ? "support" : "unsupported",
      "bloodComponent": device.bloodAnalysisType > 0 ? "support" : "unsupported",
      "bodyComponent": device.bodyCompositionType > 0 ? "support" : "unsupported"
    ]
    
    cachedDeviceFunctions = [
      "package1": package1,
      "package2": package2,
      "package3": package3
    ]
    
    self.sendEvent(DEVICE_FUNCTION, [
      "deviceId": self.connectedDeviceId ?? "",
      "data": cachedDeviceFunctions,
      "functions": cachedDeviceFunctions
    ])
    #endif
  }

  func getDateString(dayOffset: Int) -> String {
    let calendar = Calendar.current
    let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  func formatOrdinarySleep(_ items: [[String: Any]]) -> [[String: Any]] {
    var result: [[String: Any]] = []
    
    for item in items {
      let sleepTime = item["SLEEP_TIME"] as? String ?? ""
      let wakeTime = item["WAKE_TIME"] as? String ?? ""
      let line = item["SLE_LINE"] as? String ?? ""
      
      let deepHourStr = item["DEEP_HOUR"] as? String ?? "0"
      let lightHourStr = item["LIGHT_HOUR"] as? String ?? "0"
      let wakeUpTimeStr = item["WakeUpTime"] as? String ?? "0"
      let sleHourStr = item["SLE_HOUR"] as? String ?? "0"
      let sleMinuteStr = item["SLE_MINUTE"] as? String ?? "0"
      
      let allSleepMinutes = (Double(sleHourStr) ?? 0) * 60 + (Double(sleMinuteStr) ?? 0)
      let deepSleepMinutes = (Double(deepHourStr) ?? 0) * 60
      let lightSleepMinutes = (Double(lightHourStr) ?? 0) * 60
      
      var dict: [String: Any] = [:]
      dict["date"] = String(wakeTime.prefix(10))
      dict["sleepTime"] = sleepTime
      dict["wakeTime"] = wakeTime
      dict["deepSleepDuration"] = deepSleepMinutes / 60.0
      dict["lightSleepDuration"] = lightSleepMinutes / 60.0
      dict["totalSleepHours"] = Int(allSleepMinutes / 60)
      dict["totalSleepMinutes"] = Int(allSleepMinutes.truncatingRemainder(dividingBy: 60))
      dict["sleepLevel"] = (item["SLEEP_LEVEL"] as? NSNumber)?.intValue ?? 0
      dict["sleepLine"] = line
      dict["wakeUpCount"] = Int(Double(wakeUpTimeStr) ?? 0)
      
      result.append(dict)
    }
    
    return result
  }

  func formatOrdinarySleepToNewFormat(_ items: [[String: Any]]) -> [[String: Any]] {
    var result: [[String: Any]] = []
    
    for item in items {
      let sleepTime = item["SLEEP_TIME"] as? String ?? ""
      let wakeTime = item["WAKE_TIME"] as? String ?? ""
      let line = item["SLE_LINE"] as? String ?? ""
      
      let deepHourStr = item["DEEP_HOUR"] as? String ?? "0"
      let lightHourStr = item["LIGHT_HOUR"] as? String ?? "0"
      let wakeUpTimeStr = item["WakeUpTime"] as? String ?? "0"
      let sleHourStr = item["SLE_HOUR"] as? String ?? "0"
      let sleMinuteStr = item["SLE_MINUTE"] as? String ?? "0"
      
      let allSleepMinutes = Int((Double(sleHourStr) ?? 0) * 60 + (Double(sleMinuteStr) ?? 0))
      let deepSleepMinutes = Int((Double(deepHourStr) ?? 0) * 60)
      let lightSleepMinutes = Int((Double(lightHourStr) ?? 0) * 60)
      let sleepQuality = (item["SLEEP_LEVEL"] as? NSNumber)?.intValue ?? 0
      let wakeUpCount = Int(Double(wakeUpTimeStr) ?? 0)
      
      let dict: [String: Any] = [
        "date": String(wakeTime.prefix(10)),
        "sleepTime": sleepTime,
        "wakeTime": wakeTime,
        "deepSleepMinutes": deepSleepMinutes,
        "lightSleepMinutes": lightSleepMinutes,
        "totalSleepMinutes": allSleepMinutes,
        "sleepQuality": sleepQuality,
        "sleepLine": line,
        "wakeUpCount": wakeUpCount
      ]
      
      result.append(dict)
    }
    
    return result
  }

  func getInt(_ value: Any?) -> Int {
    if let num = value as? NSNumber {
      return num.intValue
    } else if let str = value as? String {
      return Int(str) ?? 0
    } else if let int = value as? Int {
      return int
    }
    return 0
  }

  func getDouble(_ value: Any?) -> Double {
    if let num = value as? NSNumber {
      return num.doubleValue
    } else if let str = value as? String {
      return Double(str) ?? 0.0
    } else if let d = value as? Double {
      return d
    }
    return 0.0
  }
}
