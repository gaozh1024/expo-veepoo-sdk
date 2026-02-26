package expo.modules.veepoo

import android.content.Context
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.*
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.*
import com.veepoo.protocol.model.settings.*
import com.inuker.bluetooth.library.Code
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse

private const val DEVICE_FOUND = "deviceFound"
private const val DEVICE_CONNECTED = "deviceConnected"
private const val DEVICE_DISCONNECTED = "deviceDisconnected"
private const val DEVICE_CONNECT_STATUS = "deviceConnectStatus"
private const val DEVICE_READY = "deviceReady"
private const val BLUETOOTH_STATE_CHANGED = "bluetoothStateChanged"
private const val DEVICE_FUNCTION = "deviceFunction"
private const val DEVICE_VERSION = "deviceVersion"
private const val PASSWORD_DATA = "passwordData"
private const val HEART_RATE_TEST_RESULT = "heartRateTestResult"
private const val BLOOD_PRESSURE_TEST_RESULT = "bloodPressureTestResult"
private const val BLOOD_OXYGEN_TEST_RESULT = "bloodOxygenTestResult"
private const val TEMPERATURE_TEST_RESULT = "temperatureTestResult"
private const val STRESS_DATA = "stressData"
private const val BLOOD_GLUCOSE_DATA = "bloodGlucoseData"
private const val READ_ORIGIN_PROGRESS = "readOriginProgress"
private const val READ_ORIGIN_COMPLETE = "readOriginComplete"
private const val ORIGIN_HALF_HOUR_DATA = "originHalfHourData"
private const val SLEEP_DATA = "sleepData"
private const val SPORT_STEP_DATA = "sportStepData"
private const val ERROR = "error"

class VeepooSDKModule : Module() {
  
  companion object {
    private const val TAG = "VeepooSDKModule"
  }
  
