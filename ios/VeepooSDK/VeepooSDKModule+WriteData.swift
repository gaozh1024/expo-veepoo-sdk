import ExpoModulesCore
import VeepooBleSDK

private let LANGUAGE_MAP: [String: UInt8] = [
  "chinese": 1,
  "english": 2,
  "japanese": 3,
  "korean": 4,
  "german": 5,
  "russian": 6,
  "spanish": 7,
  "italian": 8,
  "french": 9,
  "vietnamese": 10,
  "portuguese": 11,
  "chineseTraditional": 12,
  "thai": 13,
  "polish": 14,
  "swedish": 15,
  "turkish": 16,
  "dutch": 17,
  "czech": 18,
  "arabic": 19,
  "hungarian": 20,
  "greek": 21,
  "romanian": 22,
  "slovak": 23,
  "indonesian": 24,
  "brazilianPortuguese": 25,
  "croatian": 26,
  "lithuanian": 27,
  "ukrainian": 28,
  "hindi": 29,
  "hebrew": 30,
  "danish": 31,
  "persian": 32,
  "finnish": 33,
  "malay": 34
]

private func autoMeasureModelToMap(_ model: VPAutoMonitTestModel) -> [String: Any] {
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

extension VeepooSDKModule {
  func defineWriteData() {
    AsyncFunction("readAutoMeasureSetting") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([])
      #else
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
        
        let result = list.map { autoMeasureModelToMap($0) }
        promise.resolve(result)
      }
      #endif
    }

    AsyncFunction("modifyAutoMeasureSetting") { (setting: [String: Any], promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([])
      #else
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
          
          let result = finalList.map { autoMeasureModelToMap($0) }
          promise.resolve(result)
        }
      }
      #endif
    }

    AsyncFunction("setLanguage") { (language: String, promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(true)
      #else
      guard self.isInitialized else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }
      
      guard let manager = self.bleManager,
            let peripheralManage = manager.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "No device connected")
        return
      }
      
      guard let languageType = LANGUAGE_MAP[language] else {
        promise.reject("INVALID_LANGUAGE", "Unknown language: \(language)")
        return
      }
      
      peripheralManage.veepooSDKSettingLanguage(languageType) { success in
        if success {
          promise.resolve(true)
        } else {
          promise.reject("SET_LANGUAGE_FAILED", "Failed to set language")
        }
      }
      #endif
    }
  }
}
