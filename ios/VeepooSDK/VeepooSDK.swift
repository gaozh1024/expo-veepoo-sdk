import ExpoModulesCore
import CoreBluetooth

let DEVICE_FOUND = "deviceFound"
let DEVICE_CONNECTED = "deviceConnected"
let DEVICE_DISCONNECTED = "deviceDisconnected"
let DEVICE_CONNECT_STATUS = "deviceConnectStatus"
let DEVICE_READY = "deviceReady"
let BLUETOOTH_STATE_CHANGED = "bluetoothStateChanged"
let DEVICE_FUNCTION = "deviceFunction"
let DEVICE_VERSION = "deviceVersion"
let PASSWORD_DATA = "passwordData"
let SOCIAL_MSG_DATA = "socialMsgData"
let READ_ORIGIN_PROGRESS = "readOriginProgress"
let READ_ORIGIN_COMPLETE = "readOriginComplete"
let ORIGIN_HALF_HOUR_DATA = "originHalfHourData"
let HEART_RATE_TEST_RESULT = "heartRateTestResult"
let BLOOD_PRESSURE_TEST_RESULT = "bloodPressureTestResult"
let BLOOD_OXYGEN_TEST_RESULT = "bloodOxygenTestResult"
let TEMPERATURE_TEST_RESULT = "temperatureTestResult"
let STRESS_DATA = "stressData"
let BLOOD_GLUCOSE_DATA = "bloodGlucoseData"
let BATTERY_DATA = "batteryData"
let CUSTOM_SETTING_DATA = "customSettingData"
let DATA_RECEIVED = "dataReceived"
let CONNECTION_STATUS_CHANGED = "connectionStatusChanged"
let ERROR = "error"

