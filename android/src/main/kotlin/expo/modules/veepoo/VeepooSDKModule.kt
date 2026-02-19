package expo.modules.veepoo

import android.content.Context
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.data.*
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.*
import com.veepoo.protocol.model.settings.*
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.SearchResponse

private const val DEVICE_FOUND = "deviceFound"
private const val DEVICE_CONNECTED = "deviceConnected"
private const val DEVICE_DISCONNECTED = "deviceDisconnected"
private const val DEVICE_CONNECT_STATUS = "deviceConnectStatus"
private const val DEVICE_READY = "deviceReady"
private const val BLUETOOTH_STATE_CHANGED = "bluetoothStateChanged"
private const val DEVICE_FUNCTION = "deviceFunction"
private const val DEVICE_VERSION = "deviceVersion"
private const val PASSWORD_DATA = "passwordData"
private const val SOCIAL_MSG_DATA = "socialMsgData"
private const val READ_ORIGIN_PROGRESS = "readOriginProgress"
private const val READ_ORIGIN_COMPLETE = "readOriginComplete"
private const val ORIGIN_HALF_HOUR_DATA = "originHalfHourData"
private const val HEART_RATE_TEST_RESULT = "heartRateTestResult"
private const val BLOOD_PRESSURE_TEST_RESULT = "bloodPressureTestResult"
private const val BLOOD_OXYGEN_TEST_RESULT = "bloodOxygenTestResult"
private const val TEMPERATURE_TEST_RESULT = "temperatureTestResult"
private const val STRESS_DATA = "stressData"
private const val BLOOD_GLUCOSE_DATA = "bloodGlucoseData"
private const val BATTERY_DATA = "batteryData"
private const val CUSTOM_SETTING_DATA = "customSettingData"
private const val DATA_RECEIVED = "dataReceived"
private const val CONNECTION_STATUS_CHANGED = "connectionStatusChanged"
private const val ERROR = "error"

class VeepooSDKModule : Module() {
  
  companion object {
    private const val TAG = "VeepooSDKModule"
  }
  
  private var isScanning = false
  private var connectedDeviceId: String? = null
  private var isInitialized = false
  private val context: Context
    get() = appContext.reactContext ?: appContext.applicationContext
  
  override fun definition() = ModuleDefinition {
    Name("VeepooSDK")

    Events(
      DEVICE_FOUND,
      DEVICE_CONNECTED,
      DEVICE_DISCONNECTED,
      DEVICE_CONNECT_STATUS,
      DEVICE_READY,
      BLUETOOTH_STATE_CHANGED,
      DEVICE_FUNCTION,
      DEVICE_VERSION,
      PASSWORD_DATA,
      SOCIAL_MSG_DATA,
      READ_ORIGIN_PROGRESS,
      READ_ORIGIN_COMPLETE,
      ORIGIN_HALF_HOUR_DATA,
      HEART_RATE_TEST_RESULT,
      BLOOD_PRESSURE_TEST_RESULT,
      BLOOD_OXYGEN_TEST_RESULT,
      TEMPERATURE_TEST_RESULT,
      STRESS_DATA,
      BLOOD_GLUCOSE_DATA,
      BATTERY_DATA,
      CUSTOM_SETTING_DATA,
      DATA_RECEIVED,
      CONNECTION_STATUS_CHANGED,
      ERROR
    )

    AsyncFunction("init") { promise: Promise ->
      try {
        val manager = VPOperateManager.getInstance()
        if (manager == null) {
          promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Veepoo SDK")
          return@AsyncFunction
        }
        
        manager.init(context.applicationContext)
        manager.isLogEnable = true
        manager.setManufacturerIDFilter(false)
        
        isInitialized = true
        Log.d(TAG, "Veepoo SDK initialized successfully")
        promise.resolve(null)
      } catch (e: Exception) {
        Log.e(TAG, "Error initializing Veepoo SDK", e)
        promise.reject("INIT_ERROR", e.message)
      }
    }

    AsyncFunction("isBluetoothEnabled") { promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call init() first")
        return@AsyncFunction
      }
      
      try {
        val manager = VPOperateManager.getInstance()
        val isEnabled = manager?.isBluetoothEnabled ?: false
        promise.resolve(isEnabled)
      } catch (e: Exception) {
        promise.reject("BLUETOOTH_ERROR", e.message)
      }
    }

