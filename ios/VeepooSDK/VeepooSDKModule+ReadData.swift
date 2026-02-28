import ExpoModulesCore
import VeepooBleSDK

/// 读取与同步数据接口
extension VeepooSDKModule {
  func defineReadData() {
    AsyncFunction("readBattery") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([
        "level": 88,
        "percent": 88,
        "powerModel": 0,
        "state": 1,
        "bat": 0,
        "isPercent": true,
        "isLowBattery": false
      ])
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      var hasResolved = false

      peripheralManage.veepooSDKReadDeviceBatteryAndChargeInfo { isPercent, chargeState, percenTypeIsLowBat, battery in
        if hasResolved { return }
        hasResolved = true

        promise.resolve([
          "level": battery,
          "percent": isPercent ? battery : 0,
          "powerModel": 0,
          "state": chargeState.rawValue,
          "bat": 0,
          "isPercent": isPercent,
          "isLowBattery": percenTypeIsLowBat
        ])
      }
      #endif
    }

    AsyncFunction("syncPersonalInfo") { (info: [String: Any], promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(true)
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      let pInfo = VPSyncPersonalInfo()
      pInfo.sex = Int32(info["sex"] as? Int ?? 1)
      pInfo.status = Int32((info["height"] as? Int ?? 170))
      pInfo.weight = Int32(info["weight"] as? Int ?? 65)
      pInfo.age = Int32(info["age"] as? Int ?? 25)
      pInfo.targetStep = Int32(info["stepAim"] as? Int ?? 8000)
      pInfo.targetSleepDuration = Int32(info["sleepAim"] as? Int ?? 480)

      peripheralManage.veepooSDKSynchronousPersonalInformation(pInfo) { result in
        if result == 1 {
          promise.resolve(true)
        } else {
          promise.reject("SYNC_FAILED", "Sync personal info failed")
        }
      }
      #endif
    }

    AsyncFunction("readDeviceFunctions") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([
        "package1": [
          "type": "DeviceFunctionPackage1",
          "bloodPressure": "unsupported",
          "heartRateDetect": "support"
        ]
      ])
      #else
      if self.cachedDeviceFunctions.isEmpty {
        self.cacheDeviceFunctions()
      }
      promise.resolve(self.cachedDeviceFunctions)
      #endif
    }

    AsyncFunction("readSocialMsgData") { (promise: Promise) in
      promise.resolve([:])
    }

    AsyncFunction("readDeviceVersion") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([
        "hardwareVersion": "1.0.0-SIMULATOR",
        "firmwareVersion": "2.0.0-SIMULATOR",
        "softwareVersion": "3.0.0-SIMULATOR",
        "deviceNumber": "SIM001",
        "newVersion": "",
        "description": "Simulator Mode"
      ])
      #else
      guard let manager = self.bleManager,
            let model = manager.peripheralModel else {
        promise.reject("DEVICE_NOT_CONNECTED", "No device connected or model unavailable")
        return
      }
      
      let hardwareVersion = model.deviceVersion ?? "unknown"
      let firmwareVersion = ""
      let softwareVersion = ""
      let deviceNumber = String(model.deviceNumber)
      let newVersion = model.deviceNetVersion ?? ""
      let des = model.deviceNetVersionDes ?? ""
      
      let result: [String: Any] = [
        "hardwareVersion": hardwareVersion,
        "firmwareVersion": firmwareVersion,
        "softwareVersion": softwareVersion,
        "deviceNumber": deviceNumber,
        "newVersion": newVersion,
        "description": des
      ]
      
      self.sendEvent(DEVICE_VERSION, [
        "deviceId": self.connectedDeviceId ?? "",
        "version": result
      ])
      
