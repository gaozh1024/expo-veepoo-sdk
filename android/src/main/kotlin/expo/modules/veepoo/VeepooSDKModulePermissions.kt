package expo.modules.veepoo

import android.util.Log
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// 权限与蓝牙状态
fun ModuleDefinitionBuilder.definePermissions(module: VeepooSDKModule) {
  AsyncFunction("isBluetoothEnabled") { promise: Promise ->
    promise.resolve(module.isBluetoothEnabled())
  }

  AsyncFunction("requestPermissions") { promise: Promise ->
    try {
      if (module.hasBluetoothPermissions()) {
        promise.resolve(true)
      } else {
        promise.reject("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error checking permissions", e)
      promise.reject("PERMISSION_ERROR", e.message, e)
    }
  }
}
