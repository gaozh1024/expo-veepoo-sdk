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

      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "connecting"])

      var peripheralModel: VPPeripheralModel? = self.discoveredDevices[deviceId]

      if peripheralModel == nil,
         let uuidString = options?["uuid"] as? String,
         let uuid = UUID(uuidString: uuidString),
         let central = self.centralManager {
        let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
          peripheralModel = VPPeripheralModel(peripher: peripheral)
        }
      }

      guard let model = peripheralModel else {
        promise.reject("DEVICE_NOT_FOUND", "Device not found. Please scan first.")
        return
      }

      manager.veepooSDKConnectDevice(model) { connectState in
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
          // State code 1 means "connecting", not an error state
          // Only send connection status update, wait for subsequent state changes
          self.sendEvent(DEVICE_CONNECT_STATUS, [
            "deviceId": deviceId,
            "status": "connecting"
          ])
          // Do not call promise.reject(), keep Promise pending
          // Wait for subsequent case 2 (success) or other state codes to resolve Promise

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
          self.sendEvent(DEVICE_READY, ["deviceId": self.connectedDeviceId ?? "", "isOadModel": false])
        }

        promise.resolve(resultData)
      }
      #endif
    }

    AsyncFunction("readBattery") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve([
        "level": 0,
        "percent": 88,
        "powerModel": 0,
        "state": 1,
        "bat": 0,
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
          "percent": isPercent,
          "powerModel": 0,
          "state": chargeState.rawValue,
          "bat": 0,
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
      promise.resolve([:])
    }

    AsyncFunction("readSocialMsgData") { (promise: Promise) in
      promise.resolve([:])
    }

    AsyncFunction("startReadOriginData") { (promise: Promise) in
      promise.resolve(nil)
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
        return@AsyncFunction
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

      peripheralManage.veepooSDKTestHeartStart(true) { state, heartValue in
        var statusStr = "unknown"
        var isEnd = false

        // 🔧 假进度模拟：对于没有进度回调的测试，模拟进度更新
        var simulatedProgress = 0
        var lastProgressUpdate: DispatchTime?

        func simulateProgress() {
          guard simulatedProgress < 100 else { return }

          simulatedProgress += 10  // 每次更新10%
          lastProgressUpdate = DispatchTime.now()

          self.sendEvent(HEART_RATE_TEST_RESULT, [
            "deviceId": self.connectedDeviceId ?? "",
            "result": [
              "state": statusStr,
              "value": heartValue
            ]
          ])
        }

        switch state {
        case .start: statusStr = "testing"
          // 模拟进度更新
          simulateProgress()
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            simulateProgress()
          }

        case .notWear: statusStr = "notWear"; isEnd = true
        case .deviceBusy: statusStr = "deviceBusy"; isEnd = true
        case .over: statusStr = "over"; isEnd = true
        @unknown default: statusStr = "unknown"
        }

        // 如果没有进度回调且未结束，每2秒模拟一次进度更新
        if !isEnd && simulatedProgress == 0 {
          simulateProgress()
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            simulateProgress()
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

      peripheralManage.veepooSDKTestHeartStart(true) { state, heartValue in
        var statusStr = "unknown"
        var isEnd = false

        switch state {
        case .start: statusStr = "start"
        case .testing: statusStr = "testing"
        case .notWear: statusStr = "notWear"; isEnd = true
        case .deviceBusy: statusStr = "deviceBusy"; isEnd = true
        case .over: statusStr = "over"; isEnd = true
        @unknown default: statusStr = "unknown"
        }

        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": statusStr,
            "value": heartValue,
            "isEnd": isEnd
          ]
        ])
      }

      promise.resolve(nil)
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
}
