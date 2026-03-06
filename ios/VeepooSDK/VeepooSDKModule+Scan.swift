import ExpoModulesCore

extension VeepooSDKModule {
  func defineScan() {
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

      let timeout = options?["timeout"] as? Int ?? 10000
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeout) / 1000) { [weak self] in
        guard let self = self, self.isScanning else { return }
        self.bleManager?.veepooSDKStopScanDevice()
        self.isScanning = false
        self.pendingScanStart = false
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
  }
}
