#if targetEnvironment(simulator)
import ExpoModulesCore

private enum VeepooSimulatorEvent {
  static let deviceFound = "deviceFound"
  static let deviceConnected = "deviceConnected"
  static let deviceDisconnected = "deviceDisconnected"
  static let deviceConnectStatus = "deviceConnectStatus"
  static let connectionStatusChanged = "connectionStatusChanged"
  static let deviceReady = "deviceReady"
  static let bluetoothStateChanged = "bluetoothStateChanged"
  static let deviceFunction = "deviceFunction"
  static let deviceVersion = "deviceVersion"
  static let passwordData = "passwordData"
  static let batteryData = "batteryData"
  static let heartRateTestResult = "heartRateTestResult"
  static let bloodPressureTestResult = "bloodPressureTestResult"
  static let bloodOxygenTestResult = "bloodOxygenTestResult"
  static let temperatureTestResult = "temperatureTestResult"
  static let stressData = "stressData"
  static let bloodGlucoseData = "bloodGlucoseData"
  static let sleepData = "sleepData"
  static let sportStepData = "sportStepData"
  static let readOriginProgress = "readOriginProgress"
  static let readOriginComplete = "readOriginComplete"
  static let originFiveMinuteData = "originFiveMinuteData"
  static let originHalfHourData = "originHalfHourData"
  static let originSpo2Data = "originSpo2Data"
  static let socialMsgData = "socialMsgData"
  static let error = "error"
}

public class VeepooSDKModule: Module {
  private var connectedDeviceId: String?
  private var isInitialized = false
  private var isScanning = false

  private func permissionsResult(status: String, granted: Bool, canAskAgain: Bool) -> [String: Any] {
    [
      "granted": granted,
      "status": status,
      "canAskAgain": canAskAgain
    ]
  }

  private func emitBluetoothStatus() {
    sendEvent(VeepooSimulatorEvent.bluetoothStateChanged, [
      "state": "poweredOn",
      "stateName": "poweredOn",
      "authorization": "allowedAlways",
      "authorizationName": "allowedAlways",
      "isScanning": isScanning,
      "pendingScanStart": false
    ])
  }

  private func emitConnectionStatus(deviceId: String, status: String) {
    let payload: [String: Any] = [
      "deviceId": deviceId,
      "status": status
    ]
    sendEvent(VeepooSimulatorEvent.deviceConnectStatus, payload)
    sendEvent(VeepooSimulatorEvent.connectionStatusChanged, payload)
  }

  private func simulatorDeviceFunctions() -> [String: Any] {
    [
      "package1": [String: Any](),
      "package2": [String: Any](),
      "package3": [String: Any](),
      "package4": [String: Any](),
      "package5": [String: Any]()
    ]
  }

  private func simulatorDeviceVersion() -> [String: Any] {
    [
      "hardwareVersion": "simulator",
      "firmwareVersion": "simulator",
      "softwareVersion": "simulator",
      "deviceNumber": "simulator",
      "newVersion": "",
      "description": "iOS Simulator"
    ]
  }

  public func definition() -> ModuleDefinition {
    Name("VeepooSDK")

    Events(
      VeepooSimulatorEvent.deviceFound,
      VeepooSimulatorEvent.deviceConnected,
      VeepooSimulatorEvent.deviceDisconnected,
      VeepooSimulatorEvent.deviceConnectStatus,
      VeepooSimulatorEvent.connectionStatusChanged,
      VeepooSimulatorEvent.deviceReady,
      VeepooSimulatorEvent.bluetoothStateChanged,
      VeepooSimulatorEvent.deviceFunction,
      VeepooSimulatorEvent.deviceVersion,
      VeepooSimulatorEvent.passwordData,
      VeepooSimulatorEvent.batteryData,
      VeepooSimulatorEvent.heartRateTestResult,
      VeepooSimulatorEvent.bloodPressureTestResult,
      VeepooSimulatorEvent.bloodOxygenTestResult,
      VeepooSimulatorEvent.temperatureTestResult,
      VeepooSimulatorEvent.stressData,
      VeepooSimulatorEvent.bloodGlucoseData,
      VeepooSimulatorEvent.sleepData,
      VeepooSimulatorEvent.sportStepData,
      VeepooSimulatorEvent.readOriginProgress,
      VeepooSimulatorEvent.readOriginComplete,
      VeepooSimulatorEvent.originFiveMinuteData,
      VeepooSimulatorEvent.originHalfHourData,
      VeepooSimulatorEvent.originSpo2Data,
      VeepooSimulatorEvent.socialMsgData,
      VeepooSimulatorEvent.error
    )

    AsyncFunction("init") { (promise: Promise) in
      self.isInitialized = true
      self.emitBluetoothStatus()
      promise.resolve(nil)
    }

    AsyncFunction("isBluetoothEnabled") { (promise: Promise) in
      promise.resolve(true)
    }

    AsyncFunction("requestPermissions") { (promise: Promise) in
      promise.resolve(self.permissionsResult(status: "granted", granted: true, canAskAgain: false))
    }

    AsyncFunction("startScan") { (_: [String: Any]?, promise: Promise) in
      self.isInitialized = true
      self.isScanning = true
      self.emitBluetoothStatus()
      promise.resolve(nil)
    }

    AsyncFunction("stopScan") { (promise: Promise) in
      self.isScanning = false
      self.emitBluetoothStatus()
      promise.resolve(nil)
    }

    AsyncFunction("connect") { (deviceId: String, _: [String: Any]?, promise: Promise) in
      self.connectedDeviceId = deviceId
      self.emitConnectionStatus(deviceId: deviceId, status: "ready")
      self.sendEvent(VeepooSimulatorEvent.deviceConnected, [
        "deviceId": deviceId,
        "isOadModel": false
      ])
      self.sendEvent(VeepooSimulatorEvent.deviceReady, [
        "deviceId": deviceId,
        "isOadModel": false
      ])
      promise.resolve(nil)
    }

    AsyncFunction("disconnect") { (deviceId: String, promise: Promise) in
      self.connectedDeviceId = nil
      self.emitConnectionStatus(deviceId: deviceId, status: "disconnected")
      self.sendEvent(VeepooSimulatorEvent.deviceDisconnected, ["deviceId": deviceId])
      promise.resolve(nil)
    }

    AsyncFunction("getConnectionStatus") { (deviceId: String, promise: Promise) in
      promise.resolve(self.connectedDeviceId == deviceId ? "ready" : "disconnected")
    }

    AsyncFunction("verifyPassword") { (password: String, _: Bool, promise: Promise) in
      let payload: [String: Any] = [
        "status": "SUCCESS",
        "password": password,
        "deviceNumber": "simulator",
        "deviceVersion": "simulator"
      ]
      self.sendEvent(VeepooSimulatorEvent.passwordData, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": payload
      ])
      promise.resolve(payload)
    }

