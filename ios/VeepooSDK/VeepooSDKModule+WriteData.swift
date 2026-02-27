import ExpoModulesCore

/// 写入与设置相关接口
extension VeepooSDKModule {
  func defineWriteData() {
    AsyncFunction("readAutoMeasureSetting") { (promise: Promise) in
      promise.resolve([])
    }

    AsyncFunction("modifyAutoMeasureSetting") { (_: [String: Any], promise: Promise) in
      promise.resolve(nil)
    }

    AsyncFunction("setLanguage") { (_: Int, promise: Promise) in
      promise.resolve(true)
    }
  }
}
