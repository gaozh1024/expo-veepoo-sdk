import ExpoModulesCore
import VeepooBleSDK

/// 读取数据辅助方法
extension VeepooSDKModule {
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
      // 按时间排序后遍历，确保数据按时间顺序发送
      for (time, item) in halfHourResult.sorted(by: { $0.key < $1.key }) {
        var dataItem: [String: Any] = ["time": time]

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

        // sportValue 和 met（从数据源读取）
        if let sportStr = item["sportValue"], let sport = Double(sportStr) {
          dataItem["sportValue"] = Int(sport)
        }
        if let metStr = item["met"], let met = Double(metStr) {
          dataItem["met"] = met
        }

        // 血压字段（兼容两种 key 名）
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

        // SpO2 字段（优先从 item，其次从 oxygenMap）
        if let spo2Str = item["spo2Value"], let spo2 = Int(spo2Str), spo2 > 0 {
          dataItem["spo2Value"] = spo2
        } else if let oxyData = oxygenMap[time] {
          let oxygenValue = self.getInt(oxyData["OxygenValue"])
          if oxygenValue > 0 {
            dataItem["spo2Value"] = oxygenValue
          }
        }

        // 血糖字段（优先从 item，其次从 bloodGlucoseMap）
        if let bgStr = item["bloodGlucose"], let bg = Int(bgStr), bg > 0 {
          dataItem["bloodGlucose"] = bg
          dataItem["glucose"] = Double(bg)
        } else if let bgData = bloodGlucoseMap[time] {
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

        // 压力字段（兼容两种 key 名）
        if let stressStr = item["stress"], let stress = Int(stressStr), stress > 0 {
          dataItem["stressValue"] = stress
        } else if let stressStr = item["pressure"], let stress = Int(stressStr), stress > 0 {
          dataItem["stressValue"] = stress
        }

        // 体温字段
        if let tempStr = item["tempValue"], let temp = Double(tempStr), temp > 0 {
          dataItem["tempValue"] = temp
        }

        self.sendEvent(ORIGIN_HALF_HOUR_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": dataItem
        ])
      }
    }
    #endif
  }
  
  func emitFiveMinuteData(dayOffset: Int) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else { return }
    
    let dateStr = self.getDateString(dayOffset: dayOffset)
    
    // 加载氧气数据映射
    var oxygenMap: [String: [String: Any]] = [:]
    if let oxygenArray = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
      for item in oxygenArray {
        if let time = item["Time"] as? String {
          oxygenMap[time] = item
        }
      }
    }
    
    // 加载血糖数据映射
    var bloodGlucoseMap: [String: [String: Any]] = [:]
    if let bloodGlucoseArray = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
      for item in bloodGlucoseArray {
        if let time = item["time"] as? String {
          bloodGlucoseMap[time] = item
        }
      }
    }
    
    // 读取5分钟粒度的原始数据
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
        
        // 合并氧气数据
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
        
        // 处理数组类型的原始数据
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
          self.emitFiveMinuteData(dayOffset: i)
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
  
  // 解析社交消息数据
  func parseSocialMsgData(_ ancsData: Data) -> [String: String] {
    // 默认全部不支持
    var result: [String: String] = [
      "phone": "unsupported",
      "sms": "unsupported",
      "wechat": "unsupported",
      "qq": "unsupported",
      "facebook": "unsupported",
      "twitter": "unsupported",
      "instagram": "unsupported",
      "linkedin": "unsupported",
      "whatsapp": "unsupported",
      "line": "unsupported",
      "skype": "unsupported",
      "email": "unsupported",
      "other": "unsupported"
    ]
    
    guard ancsData.count >= 20 else { return result }
    
    // ANCS 数据格式: 从下标2开始依次代表各种功能
    // 0: 没有此功能, 1: 开启提醒, 2: 关闭提醒
    let bytes = [UInt8](ancsData)
    
    // 辅助函数: 将字节值转换为 FunctionStatus
    func statusFromByte(_ byte: UInt8) -> String {
      switch byte {
      case 1: return "open"
      case 2: return "close"
      default: return "unsupported"
      }
    }
    
    // 下标对应关系 (根据 Veepoo SDK 文档)
    // 2: 来电, 3: 短信, 4: wechat, 5: QQ, 6: Sina, 7: Facebook, 8: X(Twitter)
    // 9: Flickr, 10: LinkedIn, 11: WhatsApp, 12: Line, 13: Instagram
    // 14: Snapchat, 15: Skype, 16: 钉钉, 17: 企业微信
    // 19: 其他应用
    if bytes.count > 2 { result["phone"] = statusFromByte(bytes[2]) }
    if bytes.count > 3 { result["sms"] = statusFromByte(bytes[3]) }
    if bytes.count > 4 { result["wechat"] = statusFromByte(bytes[4]) }
    if bytes.count > 5 { result["qq"] = statusFromByte(bytes[5]) }
    if bytes.count > 7 { result["facebook"] = statusFromByte(bytes[7]) }
    if bytes.count > 8 { result["twitter"] = statusFromByte(bytes[8]) }
    if bytes.count > 13 { result["instagram"] = statusFromByte(bytes[13]) }
    if bytes.count > 10 { result["linkedin"] = statusFromByte(bytes[10]) }
    if bytes.count > 11 { result["whatsapp"] = statusFromByte(bytes[11]) }
    if bytes.count > 12 { result["line"] = statusFromByte(bytes[12]) }
    if bytes.count > 15 { result["skype"] = statusFromByte(bytes[15]) }
    if bytes.count > 3 { result["email"] = statusFromByte(bytes[3]) } // 使用短信设置
    if bytes.count > 19 { result["other"] = statusFromByte(bytes[19] & 0x0F) } // 低4位
    
    return result
  }
  
  // 标准化密码状态值，与 Android 保持一致
  func normalizePasswordStatus(_ status: String?) -> String {
    guard let status = status else { return "UNKNOWN" }
    let upperStatus = status.uppercased()
    
    switch upperStatus {
    case "SUCCESS", "1":
      return "SUCCESS"
    case "FAILED", "FAIL", "0":
      return "FAILED"
    case "CHECK_SUCCESS":
      return "CHECK_SUCCESS"
    case "CHECK_FAIL":
      return "CHECK_FAIL"
    case "NOT_SET":
      return "NOT_SET"
    default:
      return "UNKNOWN"
    }
  }
}
