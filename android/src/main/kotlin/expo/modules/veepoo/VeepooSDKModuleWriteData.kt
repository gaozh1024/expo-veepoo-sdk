package expo.modules.veepoo

import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// 写入与设置
fun ModuleDefinitionBuilder.defineWriteData(module: VeepooSDKModule) {
  AsyncFunction("readAutoMeasureSetting") { promise: Promise ->
    promise.resolve(emptyList<Any>())
  }

  AsyncFunction("modifyAutoMeasureSetting") { _: Map<String, Any?>, promise: Promise ->
    promise.resolve(null)
  }

  AsyncFunction("setLanguage") { _: Int, promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    promise.resolve(true)
  }
}
