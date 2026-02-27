import ExpoModulesCore
import VeepooBleSDK

/// 测试与实时测量接口
extension VeepooSDKModule {
  func defineTests() {
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
  }
}
