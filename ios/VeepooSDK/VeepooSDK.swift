import ExpoModulesCore
import CoreBluetooth
import VeepooBleSDK

let DEVICE_FOUND = "deviceFound"
let DEVICE_CONNECTED = "deviceConnected"
let DEVICE_DISCONNECTED = "deviceDisconnected"
let DEVICE_CONNECT_STATUS = "deviceConnectStatus"
let DEVICE_READY = "deviceReady"
let BLUETOOTH_STATE_CHANGED = "bluetoothStateChanged"
let DEVICE_FUNCTION = "deviceFunction"
let DEVICE_VERSION = "deviceVersion"
let PASSWORD_DATA = "passwordData"
let HEART_RATE_TEST_RESULT = "heartRateTestResult"
let BLOOD_PRESSURE_TEST_RESULT = "bloodPressureTestResult"
let BLOOD_OXYGEN_TEST_RESULT = "bloodOxygenTestResult"
let TEMPERATURE_TEST_RESULT = "temperatureTestResult"
let STRESS_DATA = "stressData"
let BLOOD_GLUCOSE_DATA = "bloodGlucoseData"
let BATTERY_DATA = "batteryData"
let READ_ORIGIN_PROGRESS = "readOriginProgress"
let READ_ORIGIN_COMPLETE = "readOriginComplete"
let ORIGIN_HALF_HOUR_DATA = "originHalfHourData"
let SLEEP_DATA = "sleepData"
let SPORT_STEP_DATA = "sportStepData"
let ERROR = "error"

public class VeepooSDKModule: Module {
  private var bleManager: VPBleCentralManage?
  private var peripheralManage: VPPeripheralManage?
  private var isScanning = false
  private var connectedDeviceId: String?
  private var isInitialized = false
  private var centralManager: CBCentralManager?
  private var pendingScanStart = false
  private var discoveredDevices: [String: VPPeripheralModel] = [:]
  
  private var pendingConnectDeviceId: String?
  private var pendingConnectPassword: String?
  private var pendingConnectIs24Hour: Bool = false
  private var pendingConnectPromise: Promise?
  
  private var cachedDeviceFunctions: [String: Any] = [:]

  public func definition() -> ModuleDefinition {
    Name("VeepooSDK")

    Events(
      DEVICE_FOUND,
      DEVICE_CONNECTED,
      DEVICE_DISCONNECTED,
      DEVICE_CONNECT_STATUS,
      DEVICE_READY,
      BLUETOOTH_STATE_CHANGED,
      DEVICE_FUNCTION,
      DEVICE_VERSION,
      PASSWORD_DATA,
      HEART_RATE_TEST_RESULT,
      BLOOD_PRESSURE_TEST_RESULT,
      BLOOD_OXYGEN_TEST_RESULT,
      TEMPERATURE_TEST_RESULT,
      STRESS_DATA,
      BLOOD_GLUCOSE_DATA,
      BATTERY_DATA,
      READ_ORIGIN_PROGRESS,
      READ_ORIGIN_COMPLETE,
      ORIGIN_HALF_HOUR_DATA,
      SLEEP_DATA,
      SPORT_STEP_DATA,
      ERROR
    )

    AsyncFunction("init") { (promise: Promise) in
      DispatchQueue.main.async {
        #if targetEnvironment(simulator)
        self.isInitialized = true
        promise.resolve(nil)
        #else
        guard let manager = VPBleCentralManage.sharedBleManager() else {
          promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Veepoo SDK")
          return
        }

        self.bleManager = manager
        self.peripheralManage = VPPeripheralManage.shareVPPeripheralManager()
        manager.peripheralManage = self.peripheralManage
        manager.isLogEnable = true
        manager.manufacturerIDFilter = false

        self.setupVeepooCallbacks()
        self.isInitialized = true

        self.ensureCentralManager()
        promise.resolve(nil)
        #endif
      }
    }

    AsyncFunction("isBluetoothEnabled") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(true)
      #else
      self.ensureCentralManager()
      guard let central = self.centralManager else {
        promise.reject("SDK_NOT_INITIALIZED", "Central manager not initialized")
        return
      }
      let isEnabled = central.state == .poweredOn
      promise.resolve(isEnabled)
      #endif
    }

    AsyncFunction("requestPermissions") { (promise: Promise) in
      let authorization = CBManager.authorization
      switch authorization {
      case .allowedAlways, .notDetermined:
        promise.resolve(true)
      default:
        promise.resolve(false)
      }
    }

