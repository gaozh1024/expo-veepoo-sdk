package expo.modules.smartwearablelink

import android.util.Log
import com.veepoo.protocol.VPOperateManager
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// SDK 初始化
fun ModuleDefinitionBuilder.defineInitialization(module: SmartWearableLinkSDKModule) {
  AsyncFunction("init") { promise: Promise ->
    try {
      val manager = VPOperateManager.getInstance()
      if (manager == null) {
        promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Smart Wearable Link SDK", null)
        return@AsyncFunction
      }
      
      manager.init(module.context)
      module.isInitialized = true
      Log.d(TAG, "Smart Wearable Link SDK initialized successfully")
      module.emitBluetoothStatus()
      promise.resolve(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error initializing Smart Wearable Link SDK", e)
      promise.reject("INIT_ERROR", e.message, e)
    }
  }
}
