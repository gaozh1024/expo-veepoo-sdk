import ExpoModulesCore
import VeepooBleSDK

/// SDK 初始化逻辑
extension VeepooSDKModule {
  func defineInitialization() {
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
  }
}
