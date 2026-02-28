package expo.modules.veepoo

import android.content.Context
import android.os.Handler
import android.os.Looper
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

// Expo 模块入口
class VeepooSDKModule : Module() {
  @Volatile var isScanning = false
  @Volatile var connectedDeviceId: String? = null
  @Volatile var isInitialized = false
  @Volatile var isPressureMeasuring = false
  val mainHandler = Handler(Looper.getMainLooper())
  val cachedDeviceFunctions = mutableMapOf<String, Map<String, Any?>>()
  @Volatile var cachedDeviceVersion: String = ""
  @Volatile var cachedDeviceNumber: String = ""
  @Volatile var watchday: Int = 3  // 设备存储天数，默认3天
  val context: Context
    get() = appContext.reactContext
      ?: appContext.currentActivity?.applicationContext
      ?: throw IllegalStateException("Unable to get application context")

  override fun definition() = ModuleDefinition {
    Name("VeepooSDK")
    defineEvents()
    defineInitialization(this@VeepooSDKModule)
    definePermissions(this@VeepooSDKModule)
    defineScan(this@VeepooSDKModule)
    defineConnection(this@VeepooSDKModule)
    defineReadData(this@VeepooSDKModule)
    defineWriteData(this@VeepooSDKModule)
    defineTests(this@VeepooSDKModule)
    defineLifecycle(this@VeepooSDKModule)
  }
}
