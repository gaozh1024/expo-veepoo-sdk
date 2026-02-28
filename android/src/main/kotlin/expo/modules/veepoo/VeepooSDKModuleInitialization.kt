package expo.modules.veepoo

import android.util.Log
import com.veepoo.protocol.VPOperateManager
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// SDK 初始化
fun ModuleDefinitionBuilder.defineInitialization(module: VeepooSDKModule) {
  AsyncFunction("init") { promise: Promise ->
    try {
      val manager = VPOperateManager.getInstance()
      if (manager == null) {
        promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Veepoo SDK", null)
        return@AsyncFunction
      }
      
      manager.init(module.context)
      module.isInitialized = true
      Log.d(TAG, "Veepoo SDK initialized successfully")
      promise.resolve(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error initializing Veepoo SDK", e)
      promise.reject("INIT_ERROR", e.message, e)
    }
  }
}