    AsyncFunction("startScan") { (options: [String: Any]?, promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard self.isInitialized else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      self.pendingScanStart = true

      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
        return
      }

      if self.isScanning {
        promise.resolve(nil)
        return
      }

      self.isScanning = true

      manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { peripheralModel in
        guard let model = peripheralModel else { return }
        self.handleDiscoveredDevice(model)
      }

      promise.resolve(nil)
      #endif
    }

    AsyncFunction("stopScan") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.pendingScanStart = false
      self.isScanning = false
      self.bleManager?.veepooSDKStopScanDevice()
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("connect") { (deviceId: String, options: [String: Any]?, promise: Promise) in
      #if targetEnvironment(simulator)
      self.connectedDeviceId = deviceId
      self.sendEvent(DEVICE_CONNECTED, ["deviceId": deviceId, "isOadModel": false])
      self.sendEvent(DEVICE_READY, ["deviceId": deviceId, "isOadModel": false])
      promise.resolve(nil)
      #else
      guard self.isInitialized else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
        return
      }

      let password = options?["password"] as? String ?? "0000"
      let is24Hour = options?["is24Hour"] as? Bool ?? false
      let uuidString = options?["uuid"] as? String

      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "connecting"])

      var peripheralModel: VPPeripheralModel? = self.discoveredDevices[deviceId]

      if peripheralModel == nil,
         let uuidStr = uuidString,
         let uuid = UUID(uuidString: uuidStr),
         let central = self.centralManager {
        let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
          peripheralModel = VPPeripheralModel(peripher: peripheral)
          print("🔵 [VeepooSDK] connect: 通过 UUID 找到设备")
        } else {
          print("⚠️ [VeepooSDK] connect: UUID 方式未找到设备，启动辅助扫描")
        }
      }

      if let model = peripheralModel {
        self.performConnect(
          model: model,
          deviceId: deviceId,
          password: password,
          is24Hour: is24Hour,
          promise: promise
        )
      } else {
        print("🔍 [VeepooSDK] connect: 启动辅助扫描来发现设备...")
        self.pendingConnectDeviceId = deviceId
        self.pendingConnectPassword = password
        self.pendingConnectIs24Hour = is24Hour
        self.pendingConnectPromise = promise
        
        self.ensureCentralManager()
        if let central = self.centralManager {
          central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
          ])
          self.isScanning = true
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.pendingConnectDeviceId == deviceId {
              central.stopScan()
              self.isScanning = false
              if let pendingPromise = self.pendingConnectPromise {
                self.pendingConnectPromise = nil
                self.pendingConnectDeviceId = nil
                pendingPromise.reject("DEVICE_NOT_FOUND", "Device not found after scanning. Please ensure device is powered on and nearby.")
              }
            }
          }
        } else {
          promise.reject("BLUETOOTH_UNAVAILABLE", "Bluetooth manager not available")
        }
      }
      #endif
    }

    AsyncFunction("disconnect") { (deviceId: String, promise: Promise) in
      #if targetEnvironment(simulator)
      self.connectedDeviceId = nil
      self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "disconnected"])
      promise.resolve(nil)
      #else
      self.bleManager?.veepooSDKDisconnectDevice()
      self.connectedDeviceId = nil
      self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "disconnected"])
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("getConnectionStatus") { (deviceId: String, promise: Promise) in
      let status = self.connectedDeviceId == deviceId ? "connected" : "disconnected"
      promise.resolve(status)
    }

    AsyncFunction("verifyPassword") { (password: String, is24Hour: Bool, promise: Promise) in
      #if targetEnvironment(simulator)
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": ["status": "SUCCESS", "password": password]
      ])
      self.sendEvent(DEVICE_READY, ["deviceId": self.connectedDeviceId ?? "", "isOadModel": false])
      promise.resolve(["status": "SUCCESS", "password": password])
      #else
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
        return
      }

      manager.is24HourFormat = is24Hour

      manager.veepooSDKSynchronousPassword(with: SynchronousPasswordType(rawValue: 0)!, password: password) { result in
        let success = (result.rawValue == 1) || (result.rawValue == 6)
        let status = success ? "SUCCESS" : "FAILED"

        let resultData: [String: Any] = [
          "status": status,
          "password": password,
          "deviceVersion": manager.peripheralModel?.deviceVersion ?? ""
        ]

        self.sendEvent(PASSWORD_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": resultData
        ])

        if success {
          self.cacheDeviceFunctions()
          self.sendEvent(DEVICE_READY, ["deviceId": self.connectedDeviceId ?? "", "isOadModel": false])
        }

        promise.resolve(resultData)
      }
      #endif
    }

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
          "level": isPercent ? 0 : battery,
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
          "heartRateDetect": "supported"
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
        promise.reject("NO_DEVICE_CONNECTED", "No device connected or model unavailable")
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
        promise.reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable")
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
      
      if let originData = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: Any]] {
        var halfHourDataList: [[String: Any]] = []
        
        for (time, data) in originData {
          let item: [String: Any] = [
            "time": time,
            "heartValue": data["heartValue"] ?? 0,
            "stepValue": data["stepValue"] ?? 0,
            "calValue": data["calValue"] ?? 0,
            "disValue": data["disValue"] ?? 0,
            "systolic": data["highValue"] ?? 0,
            "diastolic": data["lowValue"] ?? 0,
            "spo2Value": data["spo2Value"] ?? 0,
            "tempValue": data["tempValue"] ?? 0,
            "stressValue": data["stressValue"] ?? 0
          ]
          halfHourDataList.append(item)
        }
        
        for data in halfHourDataList {
          self.sendEvent(ORIGIN_HALF_HOUR_DATA, [
            "deviceId": self.connectedDeviceId ?? "",
            "data": data
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
      promise.resolve([])
      #else
      guard let manager = self.bleManager,
            let deviceAddress = manager.peripheralModel?.deviceAddress else {
        promise.reject("NO_DEVICE_CONNECTED", "No device connected")
        return
      }
      
      let queryDate = date ?? self.getDateString(dayOffset: 0)
      var result: [[String: Any]] = []
      let sleepType = manager.peripheralModel?.sleepType ?? 0
      
      print("🔵 [VeepooSDK] readSleepData: date=\(queryDate), sleepType=\(sleepType)")
      
      if sleepType > 0 {
        if let items = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: queryDate, andTableID: deviceAddress) {
          print("🔵 [VeepooSDK] readSleepData: accurate sleep items=\(items.count)")
          for item in items {
            var dict: [String: Any] = [:]
            dict["date"] = String(item.wakeTime.prefix(10))
            dict["sleepTime"] = item.sleepTime.count > 16 ? item.sleepTime : (item.sleepTime + ":00")
            dict["wakeTime"] = item.wakeTime.count > 16 ? item.wakeTime : (item.wakeTime + ":00")
            dict["deepSleepDuration"] = Double(item.deepDuration) ?? 0.0
            dict["lightSleepDuration"] = Double(item.lightDuration) ?? 0.0
            dict["totalSleepHours"] = Int(Double(item.sleepDuration) ?? 0.0) ?? 0
            dict["totalSleepMinutes"] = 0
            dict["sleepLevel"] = Int(Double(item.sleepQuality) ?? 0.0) ?? 0
            dict["sleepLine"] = item.sleepLine ?? ""
            dict["wakeUpCount"] = Int(Double(item.insomniaTimes) ?? 0.0) ?? 0
            dict["sleepQulity"] = Int(Double(item.sleepQuality) ?? 0.0) ?? 0
            result.append(dict)
          }
        }
       } else {
          if let items = VPDataBaseOperation.veepooSDKGetSleepData(withDate: queryDate, andTableID: deviceAddress) as? [[String: Any]] {
            print("🔵 [VeepooSDK] readSleepData: ordinary sleep items=\(items.count)")
            result = formatOrdinarySleep(items)
          }
       }
       
       print("✅ [VeepooSDK] readSleepData: result count=\(result.count)")
       
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
        promise.reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable")
        return
      }
      
      let queryDate = date ?? self.getDateString(dayOffset: 0)
      let userStature: UInt = manager.peripheralModel?.deviceStature ?? 170
      
      print("🔵 [VeepooSDK] readSportStepData: date=\(queryDate), deviceAddress=\(deviceAddress ?? "nil")")
      
      DispatchQueue.main.async {
        VPDataBaseOperation.veepooSDKGetStepData(withDate: queryDate, andTableID: deviceAddress, changeUserStature: userStature) { stepDict in
          print("🔵 [VeepooSDK] readSportStepData callback: stepDict exists=\(stepDict != nil)")
          
          guard let dict = stepDict as? [String: Any] else {
            print("⚠️ [VeepooSDK] readSportStepData: stepDict is nil")
            let emptyResult: [String: Any] = [
              "date": queryDate,
              "stepCount": 0,
              "distance": 0.0,
              "calories": 0.0
            ]
            promise.resolve(emptyResult)
            return
          }
          
          print("🔵 [VeepooSDK] readSportStepData: keys=\(dict.keys)")
          
          let stepValue: Any = dict["Step"]
          let disValue: Any = dict["Dis"]
          let calValue: Any = dict["Cal"]
          
          let step = self.getInt(stepValue)
          let disKm = self.getDouble(disValue)
          let cal = self.getDouble(calValue)
          
          print("✅ [VeepooSDK] readSportStepData: step=\(step), dis=\(disKm) km, cal=\(cal) kcal")
          
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
        promise.reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable")
        return
      }
      
      let dateStr = self.getDateString(dayOffset: dayOffset)
      var resultList: [[String: Any]] = []
      
      if let originData = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: Any]] {
        for (time, data) in originData {
          let item: [String: Any] = [
            "time": time,
            "heartValue": data["heartValue"] ?? 0,
            "stepValue": data["stepValue"] ?? 0,
            "calValue": data["calValue"] ?? 0,
            "disValue": data["disValue"] ?? 0,
            "sportValue": data["sportValue"] ?? 0,
            "systolic": data["highValue"] ?? 0,
            "diastolic": data["lowValue"] ?? 0,
            "spo2Value": data["spo2Value"] ?? 0,
            "tempValue": data["tempValue"] ?? 0,
            "stressValue": data["stressValue"] ?? 0,
            "met": data["met"] ?? 0
          ]
          resultList.append(item)
        }
      }
      
      let sortedResult = resultList.sorted { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
      
      print("🔵 [VeepooSDK] readOriginData: dayOffset=\(dayOffset), count=\(sortedResult.count)")
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

    AsyncFunction("readAutoMeasureSetting") { (promise: Promise) in
      promise.resolve([])
    }

    AsyncFunction("modifyAutoMeasureSetting") { (setting: [String: Any], promise: Promise) in
      promise.resolve(nil)
    }

    AsyncFunction("setLanguage") { (language: Int, promise: Promise) in
      promise.resolve(true)
    }

    AsyncFunction("startHeartRateTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      peripheralManage.veepooSDKTestHeartStart(true) { state, heartValue in
        var statusStr = "unknown"
        var isEnd = false

        // 🔧 假进度模拟：对于没有进度回调的测试，模拟进度更新
        var simulatedProgress = 0

        func simulateProgress() {
          guard simulatedProgress < 100 else { return }

          simulatedProgress += 10
          self.sendEvent(HEART_RATE_TEST_RESULT, [
            "deviceId": self.connectedDeviceId ?? "",
            "result": [
              "state": statusStr,
              "value": heartValue
            ]
          ])
        }

        switch state {
        case .start:
          statusStr = "testing"

          // 🔧 假进度模拟：对于没有进度回调的测试，模拟进度更新
          var simulatedProgress = 0

          func simulateProgress() {
            guard simulatedProgress < 100 else { return }

            simulatedProgress += 10
            self.sendEvent(HEART_RATE_TEST_RESULT, [
              "deviceId": self.connectedDeviceId ?? "",
              "result": [
                "state": statusStr,
                "value": heartValue
              ]
            ])
          }

          simulateProgress()
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }

        case .notWear:
          statusStr = "notWear"
          isEnd = true

        case .deviceBusy:
          statusStr = "deviceBusy"
          isEnd = true

        case .over:
          statusStr = "over"
          isEnd = true

        @unknown default:
          statusStr = "unknown"
        }

        // 如果没有进度回调且未结束，模拟多次进度更新
        if !isEnd && simulatedProgress == 0 {
          for _ in 0..<10 {
            simulateProgress()
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(2) / Double(10)) {
              simulateProgress()
            }
          }
        }

        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": statusStr,
            "value": heartValue
          ]
        ])
      }
      #endif
    }

    AsyncFunction("stopHeartRateTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.peripheralManage?.veepooSDKTestHeartStart(false) { _, _ in }
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("startBloodPressureTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      peripheralManage.veepooSDKTestBloodStart(true, testMode: 0) { state, progress, high, low in
        var statusStr = "unknown"
        var isEnd = false

        switch state {
        case .testing: statusStr = "testing"
        case .deviceBusy: statusStr = "deviceBusy"; isEnd = true
        case .testFail: statusStr = "testFail"; isEnd = true
        case .testInterrupt: statusStr = "testInterrupt"; isEnd = true
        case .complete: statusStr = "complete"; isEnd = true
        case .noFunction: statusStr = "noFunction"; isEnd = true
        @unknown default: statusStr = "unknown"
        }

        self.sendEvent(BLOOD_PRESSURE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": statusStr,
            "systolic": high,
            "diastolic": low,
            "progress": progress,
            "isEnd": isEnd
          ]
        ])
      }

      promise.resolve(nil)
      #endif
    }

    AsyncFunction("stopBloodPressureTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.peripheralManage?.veepooSDKTestBloodStart(false, testMode: 0) { _, _, _, _ in }
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("startBloodOxygenTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      peripheralManage.veepooSDKTestOxygenStart(true) { state, value in
        var statusStr = "unknown"
        var isEnd = false

        switch state {
        case .start: statusStr = "start"
        case .testing: statusStr = "testing"
        case .notWear: statusStr = "notWear"; isEnd = true
        case .deviceBusy: statusStr = "deviceBusy"; isEnd = true
        case .over: statusStr = "over"; isEnd = true
        case .noFunction: statusStr = "noFunction"; isEnd = true
        case .calibration: statusStr = "calibration"
        case .calibrationComplete: statusStr = "calibrationComplete"
        case .invalid: statusStr = "invalid"; isEnd = true
        @unknown default: statusStr = "unknown"
        }

        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": statusStr,
            "value": value,
            "isEnd": isEnd
          ]
        ])
      }

      promise.resolve(nil)
      #endif
    }

    AsyncFunction("stopBloodOxygenTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.peripheralManage?.veepooSDKTestOxygenStart(false) { _, _ in }
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("startTemperatureTest") { (promise: Promise) in
      promise.resolve(nil)
    }

    AsyncFunction("stopTemperatureTest") { (promise: Promise) in
      promise.resolve(nil)
    }

    AsyncFunction("startStressTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      peripheralManage.veepooSDK_stressTestStart(true) { state, progress, stress in
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

    AsyncFunction("stopStressTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.peripheralManage?.veepooSDK_stressTestStart(false) { _, _, _ in }
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("startBloodGlucoseTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "Peripheral manager is nil")
        return
      }

      peripheralManage.veepooSDKTestBloodGlucoseStart(true, isPersonalModel: false) { state, progress, value, level in
        var statusStr = "unknown"
        var isEnd = false

        switch state {
        case .unsupported: statusStr = "unsupported"; isEnd = true
        case .open: statusStr = "testing"
        case .close: statusStr = "over"; isEnd = true
        case .lowPower: statusStr = "lowPower"; isEnd = true
        case .deviceBusy: statusStr = "deviceBusy"; isEnd = true
        case .notWear: statusStr = "notWear"; isEnd = true
        @unknown default: statusStr = "unknown"
        }

        let finalValue = Double(value) / 100.0

        self.sendEvent(BLOOD_GLUCOSE_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": [
            "glucose": finalValue,
            "progress": progress,
            "level": level,
            "status": statusStr,
            "isEnd": isEnd
          ]
        ])
      }

      promise.resolve(nil)
      #endif
    }

    AsyncFunction("stopBloodGlucoseTest") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.peripheralManage?.veepooSDKTestBloodGlucoseStart(false, isPersonalModel: false) { _, _, _, _ in }
      promise.resolve(nil)
      #endif
    }

    OnStartObserving {
      self.emitBluetoothStatus()
    }

    OnDestroy {
      self.cleanup()
    }
  }

  private func ensureCentralManager() {
    #if !targetEnvironment(simulator)
    if centralManager != nil { return }
    centralManager = CBCentralManager(delegate: nil, queue: nil, options: [
      CBCentralManagerOptionShowPowerAlertKey: true
    ])
    #endif
  }

  private func performConnect(
    model: VPPeripheralModel,
    deviceId: String,
    password: String,
    is24Hour: Bool,
    promise: Promise
  ) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager else {
      promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
      return
    }

    manager.veepooSDKConnectDevice(model) { [weak self] connectState in
      guard let self = self else { return }
      
      switch connectState.rawValue {
      case 2:
        self.connectedDeviceId = deviceId
        self.sendEvent(DEVICE_CONNECTED, ["deviceId": deviceId, "isOadModel": false])
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "connected"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
        }

        promise.resolve(nil)

      case 0:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "bluetoothOff"])
        promise.reject("BLUETOOTH_OFF", "Bluetooth is powered off")

      case 1:
        self.sendEvent(DEVICE_CONNECT_STATUS, [
          "deviceId": deviceId,
          "status": "connecting"
        ])

      case 3:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "failed"])
        promise.reject("CONNECTION_FAILED", "Connection failed")

      case 6:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "timeout"])
        promise.reject("TIMEOUT", "Connection timeout")

      default:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "unknown", "code": connectState.rawValue])
        promise.reject("UNKNOWN_ERROR", "Unknown connection error: \(connectState.rawValue)")
      }
    }
    #endif
  }

  private func setupVeepooCallbacks() {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager else { return }

    manager.vpBleCentralManageChangeBlock = { [weak self] _ in
      DispatchQueue.main.async {
        self?.emitBluetoothStatus()
      }
    }

    manager.vpBleConnectStateChangeBlock = { [weak self] state in
      guard let self = self else { return }

      let mac = self.connectedDeviceId ?? ""

      self.sendEvent(DEVICE_CONNECT_STATUS, [
        "deviceId": mac,
        "code": state.rawValue
      ])

      if state.rawValue == 0 {
        self.connectedDeviceId = nil
        self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": mac])
      }
    }
    #endif
  }

  #if !targetEnvironment(simulator)
  private func handleDiscoveredDevice(_ peripheralModel: VPPeripheralModel) {
    let rawAddr = peripheralModel.deviceAddress
    let uuid = peripheralModel.peripheral.identifier.uuidString
    let name = peripheralModel.deviceName ?? "Unknown"
    let rssi = peripheralModel.rssi ?? 0

    let exportId = rawAddr ?? uuid

    self.discoveredDevices[exportId] = peripheralModel

    self.sendEvent(DEVICE_FOUND, [
      "device": [
        "id": exportId,
        "name": name,
        "rssi": rssi,
        "mac": exportId,
        "uuid": uuid
      ],
      "timestamp": Date().timeIntervalSince1970 * 1000
    ])
    
    if let pendingId = self.pendingConnectDeviceId,
       let pendingPromise = self.pendingConnectPromise,
       let pendingPassword = self.pendingConnectPassword,
       (pendingId == exportId || pendingId == uuid) {
      print("🔵 [VeepooSDK] 发现待连接设备: \(exportId), 自动连接...")
      self.pendingConnectDeviceId = nil
      self.pendingConnectPromise = nil
      self.pendingConnectPassword = nil
      
      if let central = self.centralManager, self.isScanning {
        central.stopScan()
        self.isScanning = false
      }
      
      self.performConnect(
        model: peripheralModel,
        deviceId: exportId,
        password: pendingPassword,
        is24Hour: self.pendingConnectIs24Hour,
        promise: pendingPromise
      )
    }
  }
  #endif

  private func verifyPasswordInternal(deviceId: String, password: String, is24Hour: Bool) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager else { return }

    manager.is24HourFormat = is24Hour

    manager.veepooSDKSynchronousPassword(with: SynchronousPasswordType(rawValue: 0)!, password: password) { [weak self] result in
      guard let self = self else { return }

      let success = (result.rawValue == 1) || (result.rawValue == 6)
      let status = success ? "SUCCESS" : "FAILED"

      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": status,
          "password": password,
          "deviceVersion": manager.peripheralModel?.deviceVersion ?? ""
        ]
      ])

      if success {
        self.sendEvent(DEVICE_READY, ["deviceId": deviceId, "isOadModel": false])
      }
    }
    #endif
  }
  
  private func emitHalfHourData(dayOffset: Int) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let deviceAddress = manager.peripheralModel?.deviceAddress else { return }
    
    let dateStr = self.getDateString(dayOffset: dayOffset)
    
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
    #endif
  }
  
  private func handleReadDeviceAllData(promise: Promise) {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let _ = manager.peripheralModel?.deviceAddress else {
      promise.reject("NO_DEVICE_CONNECTED", "No device connected")
      return
    }
    
    print("🔵 [VeepooSDK] Starting to read all device data...")
    
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
      
      print("🔵 [VeepooSDK] readDeviceAllData state: \(readState.rawValue), total: \(totalDay), current: \(currentReadDayNumber), progress: \(readCurrentDayProgress)")
      
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
        print("✅ [VeepooSDK] readDeviceAllData complete. Total days: \(totalDay)")
        
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
        print("❌ [VeepooSDK] readDeviceAllData failed: Invalid state")
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
        print("🔵 [VeepooSDK] readDeviceAllData state: \(readState.rawValue)")
      }
    }
    #endif
  }

  private func emitBluetoothStatus() {
    #if !targetEnvironment(simulator)
    var stateCode = 0
    var stateName = "unknown"

    if let central = centralManager {
      switch central.state {
      case .unknown: stateCode = 0; stateName = "unknown"
      case .resetting: stateCode = 1; stateName = "resetting"
      case .unsupported: stateCode = 2; stateName = "unsupported"
      case .unauthorized: stateCode = 3; stateName = "unauthorized"
      case .poweredOff: stateCode = 4; stateName = "poweredOff"
      case .poweredOn: stateCode = 5; stateName = "poweredOn"
      @unknown default: stateCode = 0; stateName = "unknown"
      }
    }

    let authorization: Int
    let authorizationName: String

    if #available(iOS 13.0, *) {
      switch CBManager.authorization {
      case .notDetermined: authorization = 0; authorizationName = "notDetermined"
      case .restricted: authorization = 1; authorizationName = "restricted"
      case .denied: authorization = 2; authorizationName = "denied"
      case .allowedAlways: authorization = 3; authorizationName = "allowedAlways"
      @unknown default: authorization = 0; authorizationName = "unknown"
      }
    } else {
      authorization = 0
      authorizationName = "unknown"
    }

    self.sendEvent(BLUETOOTH_STATE_CHANGED, [
      "state": stateCode,
      "stateName": stateName,
      "authorization": authorization,
      "authorizationName": authorizationName,
      "isScanning": isScanning
    ])
    #endif
  }

  private func cacheDeviceFunctions() {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager,
          let device = manager.peripheralModel else {
      return
    }
    
    let package1: [String: Any] = [
      "type": "DeviceFunctionPackage1",
      "bloodPressure": device.bloodPressureType > 0 ? "supported" : "unsupported",
      "heartRateDetect": device.deviceFuctionData[18] == 0 ? "supported" : "unsupported",
      "spoH": device.oxygenType > 0 ? "supported" : "unsupported",
      "temperatureFunction": device.temperatureType > 0 ? "supported" : "unsupported"
    ]
    
    let package2: [String: Any] = [
      "type": "DeviceFunctionPackage2",
      "ecgFunction": device.ecgType > 0 ? "supported" : "unsupported",
      "precisionSleep": device.sleepType > 0 ? "supported" : "unsupported",
      "hrvFunction": device.hrvType > 0 ? "supported" : "unsupported"
    ]
    
    let package3: [String: Any] = [
      "type": "DeviceFunctionPackage3",
      "stressFunction": device.stressType > 1 ? "supported" : "unsupported",
      "bloodGlucose": device.bloodGlucoseType > 0 ? "supported" : "unsupported",
      "bloodComponent": device.bloodAnalysisType > 0 ? "supported" : "unsupported",
      "bodyComponent": device.bodyCompositionType > 0 ? "supported" : "unsupported"
    ]
    
    cachedDeviceFunctions = [
      "package1": package1,
      "package2": package2,
      "package3": package3
    ]
    
    self.sendEvent(DEVICE_FUNCTION, [
      "deviceId": self.connectedDeviceId ?? "",
      "data": cachedDeviceFunctions
    ])
    #endif
  }

  private func cleanup() {
    #if !targetEnvironment(simulator)
    bleManager?.veepooSDKStopScanDevice()
    bleManager?.veepooSDKDisconnectDevice()
    #endif
    isScanning = false
    connectedDeviceId = nil
    isInitialized = false
    discoveredDevices.removeAll()
  }

  private func getDateString(dayOffset: Int) -> String {
    let calendar = Calendar.current
    let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private func formatOrdinarySleep(_ items: [[String: Any]]) -> [[String: Any]] {
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

  private func getInt(_ value: Any?) -> Int {
    if let num = value as? NSNumber {
      return num.intValue
    } else if let str = value as? String {
      return Int(str) ?? 0
    } else if let int = value as? Int {
      return int
    }
    return 0
  }

  private func getDouble(_ value: Any?) -> Double {
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
