import ExpoModulesCore

/// 监听器生命周期
extension VeepooSDKModule {
  func defineLifecycle() {
    _ = OnStartObserving {
      self.emitBluetoothStatus()
    }

    _ = OnDestroy {
      self.cleanup()
    }
  }
}
