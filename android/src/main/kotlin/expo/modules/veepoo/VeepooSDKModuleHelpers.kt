package expo.modules.veepoo

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IDeviceManualDetectDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.model.datas.BloodComponentManualData
import com.veepoo.protocol.model.datas.BloodGlucoseManualData
import com.veepoo.protocol.model.datas.BloodOxygenManualData
import com.veepoo.protocol.model.datas.BloodPressureManualData
import com.veepoo.protocol.model.datas.BodyTemperatureManualData
import com.veepoo.protocol.model.datas.EmotionManualData
import com.veepoo.protocol.model.datas.FatigueManualData
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.HeartRateManualData
import com.veepoo.protocol.model.datas.HrvManualData
import com.veepoo.protocol.model.datas.MetoManualData
import com.veepoo.protocol.model.datas.MiniCheckupManualData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.datas.PressureManualData
import com.veepoo.protocol.model.datas.SkinConductanceManualData
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.enums.DeviceManualDataType
import com.veepoo.protocol.model.settings.CustomSettingData
import expo.modules.kotlin.Promise

// 模块基础工具方法
fun VeepooSDKModule.isBluetoothEnabled(): Boolean {
  val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
  return manager?.adapter?.isEnabled == true
}

fun VeepooSDKModule.hasBluetoothPermissions(): Boolean {
  return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
      context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
  } else {
    context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
  }
}

// 密码状态标准化
fun normalizePasswordStatus(status: String): String {
  val normalized = status.lowercase()
  return when {
    normalized.contains("success") -> "SUCCESS"
    normalized.contains("fail") -> "FAILED"
    else -> "UNKNOWN"
  }
}

// 功能状态标准化
fun toSupportedStatus(value: Any?): String {
  return when (value) {
    is Boolean -> if (value) "support" else "unsupported"
    is Number -> if (value.toInt() > 0) "support" else "unsupported"
    is String -> {
      val normalized = value.lowercase()
      if (normalized.contains("support") || normalized == "1" || normalized == "open") "support" else "unsupported"
    }
    else -> "unsupported"
  }
}

// 统一测试状态转换
fun normalizeTestState(rawState: String?): String {
  if (rawState == null) return "unknown"
  val normalized = rawState.lowercase()
  return when {
    normalized.contains("idle") || normalized == "free" -> "idle"
    normalized.contains("start") || normalized == "begin" -> "start"
    normalized.contains("state_bp_normal") || normalized.contains("bp_normal") -> "testing"
    normalized.contains("state_heart_detect") || normalized.contains("heart_detect") || normalized.contains("heart_normal") -> "testing"
    normalized.contains("testing") || normalized == "detect" || normalized == "detect_sp" || normalized.contains("progress") -> "testing"
    normalized.contains("over") || normalized.contains("finish") || normalized.contains("complete") || normalized.contains("success") -> "over"
    normalized.contains("notwear") || normalized.contains("unpass_wear") || normalized.contains("nowear") -> "notWear"
    normalized.contains("busy") || normalized.contains("devicebusy") -> "deviceBusy"
    normalized.contains("error") || normalized.contains("fail") || normalized.contains("charging") || normalized.contains("charg_low") -> "error"
    else -> normalized
  }
}

// 功能包映射到统一结构
fun VeepooSDKModule.updateFunctionsFromSupportData(data: FunctionDeviceSupportData) {
  val package1 = mapOf(
    "bloodPressure" to toSupportedStatus(data.bp),
    "heartRateDetect" to toSupportedStatus(data.heartDetect),
    "spoH" to toSupportedStatus(data.spo2H),
    "temperatureFunction" to toSupportedStatus(data.temperatureFunction)
  )
  val package2 = mapOf(
    "ecgFunction" to toSupportedStatus(data.ecg),
    "precisionSleep" to toSupportedStatus(data.precisionSleep),
    "hrvFunction" to "unsupported"
  )
  val package3 = mapOf(
    "stressFunction" to toSupportedStatus(data.stress),
    "bloodGlucose" to "unsupported",
    "bloodComponent" to "unsupported",
    "bodyComponent" to "unsupported"
  )
  cachedDeviceFunctions["package1"] = package1
  cachedDeviceFunctions["package2"] = package2
  cachedDeviceFunctions["package3"] = package3
}

