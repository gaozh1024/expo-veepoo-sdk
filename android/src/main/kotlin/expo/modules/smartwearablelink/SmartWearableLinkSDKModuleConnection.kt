package expo.modules.smartwearablelink

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.inuker.bluetooth.library.Code
import com.inuker.bluetooth.library.model.BleGattProfile
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.settings.CustomSettingData
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// 连接相关
fun ModuleDefinitionBuilder.defineConnection(module: SmartWearableLinkSDKModule) {
  AsyncFunction("connect") { deviceId: String, options: Map<String, Any?>?, promise: Promise ->
    if (!module.isInitialized) {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    val password = options?.get("password") as? String ?: "0000"
    val is24Hour = options?.get("is24Hour") as? Boolean ?: false
    
    module.emitConnectionStatus(deviceId, "connecting")
    
    manager.connectDevice(
      deviceId,
      object : IConnectResponse {
        override fun connectState(code: Int, profile: BleGattProfile?, isOadModel: Boolean) {
          Log.d("SmartWearableLinkSDKModule", "Connection state: $code for device: $deviceId")
          
          if (code == Code.REQUEST_SUCCESS) {
            module.connectedDeviceId = deviceId
            module.sendEvent(DEVICE_CONNECTED, mapOf("deviceId" to deviceId, "isOadModel" to isOadModel))
            module.emitConnectionStatus(deviceId, "connected", code)
            
            Handler(Looper.getMainLooper()).postDelayed({
              module.verifyPasswordInternal(deviceId, password, is24Hour)
            }, 500)
            
            promise.resolve(null)
          } else {
            module.emitConnectionStatus(deviceId, "error", code)
            promise.reject("CONNECTION_FAILED", "Connection failed with code: $code", null)
          }
        }
      },
      object : INotifyResponse {
        override fun notifyState(state: Int) {
          if (state == Code.REQUEST_SUCCESS) {
            module.emitConnectionStatus(deviceId, "ready")
          }
        }
      }
    )
  }

  AsyncFunction("disconnect") { deviceId: String, promise: Promise ->
    if (!module.isInitialized) {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
      return@AsyncFunction
    }
    
    try {
      val manager = VPOperateManager.getInstance()
      manager?.disconnectWatch(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code == Code.REQUEST_SUCCESS) {
              module.connectedDeviceId = null
              module.sendEvent(DEVICE_DISCONNECTED, mapOf("deviceId" to deviceId))
              module.emitConnectionStatus(deviceId, "disconnected")
              promise.resolve(null)
            } else {
              promise.reject("DISCONNECT_FAILED", "Disconnect failed with code: $code", null)
            }
          }
        }
      )
    } catch (e: Exception) {
      Log.e("SmartWearableLinkSDKModule", "Error disconnecting", e)
      promise.reject("DISCONNECT_ERROR", e.message, e)
    }
  }

  AsyncFunction("getConnectionStatus") { deviceId: String, promise: Promise ->
    val status = if (module.connectedDeviceId == deviceId) "connected" else "disconnected"
    promise.resolve(status)
  }

  AsyncFunction("verifyPassword") { password: String, is24Hour: Boolean, promise: Promise ->
    if (!module.isInitialized) {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    if (module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    manager.confirmDevicePwd(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {}
      },
      object : IPwdDataListener {
        override fun onPwdDataChange(pwdData: PwdData?) {
          val rawStatus = pwdData?.getmStatus()?.toString() ?: "UNKNOWN"
          val status = normalizePasswordStatus(rawStatus)
          val deviceNumber = pwdData?.deviceNumber?.toString() ?: ""
          val deviceVersion = pwdData?.deviceVersion ?: ""
          val resultData = mapOf(
            "status" to status,
            "rawStatus" to rawStatus,
            "password" to password,
            "pwd" to password,
            "deviceNumber" to deviceNumber,
            "deviceVersion" to deviceVersion,
            "deviceTestVersion" to (pwdData?.deviceTestVersion ?: ""),
            "isHaveDrinkData" to (pwdData?.isHaveDrinkData ?: false),
            "isOpenNightTurnWriste" to (pwdData?.isOpenNightTurnWriste?.toString() ?: ""),
            "findPhoneFunction" to (pwdData?.findPhoneFunction?.toString() ?: ""),
            "wearDetectFunction" to (pwdData?.wearDetectFunction?.toString() ?: "")
          )
          
          if (status == "SUCCESS") {
            module.cachedDeviceVersion = deviceVersion
            module.cachedDeviceNumber = deviceNumber
            module.sendEvent(DEVICE_READY, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "isOadModel" to false
            ))
          }
          
          module.sendEvent(PASSWORD_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to resultData
          ))
          
          promise.resolve(resultData)
        }
      },
      object : IDeviceFuctionDataListener {
        override fun onFunctionSupportDataChange(data: FunctionDeviceSupportData?) {
          if (data != null) {
            module.watchday = data.wathcDay
            module.updateFunctionsFromSupportData(data)
            module.sendEvent(DEVICE_FUNCTION, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "data" to module.cachedDeviceFunctions,
              "functions" to module.cachedDeviceFunctions,
              "watchday" to data.wathcDay
            ))
          }
        }
        
        override fun onDeviceFunctionPackage1Report(data: DeviceFunctionPackage1?) {
          if (data != null && module.cachedDeviceFunctions.isNotEmpty()) {
            module.sendEvent(DEVICE_FUNCTION, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "data" to module.cachedDeviceFunctions,
              "functions" to module.cachedDeviceFunctions
            ))
          }
        }
        
        override fun onDeviceFunctionPackage2Report(data: DeviceFunctionPackage2?) {
          if (data != null && module.cachedDeviceFunctions.isNotEmpty()) {
            module.sendEvent(DEVICE_FUNCTION, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "data" to module.cachedDeviceFunctions,
              "functions" to module.cachedDeviceFunctions
            ))
          }
        }
        
        override fun onDeviceFunctionPackage3Report(data: DeviceFunctionPackage3?) {
          if (data != null && module.cachedDeviceFunctions.isNotEmpty()) {
            module.sendEvent(DEVICE_FUNCTION, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "data" to module.cachedDeviceFunctions,
              "functions" to module.cachedDeviceFunctions
            ))
          }
        }
        
        override fun onDeviceFunctionPackage4Report(data: DeviceFunctionPackage4?) {
          if (data != null && module.cachedDeviceFunctions.isNotEmpty()) {
            module.sendEvent(DEVICE_FUNCTION, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "data" to module.cachedDeviceFunctions,
              "functions" to module.cachedDeviceFunctions
            ))
          }
        }
        
        override fun onDeviceFunctionPackage5Report(data: DeviceFunctionPackage5?) {
          if (data != null && module.cachedDeviceFunctions.isNotEmpty()) {
            module.sendEvent(DEVICE_FUNCTION, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "data" to module.cachedDeviceFunctions,
              "functions" to module.cachedDeviceFunctions
            ))
          }
        }
      },
      object : ISocialMsgDataListener {
        override fun onSocialMsgSupportDataChange(data: FunctionSocailMsgData?) {}
        override fun onSocialMsgSupportDataChange2(data: FunctionSocailMsgData?) {}
      },
      object : ICustomSettingDataListener {
        override fun OnSettingDataChange(data: CustomSettingData?) {}
      },
      password,
      is24Hour
    )
  }
}
