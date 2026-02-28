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
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

fun ModuleDefinitionBuilder.defineTests(module: VeepooSDKModule) {
  AsyncFunction("startHeartRateTest") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }

    var lastHeartValue: Int = 0

    module.startSimulatedHeartRateProgress(
      onProgress = { progress ->
        module.sendEvent(HEART_RATE_TEST_RESULT, mapOf(
          "deviceId" to (module.connectedDeviceId ?: ""),
          "result" to mapOf(
            "state" to "testing",
            "value" to lastHeartValue,
            "progress" to progress
          )
        ))
      },
      onComplete = {
        manager.stopDetectHeart(object : IBleWriteResponse {
          override fun onResponse(code: Int) {}
        })
        module.sendEvent(HEART_RATE_TEST_RESULT, mapOf(
          "deviceId" to (module.connectedDeviceId ?: ""),
          "result" to mapOf(
            "state" to "over",
            "value" to lastHeartValue,
            "progress" to 100
          )
        ))
      }
    )
    
    manager.startDetectHeart(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            module.stopSimulatedHeartRateProgress()
            promise.reject("START_FAILED", "Start detect heart failed: $code", null)
          }
        }
      },
      object : IHeartDataListener {
        override fun onDataChange(heartData: HeartData?) {
          if (heartData != null && module.isHeartRateTesting) {
            val testState = normalizeTestState(heartData.heartStatus?.toString())
            lastHeartValue = heartData.data

            if (testState == "error" || testState == "notWear" || testState == "deviceBusy") {
              module.stopSimulatedHeartRateProgress()
              manager.stopDetectHeart(object : IBleWriteResponse {
                override fun onResponse(code: Int) {}
              })
              
              module.sendEvent(HEART_RATE_TEST_RESULT, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "result" to mapOf(
                  "state" to testState,
                  "value" to heartData.data,
                  "progress" to module.heartRateTestProgress
                )
              ))
            }
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

    module.stopSimulatedHeartRateProgress()
    
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
    
    var lastSystolic: Int = 0
    var lastDiastolic: Int = 0
    var lastTestState: String = "start"
    var progressReached100: Boolean = false
    
    
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
            val rawStatus = bpData.status?.toString()
            val testState = normalizeTestState(rawStatus)
            lastSystolic = bpData.highPressure
            lastDiastolic = bpData.lowPressure
            lastTestState = testState
            
            val progress = bpData.progress
            
            // 发送事件， 进度在走的时候状态应该是 testing
            if (progress > 0 && progress < 100 && testState != "error" && testState != "notWear" && testState != "deviceBusy") {
              module.sendEvent(BLOOD_PRESSURE_TEST_RESULT, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "result" to mapOf(
                  "state" to "testing",
                  "systolic" to lastSystolic,
                  "diastolic" to lastDiastolic,
                  "progress" to progress,
                  "isHaveProgress" to bpData.isHaveProgress
                )
              ))
            }

            // 当进度到达 100% 或出现错误状态时自动停止
            if (progress >= 100 || testState == "error" || testState == "notWear" || testState == "deviceBusy") {
              progressReached100 = true
              manager.stopDetectBP(
                object : IBleWriteResponse {
                  override fun onResponse(code: Int) {}
                },
                EBPDetectModel.DETECT_MODEL_PUBLIC
              )
              
              // 发送最终结果
              module.sendEvent(BLOOD_PRESSURE_TEST_RESULT, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "result" to mapOf(
                  "state" to if (testState == "error" || testState == "notWear" || testState == "deviceBusy") testState else "over",
                  "systolic" to lastSystolic,
                  "diastolic" to lastDiastolic,
                  "progress" to 100,
                  "isHaveProgress" to bpData.isHaveProgress
                )
              ))
            }
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

    var lastSPO2Value: Int = 0
    var lastRateValue: Int = 0

    module.startSimulatedBloodOxygenProgress(
      onProgress = { progress ->
        module.sendEvent(BLOOD_OXYGEN_TEST_RESULT, mapOf(
          "deviceId" to (module.connectedDeviceId ?: ""),
          "result" to mapOf(
            "state" to "testing",
            "value" to lastSPO2Value,
            "rate" to lastRateValue,
            "progress" to progress
          )
        ))
      },
      onComplete = {
        manager.stopDetectSPO2H(
          object : IBleWriteResponse {
            override fun onResponse(code: Int) {}
          },
          object : ISpo2hDataListener {
            override fun onSpO2HADataChange(data: Spo2hData?) {}
          }
        )
        module.sendEvent(BLOOD_OXYGEN_TEST_RESULT, mapOf(
          "deviceId" to (module.connectedDeviceId ?: ""),
          "result" to mapOf(
            "state" to "over",
            "value" to lastSPO2Value,
            "rate" to lastRateValue,
            "progress" to 100
          )
        ))
      }
    )
    
    manager.startDetectSPO2H(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code == Code.REQUEST_SUCCESS) {
            promise.resolve(null)
          } else {
            module.stopSimulatedBloodOxygenProgress()
            promise.reject("START_FAILED", "Start SPO2 failed: $code", null)
          }
        }
      },
      object : ISpo2hDataListener {
        override fun onSpO2HADataChange(spo2hData: Spo2hData?) {
          if (spo2hData != null && module.isBloodOxygenTesting) {
            val testState = normalizeTestState(spo2hData.deviceState?.toString())
            lastSPO2Value = spo2hData.value
            lastRateValue = spo2hData.rateValue

            if (testState == "error" || testState == "notWear" || testState == "deviceBusy") {
              module.stopSimulatedBloodOxygenProgress()
              manager.stopDetectSPO2H(
                object : IBleWriteResponse {
                  override fun onResponse(code: Int) {}
                },
                object : ISpo2hDataListener {
                  override fun onSpO2HADataChange(data: Spo2hData?) {}
                }
              )
              
              module.sendEvent(BLOOD_OXYGEN_TEST_RESULT, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "result" to mapOf(
                  "state" to testState,
                  "value" to spo2hData.value,
                  "rate" to spo2hData.rateValue,
                  "progress" to module.bloodOxygenTestProgress
                )
              ))
            }
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

    module.stopSimulatedBloodOxygenProgress()
    
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
            val testState = when {
              data.oprate == 1 -> "over"
              data.progress <= 0 -> "start"
              data.progress >= 100 -> "over"
              else -> "testing"
            }
            
            module.sendEvent(TEMPERATURE_TEST_RESULT, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "result" to mapOf(
                "state" to testState,
                "value" to data.tempture.toDouble(),
                "deviceState" to data.deviceState,
                "progress" to data.progress,
                "isEnd" to (data.oprate == 1 || data.progress >= 100)
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
    
    var lastBloodGlucose: Float = 0f
    var lastLevel: EBloodGlucoseRiskLevel? = null

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
          lastBloodGlucose = bloodGlucose
          lastLevel = level
          
          val state = when {
            progress <= 0 -> "start"
            progress >= 100 -> "over"
            else -> "testing"
          }
          
          module.sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to mapOf(
              "glucose" to bloodGlucose.toDouble(),
              "progress" to progress,
              "level" to (level?.toString() ?: "UNKNOWN"),
              "state" to state,
              "isEnd" to (progress >= 100),
              "timestamp" to System.currentTimeMillis()
            )
          ))

          // 当进度到达 100% 时自动停止
          if (progress >= 100) {
            manager.stopBloodGlucoseDetect(
              object : IBleWriteResponse {
                override fun onResponse(code: Int) {}
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

        override fun onBloodGlucoseStopDetect() {
          module.sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to mapOf(
              "glucose" to lastBloodGlucose.toDouble(),
              "progress" to 100,
              "level" to (lastLevel?.toString() ?: "UNKNOWN"),
              "state" to "over",
              "status" to "STOPPED",
              "isEnd" to true,
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }

        override fun onDetectError(opt: Int, status: EBloodGlucoseStatus?) {
          module.sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "data" to mapOf(
              "glucose" to lastBloodGlucose.toDouble(),
              "progress" to 100,
              "level" to (lastLevel?.toString() ?: "UNKNOWN"),
              "error" to "Detect error: $status",
              "state" to "error",
              "status" to (status?.toString() ?: "UNKNOWN"),
              "isEnd" to true,
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
