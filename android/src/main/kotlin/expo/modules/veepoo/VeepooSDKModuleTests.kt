package expo.modules.veepoo

import com.inuker.bluetooth.library.Code
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.*
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.EBPDetectModel
import com.veepoo.protocol.model.enums.EBloodGlucoseRiskLevel
import com.veepoo.protocol.model.enums.EBloodGlucoseStatus
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinition

// 测试与实时测量
fun ModuleDefinition.defineTests(module: VeepooSDKModule) {
  AsyncFunction("startHeartRateTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    manager.startDetectHeart(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("START_FAILED", "Start detect heart failed: $code", null)
          }
        }
      },
      object : IHeartDataListener {
        override fun onDataChange(heartData: HeartData?) {
          if (heartData != null) {
            val testState = heartData.heartStatus?.toString() ?: "unknown"
            
            module.sendEvent(HEART_RATE_TEST_RESULT, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "result" to mapOf(
                "state" to testState,
                "value" to heartData.data
              )
            ))
          }
        }
      }
    )
  }

  AsyncFunction("stopHeartRateTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance()
    manager?.stopDetectHeart(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("STOP_FAILED", "Stop detect heart failed: $code", null)
          }
        }
      }
    )
  }

  AsyncFunction("startBloodPressureTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    manager.startDetectBP(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("START_FAILED", "Start BP failed: $code", null)
          }
        }
      },
      object : IBPDetectDataListener {
        override fun onDataChange(bpData: BpData?) {
          if (bpData != null) {
            val testState = bpData.status?.toString() ?: "unknown"
            
            module.sendEvent(BLOOD_PRESSURE_TEST_RESULT, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "result" to mapOf(
                "state" to testState,
                "systolic" to bpData.highPressure,
                "diastolic" to bpData.lowPressure,
                "progress" to bpData.progress,
                "isHaveProgress" to bpData.isHaveProgress
              )
            ))
          }
        }
      },
      EBPDetectModel.DETECT_MODEL_PUBLIC
    )
  }

  AsyncFunction("stopBloodPressureTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance()
    manager?.stopDetectBP(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("STOP_FAILED", "Stop BP failed: $code", null)
          }
        }
      },
      EBPDetectModel.DETECT_MODEL_PUBLIC
    )
  }

  AsyncFunction("startBloodOxygenTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    manager.startDetectSPO2H(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("START_FAILED", "Start SPO2 failed: $code", null)
          }
        }
      },
      object : ISpo2hDataListener {
        override fun onSpO2HADataChange(spo2hData: Spo2hData?) {
          if (spo2hData != null) {
            val testState = if (spo2hData.isChecking) "testing" else "over"
            
            module.sendEvent(BLOOD_OXYGEN_TEST_RESULT, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "result" to mapOf(
                "state" to testState,
                "value" to spo2hData.value,
                "rate" to spo2hData.rateValue,
                "progress" to spo2hData.checkingProgress
              )
            ))
          }
        }
      },
      object : ILightDataCallBack {
        override fun onGreenLightDataChange(data: IntArray?) {}
      }
    )
  }

  AsyncFunction("stopBloodOxygenTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance()
    manager?.stopDetectSPO2H(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("STOP_FAILED", "Stop SpO2 failed: $code", null)
          }
        }
      },
      object : ISpo2hDataListener {
        override fun onSpO2HADataChange(data: Spo2hData?) {}
      }
    )
  }

  AsyncFunction("startTemperatureTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    manager.startDetectTempture(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("START_FAILED", "Start Temp failed: $code", null)
          }
        }
      },
      object : ITemptureDetectDataListener {
        override fun onDataChange(data: TemptureDetectData?) {
          if (data != null) {
            val testState = if (data.oprate == 1) "over" else "testing"
            
            module.sendEvent(TEMPERATURE_TEST_RESULT, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "result" to mapOf(
                "state" to testState,
                "value" to data.tempture.toDouble(),
                "deviceState" to data.deviceState,
                "progress" to data.progress
              )
            ))
          }
        }
      }
    )
  }

  AsyncFunction("stopTemperatureTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance()
    manager?.stopDetectTempture(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("STOP_FAILED", "Stop Tempture failed: $code", null)
          }
        }
      },
      object : ITemptureDetectDataListener {
        override fun onDataChange(data: TemptureDetectData?) {}
      }
    )
  }

  AsyncFunction("startStressTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    if (module.isPressureMeasuring) {
      promise.reject("ALREADY_MEASURING", "Pressure measurement is already in progress", null)
      return@AsyncFunction
    }
    
    module.isPressureMeasuring = true
    module.startPressureLoop(promise)
  }

  AsyncFunction("stopStressTest") { promise: Promise ->
    module.isPressureMeasuring = false
    promise.resolve(null)
  }

  AsyncFunction("startBloodGlucoseTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    manager.startBloodGlucoseDetect(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("START_FAILED", "Start blood glucose detect failed: $code", null)
          }
        }
      },
      object : IBloodGlucoseChangeListener {
        override fun onBloodGlucoseDetect(progress: Int, bloodGlucose: Float, level: EBloodGlucoseRiskLevel?) {
          module.sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to mapOf(
              "glucose" to bloodGlucose.toDouble(),
              "progress" to progress,
              "level" to (level?.toString() ?: "UNKNOWN"),
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }

        override fun onBloodGlucoseStopDetect() {
          module.sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to mapOf(
              "progress" to 100,
              "status" to "STOPPED",
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }

        override fun onDetectError(opt: Int, status: EBloodGlucoseStatus?) {
          module.sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to mapOf(
              "error" to "Detect error: $status",
              "status" to (status?.toString() ?: "UNKNOWN"),
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }
        
        override fun onBloodGlucoseAdjustingSettingSuccess(isSuccess: Boolean, adjustingValue: Float) {}
        override fun onBloodGlucoseAdjustingSettingFailed() {}
        override fun onBloodGlucoseAdjustingReadSuccess(isOpen: Boolean, adjustingValue: Float) {}
        override fun onBloodGlucoseAdjustingReadFailed() {}
        override fun onBGMultipleAdjustingReadSuccess(isSuccess: Boolean, info1: MealInfo?, info2: MealInfo?, info3: MealInfo?) {}
        override fun onBGMultipleAdjustingReadFailed() {}
        override fun onBGMultipleAdjustingSettingSuccess() {}
        override fun onBGMultipleAdjustingSettingFailed() {}
      }
    )
  }

  AsyncFunction("stopBloodGlucoseTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance()
    manager?.stopBloodGlucoseDetect(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            promise.reject("STOP_FAILED", "Stop blood glucose detect failed: $code", null)
          }
        }
      },
      object : IBloodGlucoseChangeListener {
        override fun onBloodGlucoseDetect(progress: Int, bloodGlucose: Float, level: EBloodGlucoseRiskLevel?) {}
        override fun onBloodGlucoseStopDetect() {}
        override fun onDetectError(opt: Int, status: EBloodGlucoseStatus?) {}
        override fun onBloodGlucoseAdjustingSettingSuccess(isSuccess: Boolean, adjustingValue: Float) {}
        override fun onBloodGlucoseAdjustingSettingFailed() {}
        override fun onBloodGlucoseAdjustingReadSuccess(isOpen: Boolean, adjustingValue: Float) {}
        override fun onBloodGlucoseAdjustingReadFailed() {}
        override fun onBGMultipleAdjustingReadSuccess(isSuccess: Boolean, info1: MealInfo?, info2: MealInfo?, info3: MealInfo?) {}
        override fun onBGMultipleAdjustingReadFailed() {}
        override fun onBGMultipleAdjustingSettingSuccess() {}
        override fun onBGMultipleAdjustingSettingFailed() {}
      }
    )
  }
}
