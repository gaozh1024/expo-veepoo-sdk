package expo.modules.smartwearablelink

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

fun ModuleDefinitionBuilder.definePermissions(module: SmartWearableLinkSDKModule) {
  AsyncFunction("isBluetoothEnabled") { promise: Promise ->
    promise.resolve(module.isBluetoothEnabled())
  }

  AsyncFunction("requestPermissions") { promise: Promise ->
    try {
      val context = module.context

      if (module.hasBluetoothPermissions()) {
        module.emitBluetoothStatus()
        promise.resolve(mapOf(
          "granted" to true,
          "status" to "granted"
        ))
        return@AsyncFunction
      }

      val activity = module.appContext.currentActivity
      if (activity == null) {
        promise.reject("NO_ACTIVITY", "Activity is not available", null)
        return@AsyncFunction
      }

      if (activity !is PermissionAwareActivity) {
        promise.reject("INVALID_ACTIVITY", "Activity does not support permission requests", null)
        return@AsyncFunction
      }

      val permissionsToRequest = getBluetoothPermissionsToRequest(context)

      if (permissionsToRequest.isEmpty()) {
        module.emitBluetoothStatus()
        promise.resolve(mapOf(
          "granted" to true,
          "status" to "granted"
        ))
        return@AsyncFunction
      }

      module.pendingPermissionsPromise = promise
      module.requestedPermissions = permissionsToRequest.toTypedArray()

      val listener = PermissionListener { requestCode, permissions, grantResults ->
        module.handlePermissionResult(requestCode, permissions, grantResults)
        true
      }

      (activity as PermissionAwareActivity).requestPermissions(
        permissionsToRequest.toTypedArray(),
        SmartWearableLinkSDKModule.PERMISSIONS_REQUEST_CODE,
        listener
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error requesting permissions", e)
      module.pendingPermissionsPromise = null
      module.requestedPermissions = null
      promise.reject("PERMISSION_ERROR", e.message, e)
    }
  }
}

fun getBluetoothPermissionsToRequest(context: android.content.Context): List<String> {
  val permissions = mutableListOf<String>()

  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN)
      != PackageManager.PERMISSION_GRANTED) {
      permissions.add(Manifest.permission.BLUETOOTH_SCAN)
    }
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
      != PackageManager.PERMISSION_GRANTED) {
      permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
    }
  }

  if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
    ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH)
    != PackageManager.PERMISSION_GRANTED) {
    permissions.add(Manifest.permission.BLUETOOTH)
  }

  return permissions
}
