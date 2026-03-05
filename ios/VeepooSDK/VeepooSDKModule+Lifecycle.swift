import ExpoModulesCore

/// 监听器生命周期
extension VeepooSDKModule {
  func defineLifecycle() {
    OnStartObserving {
      self.emitBluetoothStatus()
    }

    OnDestroy {
      self.cleanup()
    }
  }
}
