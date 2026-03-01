package expo.modules.veepoo

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import java.lang.Runnable
import expo.modules.kotlin.Promise
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

  // 心率测试模拟进度
  @Volatile var heartRateTestProgress: Int = 0
  @Volatile var isHeartRateTesting: Boolean = false
  var heartRateTestRunnable: Runnable? = null

  // 血氧测试模拟进度
  @Volatile var bloodOxygenTestProgress: Int = 0
  @Volatile var isBloodOxygenTesting: Boolean = false
  var bloodOxygenTestRunnable: Runnable? = null

  @Volatile var pendingPermissionsPromise: Promise? = null
  @Volatile var requestedPermissions: Array<String>? = null

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

  fun handlePermissionResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
    if (requestCode != PERMISSIONS_REQUEST_CODE) return

    val promise = pendingPermissionsPromise
    pendingPermissionsPromise = null
    requestedPermissions = null

    if (promise == null) return

    val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
    
    if (allGranted) {
      promise.resolve(mapOf(
        "granted" to true,
        "status" to "granted"
      ))
    } else {
      val activity = appContext.currentActivity
      val canAskAgain = permissions.any { perm ->
        activity?.shouldShowRequestPermissionRationale(perm) == true
      }

      promise.resolve(mapOf(
        "granted" to false,
        "status" to if (canAskAgain) "denied" else "never_ask_again",
        "canAskAgain" to canAskAgain
      ))
    }
  }

  companion object {
    const val PERMISSIONS_REQUEST_CODE = 1001
  }
}