      promise.resolve(result)
      #endif
    }

    AsyncFunction("startReadOriginData") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
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
      
      // 读取5分钟原始数据
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
            "spo2Value": data["spo2Value"] ?? 0,
            "tempValue": data["tempValue"] ?? 0,
            "stressValue": data["stress"] ?? data["stressValue"] ?? 0,
            "met": data["met"] ?? 0
          ]
          
          if let ppgs = data["ppgs"] as? [Int] {
            item["ppgs"] = ppgs
          }
          if let ecgs = data["ecgs"] as? [Int] {
            item["ecgs"] = ecgs
          }
          if let oxygens = data["oxygens"] as? [Int] {
            item["oxygens"] = oxygens
          }
          if let bloodGlucose = data["bloodGlucose"] as? Int {
            item["bloodGlucose"] = bloodGlucose
          }
          
          // 发送5分钟数据事件
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
      
      // 读取30分钟数据
      if let halfHourResult = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: String]] {
        for (time, item) in halfHourResult {
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

    AsyncFunction("readSleepData") { (date: String?, promise: Promise) in
      #if targetEnvironment(simulator)
      let simulatorResult: [String: Any] = [
        "date": date ?? self.getDateString(dayOffset: 0),
        "items": [
          [
            "date": "2024-01-01",
            "sleepTime": "22:30:00",
            "wakeTime": "07:00:00",
            "deepSleepMinutes": 90,
            "lightSleepMinutes": 330,
            "totalSleepMinutes": 480,
            "sleepQuality": 85,
            "sleepLine": "",
            "wakeUpCount": 2
          ]
        ],
        "summary": [
          "totalDeepSleepMinutes": 90,
          "totalLightSleepMinutes": 330,
          "totalSleepMinutes": 480,
          "averageSleepQuality": 85,
          "totalWakeUpCount": 2
        ]
      ]
      promise.resolve(simulatorResult)
      #else
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
       
       promise.resolve(result)
       #endif
     }

    AsyncFunction("readSportStepData") { (date: String?, promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([
        "date": "2024-01-01",
        "stepCount": 5000,
        "distance": 3500,
        "calories": 200.0
      ])
      #else
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

    AsyncFunction("readOriginData") { (dayOffset: Int, promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([])
      #else
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
            "spo2Value": data["spo2Value"] ?? 0,
            "tempValue": data["tempValue"] ?? 0,
            "stressValue": data["stress"] ?? data["stressValue"] ?? 0,
            "met": data["met"] ?? 0
          ]
          
          if let ppgs = data["ppgs"] as? [Int] {
            item["ppgs"] = ppgs
          }
          if let ecgs = data["ecgs"] as? [Int] {
            item["ecgs"] = ecgs
          }
          if let oxygens = data["oxygens"] as? [Int] {
            item["oxygens"] = oxygens
          }
          if let bloodGlucose = data["bloodGlucose"] as? Int {
            item["bloodGlucose"] = bloodGlucose
          }
          
          resultList.append(item)
        }
      }
      
      let sortedResult = resultList.sorted { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
      promise.resolve(sortedResult)
      #endif
    }

    AsyncFunction("readDeviceAllData") { (promise: Promise) in
      #if targetEnvironment(simulator)
      self.sendEvent(READ_ORIGIN_PROGRESS, [
        "deviceId": self.connectedDeviceId ?? "",
        "progress": [
          "readState": "start" as NSString,
          "totalDays": 1,
          "currentDay": 1,
          "progress": 0.0
        ]
      ])
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.sendEvent(READ_ORIGIN_PROGRESS, [
          "deviceId": self.connectedDeviceId ?? "",
          "progress": [
            "readState": "complete" as NSString,
            "totalDays": 1,
            "currentDay": 1,
            "progress": 1.0
          ]
        ])
        
        self.sendEvent(READ_ORIGIN_COMPLETE, [
          "deviceId": self.connectedDeviceId ?? "",
          "success": true
        ])
        
        promise.resolve(true)
      }
      #else
      self.handleReadDeviceAllData(promise: promise)
      #endif
    }
  }
}