public class VeepooSDKModule: Module {
  private var bleManager: VPBleCentralManage?
  private var peripheralManage: VPPeripheralManage?
  private var peripheralModel: VPPeripheralModel?
  private var isScanning = false
  private var connectedDeviceId: String?
  private var isInitialized = false

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
      SOCIAL_MSG_DATA,
      READ_ORIGIN_PROGRESS,
      READ_ORIGIN_COMPLETE,
      ORIGIN_HALF_HOUR_DATA,
      HEART_RATE_TEST_RESULT,
      BLOOD_PRESSURE_TEST_RESULT,
      BLOOD_OXYGEN_TEST_RESULT,
      TEMPERATURE_TEST_RESULT,
      STRESS_DATA,
      BLOOD_GLUCOSE_DATA,
      BATTERY_DATA,
      CUSTOM_SETTING_DATA,
      DATA_RECEIVED,
      CONNECTION_STATUS_CHANGED,
      ERROR
    )

    AsyncFunction("init") { (promise: Promise) in
      guard let manager = VPBleCentralManage.sharedBleManager() else {
        promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Veepoo SDK")
        return
      }

      self.bleManager = manager
      self.peripheralManage = VPPeripheralManage.shareVPPeripheralManager()
      manager.peripheralManage = self.peripheralManage
      manager.isLogEnable = true
      manager.manufacturerIDFilter = false

      self.setupBleCallbacks()
      self.isInitialized = true

      promise.resolve(nil)
    }

    AsyncFunction("isBluetoothEnabled") { (promise: Promise) in
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call init() first")
        return
      }

      let isEnabled = manager.state == .poweredOn
      promise.resolve(isEnabled)
    }

    AsyncFunction("requestPermissions") { (promise: Promise) in
      let authorization = CBManager.authorization

      switch authorization {
      case .allowedAlways, .notDetermined:
        promise.resolve(true)
      default:
        promise.reject("PERMISSION_DENIED", "Bluetooth permission denied")
      }
    }

    AsyncFunction("startScan") { (options: [String: Any]?, promise: Promise) in
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      guard manager.state == .poweredOn else {
        promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
        return
      }

      guard !self.isScanning else {
        promise.resolve(nil)
        return
      }

      manager.veepooSDKStartScanDevice { [weak self] peripheralModel in
        guard let self = self else { return }

        let deviceData: [String: Any] = [
          "id": peripheralModel.deviceAddress ?? "",
          "name": peripheralModel.deviceName ?? "Unknown",
          "rssi": peripheralModel.rssi ?? 0,
          "mac": peripheralModel.deviceAddress ?? "",
          "uuid": peripheralModel.identifier?.uuidString ?? ""
        ]

        self.sendEvent(DEVICE_FOUND, [
          "device": deviceData,
          "timestamp": Date().timeIntervalSince1970 * 1000
        ])
      }

      self.isScanning = true
      promise.resolve(nil)
    }

    AsyncFunction("stopScan") { (promise: Promise) in
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      manager.veepooSDKStopScanDevice()
      self.isScanning = false
      promise.resolve(nil)
    }

    AsyncFunction("connect") { (deviceId: String, options: [String: Any]?, promise: Promise) in
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      guard manager.state == .poweredOn else {
        promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
        return
      }

      let password = options?["password"] as? String ?? "0000"
      let is24Hour = options?["is24Hour"] as? Bool ?? false

      let model = VPPeripheralModel()
      model.deviceAddress = deviceId

      self.sendEvent(DEVICE_CONNECT_STATUS, [
        "deviceId": deviceId,
        "status": "connecting"
      ])

      manager.veepooSDKConnectDevice(model) { [weak self] connectState in
        guard let self = self else { return }

        let code = connectState.rawValue

        switch code {
        case 2:
          self.connectedDeviceId = deviceId
          self.peripheralModel = model
          self.sendEvent(DEVICE_CONNECTED, [
            "deviceId": deviceId
          ])
          self.sendEvent(DEVICE_CONNECT_STATUS, [
            "deviceId": deviceId,
            "status": "connected",
            "code": code
          ])

          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.verifyPasswordInternal(password: password, is24Hour: is24Hour)
          }

          promise.resolve(nil)

        case 0:
          self.sendEvent(DEVICE_CONNECT_STATUS, [
            "deviceId": deviceId,
            "status": "disconnected",
            "code": code
          ])
          promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth powered off")

        case 3:
          self.sendEvent(DEVICE_CONNECT_STATUS, [
            "deviceId": deviceId,
            "status": "disconnected",
            "code": code
          ])
          promise.reject("CONNECTION_FAILED", "Connection failed")

        case 6:
          self.sendEvent(DEVICE_CONNECT_STATUS, [
            "deviceId": deviceId,
            "status": "disconnected",
            "code": code
          ])
          promise.reject("TIMEOUT", "Connection timeout")

        default:
          self.sendEvent(DEVICE_CONNECT_STATUS, [
            "deviceId": deviceId,
            "status": "error",
            "code": code
          ])
          promise.reject("UNKNOWN_ERROR", "Unknown connection error: \(code)")
        }
      }
    }

    AsyncFunction("disconnect") { (deviceId: String, promise: Promise) in
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      manager.veepooSDKDisconnectDevice()
      self.connectedDeviceId = nil
      self.peripheralModel = nil

      self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
      self.sendEvent(DEVICE_CONNECT_STATUS, [
        "deviceId": deviceId,
        "status": "disconnected"
      ])

      promise.resolve(nil)
    }

    AsyncFunction("getConnectionStatus") { (deviceId: String, promise: Promise) in
      if self.connectedDeviceId == deviceId {
        promise.resolve("connected")
      } else {
        promise.resolve("disconnected")
      }
    }

    AsyncFunction("verifyPassword") { (password: String, is24Hour: Bool, promise: Promise) in
      guard let manager = self.bleManager, let peripheralManage = self.peripheralManage else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized or device not connected")
        return
      }

      let timeSetting = VPDeviceTimeSetting()
      let calendar = Calendar.current
      timeSetting.year = Int32(calendar.component(.year, from: Date()))
      timeSetting.month = Int32(calendar.component(.month, from: Date()))
      timeSetting.day = Int32(calendar.component(.day, from: Date()))
      timeSetting.hour = Int32(calendar.component(.hour, from: Date()))
      timeSetting.minute = Int32(calendar.component(.minute, from: Date()))
      timeSetting.second = Int32(calendar.component(.second, from: Date()))
      timeSetting.system = Int32(is24Hour ? 2 : 1)

      peripheralManage.veepooSDKSynchronousPassword(withType: 0, password: password, synchronizationResult: { result in
        let status: String
        switch result {
        case 0: status = "CHECK_FAIL"
        case 1: status = "CHECK_SUCCESS"
        case 2: status = "NOT_SET"
        default: status = "UNKNOWN"
        }

        promise.resolve([
          "status": status,
          "password": password,
          "deviceNumber": 0,
          "deviceVersion": "",
          "deviceTestVersion": "",
          "isHaveDrinkData": false,
          "isOpenNightTurnWrist": "unknown",
          "findPhoneFunction": "unknown",
          "wearDetectFunction": "unknown"
        ])
      }, deviceTimeSetting: timeSetting)
    }

    AsyncFunction("readBattery") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKReadDeviceBatteryInfo { isPercent, isLowBattery, battery in
        promise.resolve([
          "level": battery,
          "percent": isPercent,
          "powerModel": 0,
          "state": 0,
          "bat": battery,
          "isLowBattery": isLowBattery
        ])
      }
    }

    AsyncFunction("syncPersonalInfo") { (info: [String: Any], promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      let sex = info["sex"] as? Int ?? 1
      let height = info["height"] as? Int ?? 170
      let weight = info["weight"] as? Int ?? 65
      let age = info["age"] as? Int ?? 25
      let stepAim = info["stepAim"] as? Int ?? 8000

      peripheralManage.veepooSDKSynchronousPersonalInformation(
        withStature: Int32(height),
        weight: Int32(weight),
        birth: Int32(age),
        sex: Int32(sex),
        targetStep: Int32(stepAim)
      ) { result in
        promise.resolve(result == 1)
      }
    }

    AsyncFunction("readDeviceFunctions") { (promise: Promise) in
      guard let model = self.peripheralModel else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      var functions: [String: Any] = [:]

      if let data = model.deviceFuctionData {
        functions["package1"] = [
          "bloodPressure": self.parseFunctionStatus(data, index: 0),
          "drinking": self.parseFunctionStatus(data, index: 1),
          "sedentaryRemind": self.parseFunctionStatus(data, index: 2),
          "heartRateWarning": self.parseFunctionStatus(data, index: 3),
          "spoH": self.parseFunctionStatus(data, index: 7),
          "heartRateDetect": self.parseFunctionStatus(data, index: 17)
        ]
      }

      promise.resolve(functions)
    }

    AsyncFunction("readSocialMsgData") { (promise: Promise) in
      promise.resolve([
        "phone": "unknown",
        "sms": "unknown",
        "wechat": "unknown",
        "qq": "unknown"
      ])
    }

    AsyncFunction("startReadOriginData") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSdkStartReadDeviceAllData { [weak self] state, totalDays, currentDay, progress in
        guard let self = self else { return }

        let readState: String
        switch state {
        case .idle: readState = "idle"
        case .start: readState = "start"
        case .reading: readState = "reading"
        case .complete: readState = "complete"
        case .invalid: readState = "invalid"
        @unknown default: readState = "unknown"
        }

        self.sendEvent(READ_ORIGIN_PROGRESS, [
          "deviceId": self.connectedDeviceId ?? "",
          "progress": [
            "readState": readState,
            "totalDays": totalDays,
            "currentDay": currentDay,
            "progress": progress
          ]
        ])

        if state == .complete {
          self.sendEvent(READ_ORIGIN_COMPLETE, [
            "deviceId": self.connectedDeviceId ?? "",
            "success": true
          ])
        }
      }

      promise.resolve(nil)
    }

    AsyncFunction("readAutoMeasureSetting") { (promise: Promise) in
      promise.resolve([])
    }

    AsyncFunction("modifyAutoMeasureSetting") { (setting: [String: Any], promise: Promise) in
      promise.resolve(nil)
    }

    AsyncFunction("setLanguage") { (language: Int, promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKSettingLanguage(UInt8(language)) { success in
        promise.resolve(success)
      }
    }

    AsyncFunction("startHeartRateTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKTestHeartStart(true) { [weak self] state, heartValue in
        guard let self = self else { return }

        let testState: String
        switch state {
        case .start: testState = "start"
        case .testing: testState = "testing"
        case .notWear: testState = "notWear"
        case .deviceBusy: testState = "deviceBusy"
        case .over: testState = "over"
        @unknown default: testState = "error"
        }

        self.sendEvent(HEART_RATE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": testState,
            "value": heartValue
          ]
        ])
      }

      promise.resolve(nil)
    }

    AsyncFunction("stopHeartRateTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKTestHeartStart(false) { _, _ in }
      promise.resolve(nil)
    }

    AsyncFunction("startBloodPressureTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKTestBPStart(true) { [weak self] state, bpData in
        guard let self = self else { return }

        let testState: String
        switch state {
        case .start: testState = "start"
        case .testing: testState = "testing"
        case .notWear: testState = "notWear"
        case .deviceBusy: testState = "deviceBusy"
        case .over: testState = "over"
        @unknown default: testState = "error"
        }

        self.sendEvent(BLOOD_PRESSURE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": testState,
            "systolic": bpData?.systolic ?? 0,
            "diastolic": bpData?.diastolic ?? 0,
            "pulse": bpData?.pulse ?? 0
          ]
        ])
      }

      promise.resolve(nil)
    }

    AsyncFunction("stopBloodPressureTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKTestBPStart(false) { _, _ in }
      promise.resolve(nil)
    }

    AsyncFunction("startBloodOxygenTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKTestSPO2HStart(true) { [weak self] state, spo2Value in
        guard let self = self else { return }

        let testState: String
        switch state {
        case .start: testState = "start"
        case .testing: testState = "testing"
        case .notWear: testState = "notWear"
        case .deviceBusy: testState = "deviceBusy"
        case .over: testState = "over"
        @unknown default: testState = "error"
        }

        self.sendEvent(BLOOD_OXYGEN_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": testState,
            "value": spo2Value
          ]
        ])
      }

      promise.resolve(nil)
    }

    AsyncFunction("stopBloodOxygenTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKTestSPO2HStart(false) { _, _ in }
      promise.resolve(nil)
    }

    AsyncFunction("startTemperatureTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDK_temperatureTestStart(true) { [weak self] state, enable, progress, tempValue, originalTempValue in
        guard let self = self else { return }

        let testState: String
        switch state {
        case .start: testState = "start"
        case .testing: testState = "testing"
        case .notWear: testState = "notWear"
        case .deviceBusy: testState = "deviceBusy"
        case .over: testState = "over"
        @unknown default: testState = "error"
        }

        self.sendEvent(TEMPERATURE_TEST_RESULT, [
          "deviceId": self.connectedDeviceId ?? "",
          "result": [
            "state": testState,
            "value": tempValue,
            "originalValue": originalTempValue,
            "progress": progress,
            "enable": enable
          ]
        ])
      }

      promise.resolve(nil)
    }

    AsyncFunction("stopTemperatureTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDK_temperatureTestStart(false) { _, _, _, _, _ in }
      promise.resolve(nil)
    }

    AsyncFunction("startStressTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKMeasurePressure { [weak self] state, stressValue in
        guard let self = self else { return }

        self.sendEvent(STRESS_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": [
            "stress": stressValue,
            "timestamp": Date().timeIntervalSince1970 * 1000
          ]
        ])
      }

      promise.resolve(nil)
    }

    AsyncFunction("stopStressTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKCancelMeasurePressure()
      promise.resolve(nil)
    }

    AsyncFunction("startBloodGlucoseTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKMeasureBloodGlucose { [weak self] state, glucoseValue in
        guard let self = self else { return }

        self.sendEvent(BLOOD_GLUCOSE_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": [
            "glucose": glucoseValue,
            "timestamp": Date().timeIntervalSince1970 * 1000
          ]
        ])
      }

      promise.resolve(nil)
    }

    AsyncFunction("stopBloodGlucoseTest") { (promise: Promise) in
      guard let peripheralManage = self.peripheralManage else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }

      peripheralManage.veepooSDKCancelMeasureBloodGlucose()
      promise.resolve(nil)
    }

    OnStartObserving {
      self.registerForBluetoothEvents()
    }

    OnStopObserving {
      self.unregisterForBluetoothEvents()
    }

    OnDestroy {
      self.cleanup()
    }
  }

  private func setupBleCallbacks() {
    guard let manager = self.bleManager else { return }

    manager.vpBleCentralManageChangeBlock = { [weak self] in
      guard let self = self else { return }

      let state: String
      switch manager.state {
      case .unknown: state = "unknown"
      case .resetting: state = "resetting"
      case .unsupported: state = "unsupported"
      case .unauthorized: state = "unauthorized"
      case .poweredOff: state = "poweredOff"
      case .poweredOn: state = "poweredOn"
      @unknown default: state = "unknown"
      }

      self.sendEvent(BLUETOOTH_STATE_CHANGED, [
        "state": state,
        "stateName": state,
        "authorization": "allowedAlways",
        "authorizationName": "allowedAlways",
        "isScanning": self.isScanning,
        "pendingScanStart": false
      ])
    }

    manager.vpBleConnectStateChangeBlock = { [weak self] in
      guard let self = self else { return }

      if manager.isConnected {
        self.sendEvent(CONNECTION_STATUS_CHANGED, [
          "deviceId": self.connectedDeviceId ?? "",
          "status": "connected"
        ])
      } else {
        if let deviceId = self.connectedDeviceId {
          self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
          self.sendEvent(CONNECTION_STATUS_CHANGED, [
            "deviceId": deviceId,
            "status": "disconnected"
          ])
        }
        self.connectedDeviceId = nil
      }
    }
  }

  private func verifyPasswordInternal(password: String, is24Hour: Bool) {
    guard let peripheralManage = self.peripheralManage else { return }

    let timeSetting = VPDeviceTimeSetting()
    let calendar = Calendar.current
    timeSetting.year = Int32(calendar.component(.year, from: Date()))
    timeSetting.month = Int32(calendar.component(.month, from: Date()))
    timeSetting.day = Int32(calendar.component(.day, from: Date()))
    timeSetting.hour = Int32(calendar.component(.hour, from: Date()))
    timeSetting.minute = Int32(calendar.component(.minute, from: Date()))
    timeSetting.second = Int32(calendar.component(.second, from: Date()))
    timeSetting.system = Int32(is24Hour ? 2 : 1)

    peripheralManage.veepooSDKSynchronousPassword(withType: 0, password: password, synchronizationResult: { [weak self] result in
      guard let self = self else { return }

      let status: String
      switch result {
      case 0: status = "CHECK_FAIL"
      case 1:
        status = "CHECK_SUCCESS"
        if let deviceId = self.connectedDeviceId {
          self.sendEvent(DEVICE_READY, [
            "deviceId": deviceId,
            "isOadModel": false
          ])
        }
      case 2: status = "NOT_SET"
      default: status = "UNKNOWN"
      }

      self.sendEvent(PASSWORD_DATA, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": [
          "status": status,
          "password": password,
          "deviceNumber": 0,
          "deviceVersion": "",
          "deviceTestVersion": "",
          "isHaveDrinkData": false,
          "isOpenNightTurnWrist": "unknown",
          "findPhoneFunction": "unknown",
          "wearDetectFunction": "unknown"
        ]
      ])
    }, deviceTimeSetting: timeSetting)
  }

  private func parseFunctionStatus(_ data: Data, index: Int) -> String {
    guard index < data.count else { return "unknown" }
    let value = data[index]
    switch value {
    case 0: return "unsupported"
    case 1: return "support"
    case 2: return "open"
    case 3: return "close"
    default: return "unknown"
    }
  }

  private func registerForBluetoothEvents() {
  }

  private func unregisterForBluetoothEvents() {
  }

  private func cleanup() {
    bleManager?.veepooSDKStopScanDevice()
    bleManager?.veepooSDKDisconnectDevice()
    isScanning = false
    connectedDeviceId = nil
    peripheralModel = nil
  }
}
