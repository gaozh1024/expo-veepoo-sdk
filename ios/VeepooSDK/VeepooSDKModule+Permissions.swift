import ExpoModulesCore
import CoreBluetooth

/// 蓝牙状态与权限
extension VeepooSDKModule {
  func definePermissions() {
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
  }
}