fun VeepooSDKModule.verifyPasswordInternal(deviceId: String, password: String, is24Hour: Boolean) {
  val manager = VPOperateManager.getInstance() ?: return
  
  manager.confirmDevicePwd(
    object : IBleWriteResponse {
      override fun onResponse(code: Int) {}
    },
    object : IPwdDataListener {
      override fun onPwdDataChange(pwdData: PwdData?) {
        val status = pwdData?.getmStatus()?.toString() ?: "UNKNOWN"
        
        if (status.contains("SUCCESS")) {
          sendEvent(DEVICE_READY, mapOf(
            "deviceId" to deviceId,
            "isOadModel" to false
          ))
        }
        
        sendEvent(PASSWORD_DATA, mapOf(
          "deviceId" to deviceId,
          "data" to mapOf(
            "status" to status,
            "password" to password,
            "deviceNumber" to (pwdData?.deviceNumber?.toString() ?: ""),
            "deviceVersion" to (pwdData?.deviceVersion ?: "")
          )
        ))
      }
    },
    object : IDeviceFuctionDataListener {
      override fun onFunctionSupportDataChange(data: FunctionDeviceSupportData?) {}
      override fun onDeviceFunctionPackage1Report(data: DeviceFunctionPackage1?) {}
      override fun onDeviceFunctionPackage2Report(data: DeviceFunctionPackage2?) {}
      override fun onDeviceFunctionPackage3Report(data: DeviceFunctionPackage3?) {}
      override fun onDeviceFunctionPackage4Report(data: DeviceFunctionPackage4?) {}
      override fun onDeviceFunctionPackage5Report(data: DeviceFunctionPackage5?) {}
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

fun VeepooSDKModule.cleanup() {
  val manager = VPOperateManager.getInstance()
  manager?.stopScanDevice()
  manager?.disconnectWatch(object : IBleWriteResponse {
    override fun onResponse(code: Int) {}
  })
  isScanning = false
  isPressureMeasuring = false
  connectedDeviceId = null
  isInitialized = false
  cachedDeviceFunctions.clear()
}

// 压力测量循环
fun VeepooSDKModule.startPressureLoop(firstPromise: Promise? = null) {
  if (!isPressureMeasuring) return
  
  val dataTypeList = java.util.ArrayList<DeviceManualDataType>()
  dataTypeList.add(DeviceManualDataType.STRESS)
  
  val emptyList = java.util.ArrayList<DeviceManualDataType>()
  
  VPOperateManager.getInstance().readDeviceManualData(
    object : IBleWriteResponse {
      override fun onResponse(code: Int) {
        if (code != com.inuker.bluetooth.library.Code.REQUEST_SUCCESS) {
          if (firstPromise != null) {
            isPressureMeasuring = false
            firstPromise.reject("START_FAILED", "Start pressure measurement failed: $code", null)
          }
        } else {
          firstPromise?.resolve(null)
        }
      }
    },
    0L,
    dataTypeList,
    emptyList,
    object : IDeviceManualDetectDataListener {
      override fun onPressureManualDataChange(pressureManualDataList: List<PressureManualData>?) {
        if (isPressureMeasuring && pressureManualDataList != null && pressureManualDataList.isNotEmpty()) {
          val latestData = pressureManualDataList.last()
          
          var value = 0
          try {
            val field = latestData.javaClass.getDeclaredField("pressureValue")
            field.isAccessible = true
            value = field.getInt(latestData)
          } catch (e: Exception) {
            try {
              val field = latestData.javaClass.getDeclaredField("value")
              field.isAccessible = true
              value = field.getInt(latestData)
            } catch (e2: Exception) {}
          }
          
          sendEvent(STRESS_DATA, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "data" to mapOf(
              "stress" to value,
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }
      }

      override fun onBloodPressureDataChange(list: List<BloodPressureManualData>?) {}
      override fun onHeartRateDataChange(list: List<HeartRateManualData>?) {}
      override fun onBloodGlucoseDataChange(list: List<BloodGlucoseManualData>?) {}
      override fun onBloodOxygenDataChange(list: List<BloodOxygenManualData>?) {}
      override fun onBodyTemperatureDataChange(list: List<BodyTemperatureManualData>?) {}
      override fun onMetoManualDataChange(list: List<MetoManualData>?) {}
      override fun onHrvManualDataChange(list: List<HrvManualData>?) {}
      override fun onBloodComponentManualDataChange(list: List<BloodComponentManualData>?) {}
      override fun onMiniCheckupManualDataChange(list: List<MiniCheckupManualData>?) {}
      override fun onEmotionManualDataChange(list: List<EmotionManualData>?) {}
      override fun onFatigueManualDataChange(list: List<FatigueManualData>?) {}
      override fun onSkinConductanceManualDataChange(list: List<SkinConductanceManualData>?) {}
      override fun onReadProgress(progress: Float) {}
      override fun onReadComplete() {
        if (isPressureMeasuring) {
          mainHandler.postDelayed({ startPressureLoop() }, 1000)
        }
      }
      override fun onReadFail() {
        if (isPressureMeasuring) {
          mainHandler.postDelayed({ startPressureLoop() }, 2000)
        }
      }
    }
  )
}

const val TEST_PROGRESS_TOTAL_SECONDS = 25
const val TEST_PROGRESS_INCREMENT = 4

fun VeepooSDKModule.startSimulatedHeartRateProgress(
  onProgress: (Int) -> Unit,
  onComplete: () -> Unit
) {
  stopSimulatedHeartRateProgress()
  heartRateTestProgress = 0
  isHeartRateTesting = true

  heartRateTestRunnable = object : Runnable {
    override fun run() {
      if (!isHeartRateTesting) return

      heartRateTestProgress += TEST_PROGRESS_INCREMENT
      onProgress(heartRateTestProgress)

      if (heartRateTestProgress >= 100) {
        isHeartRateTesting = false
        onComplete()
      } else {
        mainHandler.postDelayed(this, 1000L)
      }
    }
  }

  mainHandler.post(heartRateTestRunnable!!)
}

fun VeepooSDKModule.stopSimulatedHeartRateProgress() {
  isHeartRateTesting = false
  heartRateTestRunnable?.let {
    mainHandler.removeCallbacks(it)
    heartRateTestRunnable = null
  }
  heartRateTestProgress = 0
}

fun VeepooSDKModule.startSimulatedBloodOxygenProgress(
  onProgress: (Int) -> Unit,
  onComplete: () -> Unit
) {
  stopSimulatedBloodOxygenProgress()
  bloodOxygenTestProgress = 0
  isBloodOxygenTesting = true

  bloodOxygenTestRunnable = object : Runnable {
    override fun run() {
      if (!isBloodOxygenTesting) return

      bloodOxygenTestProgress += TEST_PROGRESS_INCREMENT
      onProgress(bloodOxygenTestProgress)

      if (bloodOxygenTestProgress >= 100) {
        isBloodOxygenTesting = false
        onComplete()
      } else {
        mainHandler.postDelayed(this, 1000L)
      }
    }
  }

  mainHandler.post(bloodOxygenTestRunnable!!)
}

fun VeepooSDKModule.stopSimulatedBloodOxygenProgress() {
  isBloodOxygenTesting = false
  bloodOxygenTestRunnable?.let {
    mainHandler.removeCallbacks(it)
    bloodOxygenTestRunnable = null
  }
  bloodOxygenTestProgress = 0
}