    AsyncFunction("readBattery") { (promise: Promise) in
      let payload: [String: Any] = [
        "level": 100,
        "percent": 100,
        "powerModel": 0,
        "state": 1,
        "bat": 0,
        "isPercent": true,
        "isLowBattery": false
      ]
      self.sendEvent(VeepooSimulatorEvent.batteryData, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": payload
      ])
      promise.resolve(payload)
    }

    AsyncFunction("syncPersonalInfo") { (_: [String: Any], promise: Promise) in
      promise.resolve(true)
    }

    AsyncFunction("readDeviceFunctions") { (promise: Promise) in
      let payload = self.simulatorDeviceFunctions()
      self.sendEvent(VeepooSimulatorEvent.deviceFunction, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": payload
      ])
      promise.resolve(payload)
    }

    AsyncFunction("readSocialMsgData") { (promise: Promise) in
      let payload = [String: Any]()
      self.sendEvent(VeepooSimulatorEvent.socialMsgData, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": payload
      ])
      promise.resolve(payload)
    }

    AsyncFunction("readDeviceVersion") { (promise: Promise) in
      let payload = self.simulatorDeviceVersion()
      self.sendEvent(VeepooSimulatorEvent.deviceVersion, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": payload
      ])
      promise.resolve(payload)
    }

    AsyncFunction("startReadOriginData") { (promise: Promise) in
      self.sendEvent(VeepooSimulatorEvent.readOriginComplete, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": [Any]()
      ])
      promise.resolve(nil)
    }

    AsyncFunction("readSleepData") { (_: String?, promise: Promise) in
      promise.resolve([Any]())
    }

    AsyncFunction("readSportStepData") { (date: String?, promise: Promise) in
      promise.resolve([
        "date": date ?? "",
        "stepCount": 0,
        "distance": 0,
        "calories": 0
      ])
    }

    AsyncFunction("readOriginData") { (_: Int, promise: Promise) in
      promise.resolve([Any]())
    }

    AsyncFunction("readDeviceAllData") { (promise: Promise) in
      self.sendEvent(VeepooSimulatorEvent.readOriginComplete, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": [Any]()
      ])
      promise.resolve(true)
    }

    AsyncFunction("readDaySummaryData") { (_: Int, promise: Promise) in
      promise.resolve([
        "date": "",
        "allStep": 0,
        "sportList": [Any](),
        "rateList": [Any](),
        "bpList": [Any]()
      ])
    }

    AsyncFunction("readAutoMeasureSetting") { (promise: Promise) in
      promise.resolve([Any]())
    }

    AsyncFunction("modifyAutoMeasureSetting") { (setting: [String: Any], promise: Promise) in
      promise.resolve(setting)
    }

    AsyncFunction("setLanguage") { (_: String, promise: Promise) in
      promise.resolve(true)
    }

    AsyncFunction("startHeartRateTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("stopHeartRateTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("startBloodPressureTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("stopBloodPressureTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("startBloodOxygenTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("stopBloodOxygenTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("startTemperatureTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("stopTemperatureTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("startStressTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("stopStressTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("startBloodGlucoseTest") { (promise: Promise) in promise.resolve(nil) }
    AsyncFunction("stopBloodGlucoseTest") { (promise: Promise) in promise.resolve(nil) }
  }
}
#endif