  private var isScanning = false
  private var connectedDeviceId: String? = null
  private var isInitialized = false
  private var isPressureMeasuring = false
  private val mainHandler = Handler(Looper.getMainLooper())
  private val cachedDeviceFunctions = mutableMapOf<String, Map<String, Any?>>()
  private var cachedDeviceVersion: String = ""
  private var cachedDeviceNumber: String = ""
  private val context: Context
    get() = appContext.reactContext ?: appContext.currentActivity?.applicationContext!!
  
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
      HEART_RATE_TEST_RESULT,
      BLOOD_PRESSURE_TEST_RESULT,
      BLOOD_OXYGEN_TEST_RESULT,
      TEMPERATURE_TEST_RESULT,
      STRESS_DATA,
      BLOOD_GLUCOSE_DATA,
      READ_ORIGIN_PROGRESS,
      READ_ORIGIN_COMPLETE,
      ORIGIN_HALF_HOUR_DATA,
      ERROR
    )

    AsyncFunction("init") { promise: Promise ->
      try {
        val manager = VPOperateManager.getInstance()
        if (manager == null) {
          promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Veepoo SDK", null)
          return@AsyncFunction
        }
        
        manager.init(context)
        isInitialized = true
        Log.d(TAG, "Veepoo SDK initialized successfully")
        promise.resolve(null)
      } catch (e: Exception) {
        Log.e(TAG, "Error initializing Veepoo SDK", e)
        promise.reject("INIT_ERROR", e.message, e)
      }
    }

    AsyncFunction("isBluetoothEnabled") { promise: Promise ->
      promise.resolve(true)
    }

    AsyncFunction("requestPermissions") { promise: Promise ->
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val hasPermission = context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                           context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
          promise.resolve(true)
        } else {
          promise.reject("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
        }
      } else {
        val hasPermission = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
          promise.resolve(true)
        } else {
          promise.reject("PERMISSION_DENIED", "Location permission not granted", null)
        }
      }
    }

    AsyncFunction("startScan") { options: Map<String, Any?>?, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
        return@AsyncFunction
      }
      
      if (isScanning) {
        promise.resolve(null)
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
        promise.reject("SCAN_ERROR", e.message, e)
      }
    }

    AsyncFunction("stopScan") { promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
        return@AsyncFunction
      }
      
      try {
        val manager = VPOperateManager.getInstance()
        manager?.stopScanDevice()
        isScanning = false
        promise.resolve(null)
      } catch (e: Exception) {
        Log.e(TAG, "Error stopping scan", e)
        promise.reject("SCAN_ERROR", e.message, e)
      }
    }

    AsyncFunction("connect") { deviceId: String, options: Map<String, Any?>?, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      val password = options?.get("password") as? String ?: "0000"
      val is24Hour = options?.get("is24Hour") as? Boolean ?: false
      
      sendEvent(DEVICE_CONNECT_STATUS, mapOf(
        "deviceId" to deviceId,
        "status" to "connecting"
      ))
      
      manager.connectDevice(
        deviceId,
        object : IConnectResponse {
          override fun connectState(code: Int, profile: com.inuker.bluetooth.library.model.BleGattProfile?, isOadModel: Boolean) {
            Log.d(TAG, "Connection state: $code for device: $deviceId")
            
            if (code == Code.REQUEST_SUCCESS) {
              connectedDeviceId = deviceId
              sendEvent(DEVICE_CONNECTED, mapOf("deviceId" to deviceId, "isOadModel" to isOadModel))
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "connected",
                "code" to code
              ))
              
              Handler(Looper.getMainLooper()).postDelayed({
                verifyPasswordInternal(deviceId, password, is24Hour)
              }, 500)
              
              promise.resolve(null)
            } else {
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "disconnected",
                "code" to code
              ))
              promise.reject("CONNECTION_FAILED", "Connection failed with code: $code", null)
            }
          }
        },
        object : INotifyResponse {
          override fun notifyState(state: Int) {
            if (state == Code.REQUEST_SUCCESS) {
              sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                "deviceId" to deviceId,
                "status" to "ready"
              ))
            }
          }
        }
      )
    }

    AsyncFunction("disconnect") { deviceId: String, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
        return@AsyncFunction
      }
      
      try {
        val manager = VPOperateManager.getInstance()
        manager?.disconnectWatch(
          object : IBleWriteResponse {
            override fun onResponse(code: Int) {
              if (code == Code.REQUEST_SUCCESS) {
                connectedDeviceId = null
                sendEvent(DEVICE_DISCONNECTED, mapOf("deviceId" to deviceId))
                sendEvent(DEVICE_CONNECT_STATUS, mapOf(
                  "deviceId" to deviceId,
                  "status" to "disconnected"
                ))
                promise.resolve(null)
              } else {
                promise.reject("DISCONNECT_FAILED", "Disconnect failed with code: $code", null)
              }
            }
          }
        )
      } catch (e: Exception) {
        Log.e(TAG, "Error disconnecting", e)
        promise.reject("DISCONNECT_ERROR", e.message, e)
      }
    }

    AsyncFunction("getConnectionStatus") { deviceId: String, promise: Promise ->
      val status = if (connectedDeviceId == deviceId) "connected" else "disconnected"
      promise.resolve(status)
    }

    AsyncFunction("verifyPassword") { password: String, is24Hour: Boolean, promise: Promise ->
      if (!isInitialized) {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      if (connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      manager.confirmDevicePwd(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {}
        },
        object : IPwdDataListener {
          override fun onPwdDataChange(pwdData: PwdData?) {
            val status = pwdData?.getmStatus()?.toString() ?: "UNKNOWN"
            
            if (status.contains("SUCCESS")) {
              cachedDeviceVersion = pwdData?.deviceVersion ?: ""
              cachedDeviceNumber = pwdData?.deviceNumber?.toString() ?: ""
              sendEvent(DEVICE_READY, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "isOadModel" to false
              ))
            }
            
            sendEvent(PASSWORD_DATA, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "data" to mapOf(
                "status" to status,
                "password" to password,
                "deviceNumber" to (pwdData?.deviceNumber?.toString() ?: ""),
                "deviceVersion" to (pwdData?.deviceVersion ?: "")
              )
            ))
            
            promise.resolve(mapOf(
              "status" to status,
              "password" to password,
              "deviceNumber" to (pwdData?.deviceNumber?.toString() ?: ""),
              "deviceVersion" to (pwdData?.deviceVersion ?: "")
            ))
          }
        },
        object : IDeviceFuctionDataListener {
          override fun onFunctionSupportDataChange(data: FunctionDeviceSupportData?) {
            if (data != null) {
              val functionData = mapOf(
                "type" to "FunctionDeviceSupportData",
                "heartDetect" to data.heartDetect.toString(),
                "bp" to data.bp.toString(),
                "spo2H" to data.spo2H.toString(),
                "temperatureFunction" to data.temperatureFunction.toString(),
                "ecg" to data.ecg.toString(),
                "precisionSleep" to data.precisionSleep.toString(),
                "weatherFunction" to data.weatherFunction.toString(),
                "beathFunction" to data.beathFunction.toString(),
                "women" to data.women.toString(),
                "screenStyleFunction" to data.screenStyleFunction.toString(),
                "stress" to data.stress.toString()
              )
              sendEvent(DEVICE_FUNCTION, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to functionData
              ))
            }
          }
          
          override fun onDeviceFunctionPackage1Report(data: DeviceFunctionPackage1?) {
            if (data != null) {
              val functionData = mapOf(
                "type" to "DeviceFunctionPackage1",
                "raw" to data.toString()
              )
              sendEvent(DEVICE_FUNCTION, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to functionData
              ))
              cachedDeviceFunctions["package1"] = functionData
            }
          }
          
          override fun onDeviceFunctionPackage2Report(data: DeviceFunctionPackage2?) {
            if (data != null) {
              val functionData = mapOf(
                "type" to "DeviceFunctionPackage2",
                "raw" to data.toString()
              )
              sendEvent(DEVICE_FUNCTION, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to functionData
              ))
              cachedDeviceFunctions["package2"] = functionData
            }
          }
          
          override fun onDeviceFunctionPackage3Report(data: DeviceFunctionPackage3?) {
            if (data != null) {
              val functionData = mapOf(
                "type" to "DeviceFunctionPackage3",
                "bigDataTranType" to (data.bigDataTranType),
                "watchUiServerCount" to (data.watchUiServerCount),
                "watchUiCustomCount" to (data.watchUiCustomCount),
                "temperatureFunction" to (data.temperatureFunction?.toString() ?: "unsupported"),
                "temperatureType" to (data.temperatureType),
                "cpuType" to (data.cpuType),
                "stressFunction" to (data.stressFunction?.toString() ?: "unsupported"),
                "stressType" to (data.stressType),
                "contactFunction" to (data.contactFunction?.toString() ?: "unsupported"),
                "contactType" to (data.contactType),
                "musicStyle" to (data.musicStyle),
                "findDeviceByPhoneFunction" to (data.findDeviceByPhoneFunction?.toString() ?: "unsupported"),
                "agpsFunction" to (data.agpsFunction?.toString() ?: "unsupported"),
                "bloodGlucoseTag" to (data.bloodGlucoseTag),
                "bloodGlucose" to (data.bloodGlucose),
                "bloodGlucoseAdjusting" to (data.bloodGlucoseAdjusting?.toString() ?: "unsupported"),
                "bloodGlucoseMultipleAdjusting" to (data.bloodGlucoseMultipleAdjusting?.toString() ?: "unsupported"),
                "bloodGlucoseRiskAssessment" to (data.bloodGlucoseRiskAssessment?.toString() ?: "unsupported")
              )
              sendEvent(DEVICE_FUNCTION, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to functionData
              ))
              cachedDeviceFunctions["package3"] = functionData
            }
          }
          
          override fun onDeviceFunctionPackage4Report(data: DeviceFunctionPackage4?) {
            if (data != null) {
              val functionData = mapOf(
                "type" to "DeviceFunctionPackage4",
                "bloodComponent" to (data.bloodComponent?.toString() ?: "unsupported"),
                "bloodComponentSingleCalibration" to (data.bloodComponentSingleCalibration?.toString() ?: "unsupported"),
                "bodyComponent" to (data.bodyComponent?.toString() ?: "unsupported"),
                "worldClock" to (data.worldClock?.toString() ?: "unsupported"),
                "autoMeasure" to (data.autoMeasure?.toString() ?: "unsupported"),
                "temperatureAlarm" to (data.temperatureAlarm?.toString() ?: "unsupported"),
                "wallet" to (data.wallet?.toString() ?: "unsupported"),
                "postcard" to (data.postcard?.toString() ?: "unsupported"),
                "gameSetting" to (data.gameSetting?.toString() ?: "unsupported"),
                "aiQA" to (data.aiQA?.toString() ?: "unsupported"),
                "aiDial" to (data.aiDial?.toString() ?: "unsupported"),
                "distanceCalorieGoal" to (data.distanceCalorieGoal?.toString() ?: "unsupported"),
                "videoDial" to (data.videoDial?.toString() ?: "unsupported")
              )
              sendEvent(DEVICE_FUNCTION, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to functionData
              ))
              cachedDeviceFunctions["package4"] = functionData
            }
          }
          
          override fun onDeviceFunctionPackage5Report(data: DeviceFunctionPackage5?) {
            if (data != null) {
              val functionData = mapOf(
                "type" to "DeviceFunctionPackage5",
                "textImagePush" to (data.textImagePush?.toString() ?: "unsupported")
              )
              sendEvent(DEVICE_FUNCTION, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to functionData
              ))
              cachedDeviceFunctions["package5"] = functionData
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

    AsyncFunction("readBattery") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      manager.readBattery(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {}
        },
        object : IBatteryDataListener {
          override fun onDataChange(batteryData: BatteryData?) {
            if (batteryData != null) {
              promise.resolve(mapOf(
                "level" to batteryData.batteryLevel,
                "percent" to batteryData.batteryPercent,
                "powerModel" to batteryData.powerModel,
                "state" to batteryData.state,
                "bat" to batteryData.bat.toInt(),
                "isPercent" to batteryData.isPercent,
                "isLowBattery" to batteryData.isLowBattery
              ))
            } else {
              promise.reject("READ_FAILED", "Battery data is null", null)
            }
          }
        }
      )
    }

    AsyncFunction("syncPersonalInfo") { info: Map<String, Any?>, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      val sex = (info["sex"] as? Number)?.toInt() ?: 1
      val height = (info["height"] as? Number)?.toInt() ?: 170
      val weight = (info["weight"] as? Number)?.toInt() ?: 65
      val age = (info["age"] as? Number)?.toInt() ?: 25
      val stepAim = (info["stepAim"] as? Number)?.toInt() ?: 8000
      val sleepAim = (info["sleepAim"] as? Number)?.toInt() ?: 480
      
      val eSex = if (sex == 1) ESex.MAN else ESex.WOMEN
      val personalInfo = PersonInfoData(eSex, height, weight, age, stepAim, sleepAim)
      
      manager.syncPersonInfo(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code != Code.REQUEST_SUCCESS) {
              promise.reject("CMD_FAILED", "Sync person info failed: $code", null)
            }
          }
        },
        object : IPersonInfoDataListener {
          override fun OnPersoninfoDataChange(status: EOprateStauts?) {
            if (status == EOprateStauts.OPRATE_SUCCESS) {
              promise.resolve(true)
            } else {
              promise.reject("SYNC_FAILED", "Sync failed: $status", null)
            }
          }
        },
        personalInfo
      )
    }

    AsyncFunction("readDeviceFunctions") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      Log.d(TAG, "readDeviceFunctions: returning ${cachedDeviceFunctions.size} function packages")
      promise.resolve(cachedDeviceFunctions.toMap())
    }

    AsyncFunction("readSocialMsgData") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      promise.resolve(emptyMap<String, Any>())
    }

    AsyncFunction("readDeviceVersion") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      Log.d(TAG, "readDeviceVersion: reading device version info")
      
      val result = mapOf(
        "hardwareVersion" to cachedDeviceVersion,
        "firmwareVersion" to "",
        "softwareVersion" to "",
        "deviceNumber" to cachedDeviceNumber,
        "newVersion" to "",
        "description" to ""
      )
      
      sendEvent(DEVICE_VERSION, mapOf(
        "deviceId" to (connectedDeviceId ?: ""),
        "version" to result
      ))
      
      Log.d(TAG, "readDeviceVersion: $result")
      promise.resolve(result)
    }

    AsyncFunction("startReadOriginData") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      manager.readOriginData(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code == Code.REQUEST_SUCCESS) {
              Log.d(TAG, "startReadOriginData: command sent successfully")
            } else {
              Log.e(TAG, "startReadOriginData: command failed with code $code")
            }
          }
        },
        object : IOriginData3Listener {
          override fun onOriginFiveMinuteListDataChange(dataList3: List<OriginData3>?) {
            if (dataList3 != null && dataList3.isNotEmpty()) {
              Log.d(TAG, "onOriginFiveMinuteListDataChange: ${dataList3.size} records")
            }
          }
          
          override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {
            try {
              if (data != null) {
                Log.d(TAG, "onOriginHalfHourDataChange: date=${data.date}, allStep=${data.allStep}")
                
                val sportList = mutableListOf<Map<String, Any>>()
                data.halfHourSportDatas?.forEach { sport ->
                  try {
                    val time = sport.time
                    if (time != null) {
                      sportList.add(mapOf(
                        "time" to String.format("%02d:%02d", time.hour, time.minute),
                        "step" to sport.stepValue,
                        "cal" to sport.calValue,
                        "dis" to sport.disValue
                      ))
                    }
                  } catch (e: Exception) {
                    Log.e(TAG, "Error processing sport data", e)
                  }
                }
                
                val rateList = mutableListOf<Map<String, Any>>()
                data.halfHourRateDatas?.forEach { rate ->
                  try {
                    val time = rate.time
                    if (time != null) {
                      rateList.add(mapOf(
                        "time" to String.format("%02d:%02d", time.hour, time.minute),
                        "heartValue" to rate.rateValue
                      ))
                    }
                  } catch (e: Exception) {
                    Log.e(TAG, "Error processing rate data", e)
                  }
                }
                
                val bpList = mutableListOf<Map<String, Any>>()
                data.halfHourBps?.forEach { bp ->
                  try {
                    val time = bp.time
                    if (time != null) {
                      bpList.add(mapOf(
                        "time" to String.format("%02d:%02d", time.hour, time.minute),
                        "systolic" to bp.highValue,
                        "diastolic" to bp.lowValue
                      ))
                    }
                  } catch (e: Exception) {
                    Log.e(TAG, "Error processing BP data", e)
                  }
                }
                
                val dateStr = data.date ?: ""
                val formattedDate = if (dateStr.length >= 10) dateStr.substring(0, 10) else dateStr
                
                val calSum = sportList.mapNotNull { (it["cal"] as? Number)?.toDouble() }.sum()
                val disSum = sportList.mapNotNull { (it["dis"] as? Number)?.toDouble() }.sum()
                val stepSum = sportList.mapNotNull { (it["step"] as? Number)?.toInt() }.sum()
                
                sendEvent(ORIGIN_HALF_HOUR_DATA, mapOf(
                  "deviceId" to (connectedDeviceId ?: ""),
                  "data" to mapOf(
                    "time" to formattedDate,
                    "sportValue" to data.allStep,
                    "calValue" to calSum,
                    "disValue" to disSum,
                    "stepValue" to stepSum,
                    "heartValue" to (rateList.firstOrNull()?.get("heartValue") ?: 0),
                    "diastolic" to (bpList.firstOrNull()?.get("diastolic") ?: 0),
                    "systolic" to (bpList.firstOrNull()?.get("systolic") ?: 0),
                    "spo2Value" to 0,
                    "tempValue" to 0.0,
                    "stressValue" to 0
                  )
                ))
              }
            } catch (e: Exception) {
              Log.e(TAG, "Error in onOriginHalfHourDataChange", e)
              sendEvent(ERROR, mapOf(
                "code" to "ORIGIN_DATA_ERROR",
                "message" to (e.message ?: "Unknown error processing origin data"),
                "deviceId" to (connectedDeviceId ?: "")
              ))
            }
          }
          
          override fun onOriginHRVOriginListDataChange(dataList: List<HRVOriginData>?) {
            if (dataList != null && dataList.isNotEmpty()) {
              Log.d(TAG, "onOriginHRVOriginListDataChange: ${dataList.size} records")
            }
          }
          
          override fun onOriginSpo2OriginListDataChange(dataList: List<Spo2hOriginData>?) {
            if (dataList != null && dataList.isNotEmpty()) {
              Log.d(TAG, "onOriginSpo2OriginListDataChange: ${dataList.size} records")
            }
          }
          
          override fun onReadOriginProgressDetail(day: Int, date: String?, allPack: Int, currentPack: Int) {
            try {
              val progress = if (allPack > 0) currentPack.toDouble() / allPack.toDouble() else 0.0
              Log.d(TAG, "onReadOriginProgressDetail: day=$day, progress=$progress")
              
              sendEvent(READ_ORIGIN_PROGRESS, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "progress" to mapOf(
                  "readState" to "reading",
                  "totalDays" to 1,
                  "currentDay" to 1,
                  "progress" to progress
                )
              ))
            } catch (e: Exception) {
              Log.e(TAG, "Error in onReadOriginProgressDetail", e)
            }
          }
          
          override fun onReadOriginProgress(progress: Float) {
            try {
              var p = progress.toDouble()
              if (p > 1.0) p /= 100.0
              
              Log.d(TAG, "onReadOriginProgress: $p")
              
              sendEvent(READ_ORIGIN_PROGRESS, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "progress" to mapOf(
                  "readState" to "reading",
                  "totalDays" to 1,
                  "currentDay" to 1,
                  "progress" to p
                )
              ))
            } catch (e: Exception) {
              Log.e(TAG, "Error in onReadOriginProgress", e)
            }
          }
          
          override fun onReadOriginComplete() {
            try {
              Log.d(TAG, "onReadOriginComplete")
              
              sendEvent(READ_ORIGIN_COMPLETE, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "success" to true
              ))
              
              promise.resolve(null)
            } catch (e: Exception) {
              Log.e(TAG, "Error in onReadOriginComplete", e)
              sendEvent(READ_ORIGIN_COMPLETE, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "success" to false
              ))
              promise.resolve(null)
            }
          }
        },
        0
      )
    }

    AsyncFunction("readDeviceAllData") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      Log.d(TAG, "readDeviceAllData: starting to read all device data")
      
      sendEvent(READ_ORIGIN_PROGRESS, mapOf(
        "deviceId" to (connectedDeviceId ?: ""),
        "progress" to mapOf(
          "readState" to "start",
          "totalDays" to 1,
          "currentDay" to 1,
          "progress" to 0.0
        )
      ))
      
      manager.readOriginData(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code != Code.REQUEST_SUCCESS) {
              Log.e(TAG, "readDeviceAllData: command failed with code $code")
            }
          }
        },
        object : IOriginData3Listener {
          override fun onOriginFiveMinuteListDataChange(dataList3: List<OriginData3>?) {
            if (dataList3 != null && dataList3.isNotEmpty()) {
              Log.d(TAG, "readDeviceAllData: onOriginFiveMinuteListDataChange: ${dataList3.size} records")
            }
          }
          
          override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {
            if (data != null) {
              Log.d(TAG, "readDeviceAllData: onOriginHalfHourDataChange: date=${data.date}")
              
              val sportList = mutableListOf<Map<String, Any>>()
              data.halfHourSportDatas?.forEach { sport ->
                val time = sport.time
                if (time != null) {
                  sportList.add(mapOf(
                    "time" to String.format("%02d:%02d", time.hour, time.minute),
                    "step" to sport.stepValue,
                    "cal" to sport.calValue,
                    "dis" to sport.disValue
                  ))
                }
              }
              
              val rateList = mutableListOf<Map<String, Any>>()
              data.halfHourRateDatas?.forEach { rate ->
                val time = rate.time
                if (time != null) {
                  rateList.add(mapOf(
                    "time" to String.format("%02d:%02d", time.hour, time.minute),
                    "heartValue" to rate.rateValue
                  ))
                }
              }
              
              val dateStr = data.date ?: ""
              val formattedDate = if (dateStr.length >= 10) dateStr.substring(0, 10) else dateStr
              
              val calSum = sportList.mapNotNull { (it["cal"] as? Number)?.toDouble() }.sum()
              val disSum = sportList.mapNotNull { (it["dis"] as? Number)?.toDouble() }.sum()
              val stepSum = sportList.mapNotNull { (it["step"] as? Number)?.toInt() }.sum()
              
              sendEvent(ORIGIN_HALF_HOUR_DATA, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "data" to mapOf(
                  "time" to formattedDate,
                  "sportValue" to data.allStep,
                  "calValue" to calSum,
                  "disValue" to disSum,
                  "stepValue" to stepSum,
                  "heartValue" to (rateList.firstOrNull()?.get("heartValue") ?: 0)
                )
              ))
            }
          }
          
          override fun onOriginHRVOriginListDataChange(dataList: List<HRVOriginData>?) {}
          
          override fun onOriginSpo2OriginListDataChange(dataList: List<Spo2hOriginData>?) {}
          
          override fun onReadOriginProgressDetail(day: Int, date: String?, allPack: Int, currentPack: Int) {
            val progress = if (allPack > 0) currentPack.toDouble() / allPack.toDouble() else 0.0
            Log.d(TAG, "readDeviceAllData: onReadOriginProgressDetail: day=$day, progress=$progress")
            
            sendEvent(READ_ORIGIN_PROGRESS, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "progress" to mapOf(
                "readState" to "reading",
                "totalDays" to 1,
                "currentDay" to day,
                "progress" to progress
              )
            ))
          }
          
          override fun onReadOriginProgress(progress: Float) {
            var p = progress.toDouble()
            if (p > 1.0) p /= 100.0
            
            Log.d(TAG, "readDeviceAllData: onReadOriginProgress: $p")
            
            sendEvent(READ_ORIGIN_PROGRESS, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "progress" to mapOf(
                "readState" to "reading",
                "totalDays" to 1,
                "currentDay" to 1,
                "progress" to p
              )
            ))
          }
          
          override fun onReadOriginComplete() {
            Log.d(TAG, "readDeviceAllData: onReadOriginComplete")
            
            sendEvent(READ_ORIGIN_PROGRESS, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "progress" to mapOf(
                "readState" to "complete",
                "totalDays" to 1,
                "currentDay" to 1,
                "progress" to 1.0
              )
            ))
            
            sendEvent(READ_ORIGIN_COMPLETE, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "success" to true
            ))
            
            promise.resolve(true)
          }
        },
        0
      )
    }

    AsyncFunction("readSleepData") { date: String?, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      Log.d(TAG, "readSleepData: reading sleep data")
      
      manager.readSleepData(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code != Code.REQUEST_SUCCESS) {
              Log.e(TAG, "readSleepData: command failed with code $code")
            }
          }
        },
        object : ISleepDataListener {
          override fun onSleepDataChange(day: String?, sleepData: SleepData?) {
            if (sleepData != null) {
              Log.d(TAG, "onSleepDataChange: day=$day, allSleepTime=${sleepData.allSleepTime}")
              
              var sleepDownStr = ""
              if (sleepData.sleepDown != null) {
                sleepDownStr = String.format("%04d-%02d-%02d %02d:%02d:%02d",
                  sleepData.sleepDown.year,
                  sleepData.sleepDown.month,
                  sleepData.sleepDown.day,
                  sleepData.sleepDown.hour,
                  sleepData.sleepDown.minute,
                  sleepData.sleepDown.second
                )
              }
              
              var sleepUpStr = ""
              if (sleepData.sleepUp != null) {
                sleepUpStr = String.format("%04d-%02d-%02d %02d:%02d:%02d",
                  sleepData.sleepUp.year,
                  sleepData.sleepUp.month,
                  sleepData.sleepUp.day,
                  sleepData.sleepUp.hour,
                  sleepData.sleepUp.minute,
                  sleepData.sleepUp.second
                )
              }
              
              val result = mapOf(
                "date" to (sleepData.date ?: ""),
                "sleepTime" to sleepDownStr,
                "wakeTime" to sleepUpStr,
                "deepSleepDuration" to (sleepData.deepSleepTime / 60.0),
                "lightSleepDuration" to (sleepData.lowSleepTime / 60.0),
                "totalSleepHours" to (sleepData.allSleepTime / 60),
                "totalSleepMinutes" to (sleepData.allSleepTime % 60),
                "sleepLevel" to sleepData.sleepQulity,
                "sleepLine" to (sleepData.sleepLine ?: ""),
                "wakeUpCount" to sleepData.wakeCount
              )
              
              sendEvent(SLEEP_DATA, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "date" to (sleepData.date ?: ""),
                "data" to listOf(result)
              ))
              
              promise.resolve(listOf(result))
            } else {
              Log.d(TAG, "onSleepDataChange: sleepData is null")
              sendEvent(SLEEP_DATA, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "date" to (date ?: ""),
                "data" to emptyList<Any>()
              ))
              promise.resolve(emptyList<Any>())
            }
          }
          
          override fun onSleepProgress(progress: Float) {
            Log.d(TAG, "onSleepProgress: $progress")
          }
          
          override fun onSleepProgressDetail(day: String?, progress: Int) {
            Log.d(TAG, "onSleepProgressDetail: day=$day, progress=$progress")
          }
          
          override fun onReadSleepComplete() {
            Log.d(TAG, "onReadSleepComplete")
          }
        },
        0
      )
    }

    AsyncFunction("readSportStepData") { date: String?, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      Log.d(TAG, "readSportStepData: reading sport step data")
      
      manager.readSportStep(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code != Code.REQUEST_SUCCESS) {
              Log.e(TAG, "readSportStepData: command failed with code $code")
            }
          }
        },
        object : ISportDataListener {
          override fun onSportDataChange(sportData: SportData?) {
            if (sportData != null) {
              Log.d(TAG, "onSportDataChange: step=${sportData.step}, dis=${sportData.dis}, kcal=${sportData.kcal}")
              
              val result = mapOf(
                "date" to (date ?: ""),
                "stepCount" to sportData.step,
                "distance" to sportData.dis,
                "calories" to sportData.kcal
              )
              
              sendEvent(SPORT_STEP_DATA, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "date" to (date ?: ""),
                "data" to result
              ))
              
              promise.resolve(result)
            } else {
              Log.d(TAG, "onSportDataChange: sportData is null")
              val emptyResult = mapOf(
                "date" to (date ?: ""),
                "stepCount" to 0,
                "distance" to 0.0,
                "calories" to 0.0
              )
              sendEvent(SPORT_STEP_DATA, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
                "date" to (date ?: ""),
                "data" to emptyResult
              ))
              promise.resolve(emptyResult)
            }
          }
        }
      )
    }

    AsyncFunction("readOriginData") { dayOffset: Int, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      val manager = VPOperateManager.getInstance() ?: run {
        promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
        return@AsyncFunction
      }
      
      Log.d(TAG, "readOriginData: dayOffset=$dayOffset")
      
      manager.readOriginData(
        object : IBleWriteResponse {
          override fun onResponse(code: Int) {
            if (code != Code.REQUEST_SUCCESS) {
              Log.e(TAG, "readOriginData: command failed with code $code")
            }
          }
        },
        object : IOriginData3Listener {
          private val dataList = mutableListOf<Map<String, Any>>()
          
          override fun onOriginFiveMinuteListDataChange(dataList3: List<OriginData3>?) {
            if (dataList3 != null && dataList3.isNotEmpty()) {
              Log.d(TAG, "onOriginFiveMinuteListDataChange: ${dataList3.size} records")
              
              for (data in dataList3) {
                val timeData = data.getmTime()
                if (timeData != null) {
                  val timeStr = String.format("%02d:%02d", timeData.hour, timeData.minute)
                  
                  val item = mapOf(
                    "time" to timeStr,
                    "heartValue" to data.rateValue,
                    "stepValue" to data.stepValue,
                    "calValue" to data.calValue,
                    "disValue" to data.disValue,
                    "sportValue" to data.sportValue,
                    "systolic" to data.highValue,
                    "diastolic" to data.lowValue,
                    "spo2Value" to 0,
                    "tempValue" to data.temperature,
                    "stressValue" to data.pressure,
                    "met" to data.met.toDouble()
                  )
                  
                  dataList.add(item)
                }
              }
            }
          }
          
          override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {}
          
          override fun onOriginHRVOriginListDataChange(dataList: List<HRVOriginData>?) {}
          
          override fun onOriginSpo2OriginListDataChange(dataList: List<Spo2hOriginData>?) {}
          
          override fun onReadOriginProgressDetail(day: Int, date: String?, allPack: Int, currentPack: Int) {}
          
          override fun onReadOriginProgress(progress: Float) {}
          
          override fun onReadOriginComplete() {
            Log.d(TAG, "readOriginData complete: ${dataList.size} records")
            val sortedList = dataList.sortedBy { it["time"] as? String ?: "" }
            promise.resolve(sortedList)
          }
        },
        dayOffset
      )
    }

    AsyncFunction("readAutoMeasureSetting") { promise: Promise ->
      promise.resolve(emptyList<Any>())
    }

    AsyncFunction("modifyAutoMeasureSetting") { setting: Map<String, Any?>, promise: Promise ->
      promise.resolve(null)
    }

    AsyncFunction("setLanguage") { language: Int, promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      promise.resolve(true)
    }

    AsyncFunction("startHeartRateTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
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
              
              sendEvent(HEART_RATE_TEST_RESULT, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
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
      if (!isInitialized || connectedDeviceId == null) {
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
      if (!isInitialized || connectedDeviceId == null) {
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
              
              sendEvent(BLOOD_PRESSURE_TEST_RESULT, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
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
      if (!isInitialized || connectedDeviceId == null) {
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
      if (!isInitialized || connectedDeviceId == null) {
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
              
              sendEvent(BLOOD_OXYGEN_TEST_RESULT, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
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
      if (!isInitialized || connectedDeviceId == null) {
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
      if (!isInitialized || connectedDeviceId == null) {
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
              
              sendEvent(TEMPERATURE_TEST_RESULT, mapOf(
                "deviceId" to (connectedDeviceId ?: ""),
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
      if (!isInitialized || connectedDeviceId == null) {
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
      if (!isInitialized || connectedDeviceId == null) {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
        return@AsyncFunction
      }
      
      if (isPressureMeasuring) {
        promise.reject("ALREADY_MEASURING", "Pressure measurement is already in progress", null)
        return@AsyncFunction
      }
      
      isPressureMeasuring = true
      startPressureLoop(promise)
    }

    AsyncFunction("stopStressTest") { promise: Promise ->
      isPressureMeasuring = false
      promise.resolve(null)
    }

    AsyncFunction("startBloodGlucoseTest") { promise: Promise ->
      if (!isInitialized || connectedDeviceId == null) {
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
            sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "data" to mapOf(
                "glucose" to bloodGlucose.toDouble(),
                "progress" to progress,
                "level" to (level?.toString() ?: "UNKNOWN"),
                "timestamp" to System.currentTimeMillis()
              )
            ))
          }

          override fun onBloodGlucoseStopDetect() {
            sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
              "data" to mapOf(
                "progress" to 100,
                "status" to "STOPPED",
                "timestamp" to System.currentTimeMillis()
              )
            ))
          }

          override fun onDetectError(opt: Int, status: EBloodGlucoseStatus?) {
            sendEvent(BLOOD_GLUCOSE_DATA, mapOf(
              "deviceId" to (connectedDeviceId ?: ""),
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
      if (!isInitialized || connectedDeviceId == null) {
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
  
  private fun startPressureLoop(firstPromise: Promise? = null) {
    if (!isPressureMeasuring) return
    
    val dataTypeList = java.util.ArrayList<DeviceManualDataType>()
    dataTypeList.add(DeviceManualDataType.STRESS)
    
    val emptyList = java.util.ArrayList<DeviceManualDataType>()
    
    VPOperateManager.getInstance().readDeviceManualData(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code != Code.REQUEST_SUCCESS) {
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
              } catch (e2: Exception) { }
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
  
  private fun cleanup() {
    val manager = VPOperateManager.getInstance()
    manager?.stopScanDevice()
    manager?.disconnectWatch(object : IBleWriteResponse {
      override fun onResponse(code: Int) {}
    })
    isScanning = false
    isPressureMeasuring = false
    connectedDeviceId = null
    isInitialized = false
  }
}
