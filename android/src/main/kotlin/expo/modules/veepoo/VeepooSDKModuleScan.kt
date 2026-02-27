package expo.modules.veepoo

import android.util.Log
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.veepoo.protocol.VPOperateManager
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinition

// 扫描相关
fun ModuleDefinition.defineScan(module: VeepooSDKModule) {
  AsyncFunction("startScan") { _: Map<String, Any?>?, promise: Promise ->
    if (!module.isInitialized) {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
      return@AsyncFunction
    }
    
    if (module.isScanning) {
      promise.resolve(null)
      return@AsyncFunction
    }

    if (!module.hasBluetoothPermissions()) {
      promise.reject("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
      return@AsyncFunction
    }

    if (!module.isBluetoothEnabled()) {
      promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is powered off", null)
      return@AsyncFunction
    }
    
    try {
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      manager.startScanDevice(object : SearchResponse {
        override fun onSearchStarted() {
          Log.d(TAG, "Scan started")
          module.isScanning = true
        }

        override fun onDeviceFounded(result: SearchResult?) {
          result?.let { device ->
            val deviceData = mapOf(
              "id" to device.address,
              "name" to (device.name ?: "Unknown"),
              "rssi" to device.rssi,
              "mac" to device.address,
              "uuid" to device.address
            )
            
            module.sendEvent(DEVICE_FOUND, mapOf(
              "device" to deviceData,
              "timestamp" to System.currentTimeMillis()
            ))
            Log.d(TAG, "Device found: ${device.name}")
          }
        }

        override fun onSearchStopped() {
          Log.d(TAG, "Scan stopped")
          module.isScanning = false
        }

        override fun onSearchCanceled() {
          Log.d(TAG, "Scan canceled")
          module.isScanning = false
        }
      })
      
      promise.resolve(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error starting scan", e)
      promise.reject("SCAN_ERROR", e.message, e)
    }
  }

  AsyncFunction("stopScan") { promise: Promise ->
    if (!module.isInitialized) {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
      return@AsyncFunction
    }
    
    try {
      val manager = VPOperateManager.getInstance()
      manager?.stopScanDevice()
      module.isScanning = false
      promise.resolve(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping scan", e)
      promise.reject("SCAN_ERROR", e.message, e)
    }
  }
}
