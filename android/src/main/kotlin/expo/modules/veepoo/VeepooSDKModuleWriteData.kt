package expo.modules.veepoo

import android.util.Log
import com.inuker.bluetooth.library.Code
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.IAutoMeasureSettingDataListener
import com.veepoo.protocol.model.datas.AutoMeasureData
import com.veepoo.protocol.model.enums.EAutoMeasureType
import com.veepoo.protocol.model.settings.VpSpGetUtil
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

private fun autoMeasureDataToMap(data: AutoMeasureData): Map<String, Any> {
  return mapOf(
    "protocolType" to data.protocolType,
    "funType" to data.funType.value,
    "isSwitchOpen" to data.isSwitchOpen,
    "stepUnit" to data.stepUnit,
    "isSlotModify" to data.isSlotModify,
    "isIntervalModify" to data.isIntervalModify,
    "supportStartMinute" to data.supportStartMinute,
    "supportEndMinute" to data.supportEndMinute,
    "measureInterval" to data.measureInterval,
    "currentStartMinute" to data.currentStartMinute,
    "currentEndMinute" to data.currentEndMinute
  )
}

private fun mapToAutoMeasureData(map: Map<String, Any?>): AutoMeasureData {
  val data = AutoMeasureData()
  
  (map["protocolType"] as? Number)?.let { data.protocolType = it.toInt() }
  (map["funType"] as? Number)?.let { 
    EAutoMeasureType.fromValue(it.toInt())?.let { type -> data.funType = type }
  }
  (map["isSwitchOpen"] as? Boolean)?.let { data.isSwitchOpen = it }
  (map["stepUnit"] as? Number)?.let { data.stepUnit = it.toInt() }
  (map["isSlotModify"] as? Boolean)?.let { data.isSlotModify = it }
  (map["isIntervalModify"] as? Boolean)?.let { data.isIntervalModify = it }
  (map["supportStartMinute"] as? Number)?.let { data.supportStartMinute = it.toInt() }
  (map["supportEndMinute"] as? Number)?.let { data.supportEndMinute = it.toInt() }
  (map["measureInterval"] as? Number)?.let { data.measureInterval = it.toInt() }
  (map["currentStartMinute"] as? Number)?.let { data.currentStartMinute = it.toInt() }
  (map["currentEndMinute"] as? Number)?.let { data.currentEndMinute = it.toInt() }
  
  return data
}

fun ModuleDefinitionBuilder.defineWriteData(module: VeepooSDKModule) {
  AsyncFunction("readAutoMeasureSetting") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val context = module.appContext.reactContext ?: run {
      promise.reject("CONTEXT_ERROR", "Cannot get app context", null)
      return@AsyncFunction
    }
    
    if (!VpSpGetUtil.getVpSpVariInstance(context).isSupportAutoMeasure) {
      promise.reject("UNSUPPORTED", "Device does not support auto measure setting", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "readAutoMeasureSetting: reading auto measure settings")
    
    manager.readAutoMeasureSettingData(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code != Code.REQUEST_SUCCESS) {
            Log.e(TAG, "readAutoMeasureSetting: command failed with code $code")
          }
        }
      },
      object : IAutoMeasureSettingDataListener {
        override fun onSettingDataChange(autoMeasureDataList: MutableList<AutoMeasureData>?) {
          if (autoMeasureDataList != null) {
            Log.d(TAG, "readAutoMeasureSetting: received ${autoMeasureDataList.size} settings")
            val result = autoMeasureDataList.map { autoMeasureDataToMap(it) }
            promise.resolve(result)
          } else {
            promise.reject("READ_FAILED", "Auto measure data list is null", null)
          }
        }
        
        override fun onSettingDataChangeFail() {
          Log.e(TAG, "readAutoMeasureSetting: onSettingDataChangeFail")
          promise.reject("READ_FAILED", "Read auto measure setting failed", null)
        }
        
        override fun onSettingDataChangeSuccess() {
          Log.d(TAG, "readAutoMeasureSetting: onSettingDataChangeSuccess")
        }
      }
    )
  }

  AsyncFunction("modifyAutoMeasureSetting") { setting: Map<String, Any?>, promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val context = module.appContext.reactContext ?: run {
      promise.reject("CONTEXT_ERROR", "Cannot get app context", null)
      return@AsyncFunction
    }
    
    if (!VpSpGetUtil.getVpSpVariInstance(context).isSupportAutoMeasure) {
      promise.reject("UNSUPPORTED", "Device does not support auto measure setting", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "modifyAutoMeasureSetting: modifying auto measure setting")
    
    val autoMeasureData = mapToAutoMeasureData(setting)
    
    manager.setAutoMeasureSettingData(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code != Code.REQUEST_SUCCESS) {
            Log.e(TAG, "modifyAutoMeasureSetting: command failed with code $code")
          }
        }
      },
      autoMeasureData,
      object : IAutoMeasureSettingDataListener {
        override fun onSettingDataChange(autoMeasureDataList: MutableList<AutoMeasureData>?) {
          if (autoMeasureDataList != null) {
            Log.d(TAG, "modifyAutoMeasureSetting: received ${autoMeasureDataList.size} settings")
            val result = autoMeasureDataList.map { autoMeasureDataToMap(it) }
            promise.resolve(result)
          } else {
            promise.resolve(emptyList<Any>())
          }
        }
        
        override fun onSettingDataChangeFail() {
          Log.e(TAG, "modifyAutoMeasureSetting: onSettingDataChangeFail")
          promise.reject("SET_FAILED", "Set auto measure setting failed", null)
        }
        
        override fun onSettingDataChangeSuccess() {
          Log.d(TAG, "modifyAutoMeasureSetting: onSettingDataChangeSuccess")
        }
      }
    )
  }

  AsyncFunction("setLanguage") { _: Int, promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    promise.resolve(true)
  }
}