    AsyncFunction("requestPermissions") { promise: Promise ->
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val hasPermission = context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                           context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
          promise.resolve(true)
        } else {
          promise.reject("PERMISSION_DENIED", "Bluetooth permissions not granted. Please request permissions from your app.")
        }
      } else {
        val hasPermission = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
          promise.resolve(true)
        } else {
          promise.reject("PERMISSION_DENIED", "Location permission not granted")
        }
      }
    }

    AsyncFunction("startScan") { options: Map<String, Any?>?, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return@AsyncFunction
      }
      
      if (isScanning) {
        promise.resolve(null)
        return@AsyncFunction
      }
      
      try {
        val manager = VPOperateManager.getInstance() ?: run {
          promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
          return@AsyncFunction
        }
        
        if (!manager.isBluetoothEnabled) {
          promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
          return@AsyncFunction
        }
        
        manager.startScanDevice(object : SearchResponse {
          override fun onSearchStarted() {
            Log.d(TAG, "Scan started")
            isScanning = true
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
              
              sendEvent(DEVICE_FOUND, mapOf(
                "device" to deviceData,
                "timestamp" to System.currentTimeMillis()
              ))
              Log.d(TAG, "Device found: ${device.name}")
            }
          }

          override fun onSearchStopped() {
            Log.d(TAG, "Scan stopped")
            isScanning = false
          }

          override fun onSearchCanceled() {
            Log.d(TAG, "Scan canceled")
            isScanning = false
          }
        })
        
        promise.resolve(null)
      } catch (e: Exception) {
        Log.e(TAG, "Error starting scan", e)
        promise.reject("SCAN_ERROR", e.message)
      }
    }

    AsyncFunction("stopScan") { promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return@AsyncFunction
      }
      
      try {
        val manager = VPOperateManager.getInstance()
        manager?.stopScanDevice()
        isScanning = false
        promise.resolve(null)
      } catch (e: Exception) {
        Log.e(TAG, "Error stopping scan", e)
        promise.reject("SCAN_ERROR", e.message)
      }
    }

    AsyncFunction("connect") { deviceId: String, options: Map<String, Any?>?, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      if (!manager.isBluetoothEnabled) {
        promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
        return@AsyncFunction
      }
      
      val password = options?.get("password") as? String ?: "0000"
      val is24Hour = options?.get("is24Hour") as? Boolean ?: false
      
      sendEvent(DEVICE_CONNECT_STATUS, mapOf(
        "deviceId" to deviceId,
        "status" to "connecting"
      ))
      
      manager.connectDevice(deviceId, object : IConnectResponse {
        override fun connectStatue(status: Int) {
          Log.d(TAG, "Connection status: $status for device: $deviceId")
          
          when (status) {
            2 -> {
              connectedDeviceId = deviceId
              sendEvent(DEVICE_CONNECTED, mapOf("deviceId" to deviceId))
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "connected",
                "code" to status
              ))
              
              // Verify password after connection
              android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                verifyPasswordInternal(deviceId, password, is24Hour)
              }, 500)
              
              promise.resolve(null)
            }
            0 -> {
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "disconnected",
                "code" to status
              ))
              promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth powered off")
            }
            3 -> {
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "disconnected",
                "code" to status
              ))
              promise.reject("CONNECTION_FAILED", "Connection failed")
            }
            6 -> {
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "disconnected",
                "code" to status
              ))
              promise.reject("TIMEOUT", "Connection timeout")
            }
            else -> {
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "error",
                "code" to status
              ))
              promise.reject("UNKNOWN_ERROR", "Unknown connection error: $status")
            }
          }
        }
      })
    }

    AsyncFunction("disconnect") { deviceId: String, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return@AsyncFunction
      }
      
      try {
        val manager = VPOperateManager.getInstance()
        manager?.disconnectDevice()
        connectedDeviceId = null
        
        sendEvent(DEVICE_DISCONNECTED, mapOf("deviceId" to deviceId))
        sendEvent(DEVICE_CONNECT_STATUS, mapOf(
          "deviceId" to deviceId,
          "status" to "disconnected"
        ))
        
        promise.resolve(null)
      } catch (e: Exception) {
        Log.e(TAG, "Error disconnecting", e)
        promise.reject("DISCONNECT_ERROR", e.message)
      }
    }

    AsyncFunction("getConnectionStatus") { deviceId: String, promise: Promise ->
      val status = if (connectedDeviceId == deviceId) "connected" else "disconnected"
      promise.resolve(status)
    }

    AsyncFunction("verifyPassword") { password: String, is24Hour: Boolean, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized or device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      if (connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val calendar = java.util.Calendar.getInstance()
      manager.confirmDevicePwd(password, object : IPwdDataListener {
        override fun pwdData(pwsData: PwdData?) {
          val status = when (pwsData?.pwdStatus) {
            EPwdStatus.FAIL -> "CHECK_FAIL"
            EPwdStatus.SUCCESS -> "CHECK_SUCCESS"
            EPwdStatus.NOT_SET -> "NOT_SET"
            else -> "UNKNOWN"
          }
          
          promise.resolve(mapOf(
            "status" to status,
            "password" to password,
            "deviceNumber" to (pwsData?.deviceNumber ?: 0),
            "deviceVersion" to (pwsData?.deviceVersion ?: ""),
            "deviceTestVersion" to (pwsData?.deviceTestVersion ?: ""),
            "isHaveDrinkData" to (pwsData?.isHaveDrinkData ?: false),
            "isOpenNightTurnWrist" to "unknown",
            "findPhoneFunction" to "unknown",
            "wearDetectFunction" to "unknown"
          ))
        }
      })
    }

    AsyncFunction("readBattery") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.readDeviceBatteryInfo(object : IBatteryDataListener {
        override fun batteryData(batteryData: BatteryData?) {
          promise.resolve(mapOf(
            "level" to (batteryData?.batteryLevel ?: 0),
            "percent" to true,
            "powerModel" to 0,
            "state" to 0,
            "bat" to (batteryData?.batteryLevel ?: 0),
            "isLowBattery" to ((batteryData?.batteryLevel ?: 0) < 20)
          ))
        }
      })
    }

    AsyncFunction("syncPersonalInfo") { info: Map<String, Any?>, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      val sex = (info["sex"] as? Number)?.toInt() ?: 1
      val height = (info["height"] as? Number)?.toInt() ?: 170
      val weight = (info["weight"] as? Number)?.toInt() ?: 65
      val age = (info["age"] as? Number)?.toInt() ?: 25
      val stepAim = (info["stepAim"] as? Number)?.toInt() ?: 8000
      
      val personalInfo = PersonalInfoData(
        ESex.values().getOrNull(sex) ?: ESex.MAN,
        height,
        weight,
        age,
        stepAim
      )
      
      manager.settingPersonalInfo(object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          promise.resolve(code == 0)
        }
      }, personalInfo)
    }

    AsyncFunction("readDeviceFunctions") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.deviceFunction(object : IDeviceFuctionDataListener {
        override fun deviceFuctionData(functionData: FunctionData?) {
          val functions = mapOf(
            "package1" to mapOf(
              "bloodPressure" to parseFunctionStatus(functionData?.functionBloodPressure),
              "drinking" to parseFunctionStatus(functionData?.functionDrink),
              "sedentaryRemind" to parseFunctionStatus(functionData?.functionSedentaryRemind),
              "heartRateWarning" to parseFunctionStatus(functionData?.functionHeartRateWarning),
              "spoH" to parseFunctionStatus(functionData?.functionSPO2H),
              "heartRateDetect" to parseFunctionStatus(functionData?.functionHeartRateDetect)
            )
          )
          promise.resolve(functions)
        }
      })
    }

    AsyncFunction("readSocialMsgData") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.readSocialMsgData(object : ISocialMsgDataListener {
        override fun socialMsgData(socialMsgData: SocialMsgData?) {
          promise.resolve(mapOf(
            "phone" to parseFunctionStatus(socialMsgData?.phoneFunction),
            "sms" to parseFunctionStatus(socialMsgData?.smsFunction),
            "wechat" to parseFunctionStatus(socialMsgData?.wechatFunction),
            "qq" to parseFunctionStatus(socialMsgData?.qqFunction)
          ))
        }
      })
    }

    AsyncFunction("startReadOriginData") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startReadDeviceAllData(object : IOriginProgressListener {
        override fun progress(progress: Int, originData: OriginData?) {
          sendEvent(READ_ORIGIN_PROGRESS, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "progress" to mapOf(
              "readState" to "reading",
              "totalDays" to 0,
              "currentDay" to 0,
              "progress" to progress
            )
          ))
        }

        override fun complete(originAllData: MutableList<OriginData>?) {
          sendEvent(READ_ORIGIN_COMPLETE, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "success" to true
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("readAutoMeasureSetting") { promise: Promise ->
      promise.resolve(emptyList<Any>())
    }

    AsyncFunction("modifyAutoMeasureSetting") { setting: Map<String, Any?>, promise: Promise ->
      promise.resolve(null)
    }

    AsyncFunction("setLanguage") { language: Int, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.settingLanguage(object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          promise.resolve(code == 0)
        }
      }, language.toByte())
    }

    AsyncFunction("startHeartRateTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startDetectHeart(object : IHeartDataListener {
        override fun heartData(heartData: HeartData?) {
          val testState = when (heartData?.heartStatus) {
            EHeartStatus.DETECTING -> "testing"
            EHeartStatus.NOT_WEAR -> "notWear"
            EHeartStatus.DEVICE_BUSY -> "deviceBusy"
            EHeartStatus.DETECT_COMPLETE -> "over"
            else -> "error"
          }
          
          sendEvent(HEART_RATE_TEST_RESULT, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "result" to mapOf(
              "state" to testState,
              "value" to (heartData?.heartValue ?: 0)
            )
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("stopHeartRateTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance()
      manager?.stopDetectHeart()
      promise.resolve(null)
    }

    AsyncFunction("startBloodPressureTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startDetectBP(object : IBPDataListener {
        override fun bpData(bpData: BPData?) {
          val testState = when (bpData?.bpStatus) {
            EBPStatus.DETECTING -> "testing"
            EBPStatus.NOT_WEAR -> "notWear"
            EBPStatus.DEVICE_BUSY -> "deviceBusy"
            EBPStatus.DETECT_COMPLETE -> "over"
            else -> "error"
          }
          
          sendEvent(BLOOD_PRESSURE_TEST_RESULT, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "result" to mapOf(
              "state" to testState,
              "systolic" to (bpData?.highPressure ?: 0),
              "diastolic" to (bpData?.lowPressure ?: 0),
              "pulse" to (bpData?.pulse ?: 0)
            )
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("stopBloodPressureTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance()
      manager?.stopDetectBP()
      promise.resolve(null)
    }

    AsyncFunction("startBloodOxygenTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startDetectSPO2H(object : ISPO2HDataListener {
        override fun spo2hData(spo2hData: SPO2HData?) {
          val testState = when (spo2hData?.spo2hStatus) {
            ESPO2HStatus.DETECTING -> "testing"
            ESPO2HStatus.NOT_WEAR -> "notWear"
            ESPO2HStatus.DEVICE_BUSY -> "deviceBusy"
            ESPO2HStatus.DETECT_COMPLETE -> "over"
            else -> "error"
          }
          
          sendEvent(BLOOD_OXYGEN_TEST_RESULT, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "result" to mapOf(
              "state" to testState,
              "value" to (spo2hData?.spo2hValue ?: 0)
            )
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("stopBloodOxygenTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance()
      manager?.stopDetectSPO2H()
      promise.resolve(null)
    }

    AsyncFunction("startTemperatureTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startDetectTemp(object : ITempDataListener {
        override fun tempData(tempData: TempData?) {
          val testState = when (tempData?.tempStatus) {
            ETempStatus.DETECTING -> "testing"
            ETempStatus.NOT_WEAR -> "notWear"
            ETempStatus.DEVICE_BUSY -> "deviceBusy"
            ETempStatus.DETECT_COMPLETE -> "over"
            else -> "error"
          }
          
          sendEvent(TEMPERATURE_TEST_RESULT, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "result" to mapOf(
              "state" to testState,
              "value" to (tempData?.tempValue ?: 0f),
              "originalValue" to (tempData?.tempOriginalValue ?: 0f),
              "progress" to 100,
              "enable" to true
            )
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("stopTemperatureTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance()
      manager?.stopDetectTemp()
      promise.resolve(null)
    }

    AsyncFunction("startStressTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startDetectPressure(object : IPressureDataListener {
        override fun pressureData(pressureData: PressureData?) {
          sendEvent(STRESS_DATA, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "data" to mapOf(
              "stress" to (pressureData?.pressureValue ?: 0),
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("stopStressTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance()
      manager?.stopDetectPressure()
      promise.resolve(null)
    }

    AsyncFunction("startBloodGlucoseTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null")
        return@AsyncFunction
      }
      
      manager.startDetectBloodGlucose(object : IBloodGlucoseDataListener {
        override fun bloodGlucoseData(bloodGlucoseData: BloodGlucoseData?) {
          sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
            "deviceId" to (connectedDeviceId ?: ""),
            "data" to mapOf(
              "glucose" to (bloodGlucoseData?.bloodGlucoseValue ?: 0),
              "timestamp" to System.currentTimeMillis()
            )
          ))
        }
      })
      
      promise.resolve(null)
    }

    AsyncFunction("stopBloodGlucoseTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance()
      manager?.stopDetectBloodGlucose()
      promise.resolve(null)
    }

    OnStartObserving {
      Log.d(TAG, "Started observing events")
    }

    OnStopObserving {
      Log.d(TAG, "Stopped observing events")
    }

    OnDestroy {
      cleanup()
    }
  }
  
  private fun verifyPasswordInternal(deviceId: String, password: String, is24Hour: Boolean) {
    val manager = VPOperateManager.getInstance() ?: return
    
    manager.confirmDevicePwd(password, object : IPwdDataListener {
      override fun pwdData(pwsData: PwdData?) {
        val status = when (pwsData?.pwdStatus) {
          EPwdStatus.FAIL -> "CHECK_FAIL"
          EPwdStatus.SUCCESS -> {
            sendEvent(DEVICE_READY, mapOf(
              "deviceId" to deviceId,
              "isOadModel" to false
            ))
            "CHECK_SUCCESS"
          }
          EPwdStatus.NOT_SET -> "NOT_SET"
          else -> "UNKNOWN"
        }
        
        sendEvent(PASSWORD_DATA, mapOf(
          "deviceId" to deviceId,
          "data" to mapOf(
            "status" to status,
            "password" to password,
            "deviceNumber" to (pwsData?.deviceNumber ?: 0),
            "deviceVersion" to (pwsData?.deviceVersion ?: ""),
            "deviceTestVersion" to (pwsData?.deviceTestVersion ?: ""),
            "isHaveDrinkData" to (pwsData?.isHaveDrinkData ?: false),
            "isOpenNightTurnWrist" to "unknown",
            "findPhoneFunction" to "unknown",
            "wearDetectFunction" to "unknown"
          )
        ))
      }
    })
  }
  
  private fun parseFunctionStatus(status: EFunctionStatus?): String {
    return when (status) {
      EFunctionStatus.SUPPORT -> "support"
      EFunctionStatus.OPEN -> "open"
      EFunctionStatus.CLOSE -> "close"
      EFunctionStatus.UNSUPPORT -> "unsupported"
      else -> "unknown"
    }
  }
  
  private fun cleanup() {
    val manager = VPOperateManager.getInstance()
    manager?.stopScanDevice()
    manager?.disconnectDevice()
    isScanning = false
    connectedDeviceId = null
    isInitialized = false
  }
}
