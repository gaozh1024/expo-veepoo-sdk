package expo.modules.veepoo

import android.util.Log
import com.inuker.bluetooth.library.Code
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.*
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.EOprateStauts
import com.veepoo.protocol.model.enums.ESex
import com.veepoo.protocol.model.settings.*
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

fun buildHalfHourItems(data: OriginHalfHourData): List<Map<String, Any>> {
  val map = linkedMapOf<String, MutableMap<String, Any>>()

  fun timeKey(time: TimeData?): String? {
    return time?.let { String.format("%02d:%02d", it.hour, it.minute) }
  }

  fun entry(key: String): MutableMap<String, Any> {
    return map.getOrPut(key) { mutableMapOf("time" to key) }
  }

  data.halfHourSportDatas?.forEach { sport ->
    val key = timeKey(sport.time) ?: return@forEach
    val item = entry(key)
    item["stepValue"] = sport.stepValue
    item["calValue"] = sport.calValue
    item["disValue"] = sport.disValue
  }

  data.halfHourRateDatas?.forEach { rate ->
    val key = timeKey(rate.time) ?: return@forEach
    entry(key)["heartValue"] = rate.rateValue
  }

  data.halfHourBps?.forEach { bp ->
    val key = timeKey(bp.time) ?: return@forEach
    val item = entry(key)
    item["systolic"] = bp.highValue
    item["diastolic"] = bp.lowValue
  }

  return map.keys.sorted().map { key ->
    val item = map[key]!!
    if (!item.containsKey("sportValue")) item["sportValue"] = 0
    if (!item.containsKey("systolic")) item["systolic"] = 0
    if (!item.containsKey("diastolic")) item["diastolic"] = 0
    if (!item.containsKey("spo2Value")) item["spo2Value"] = 0
    if (!item.containsKey("tempValue")) item["tempValue"] = 0
    if (!item.containsKey("stressValue")) item["stressValue"] = 0
    item
  }
}

// 读取与同步数据
fun ModuleDefinitionBuilder.defineReadData(module: VeepooSDKModule) {
  AsyncFunction("readBattery") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
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
            val actualLevel = if (batteryData.isPercent) batteryData.batteryPercent else batteryData.batteryLevel
            promise.resolve(mapOf(
              "level" to actualLevel,
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
    if (!module.isInitialized || module.connectedDeviceId == null) {
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
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "readDeviceFunctions: returning ${module.cachedDeviceFunctions.size} function packages")
    promise.resolve(module.cachedDeviceFunctions.toMap())
  }

  AsyncFunction("readSocialMsgData") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    promise.resolve(emptyMap<String, Any>())
  }

  AsyncFunction("readDeviceVersion") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "readDeviceVersion: reading device version info")
    
    val result = mapOf(
      "hardwareVersion" to module.cachedDeviceVersion,
      "firmwareVersion" to "",
      "softwareVersion" to "",
      "deviceNumber" to module.cachedDeviceNumber,
      "newVersion" to "",
      "description" to ""
    )
    
    module.sendEvent(DEVICE_VERSION, mapOf(
      "deviceId" to (module.connectedDeviceId ?: ""),
      "version" to result
    ))
    
    Log.d(TAG, "readDeviceVersion: $result")
    promise.resolve(result)
  }

  AsyncFunction("startReadOriginData") { promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
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
            
            for (data in dataList3) {
              try {
                val timeData = data.getmTime()
                if (timeData != null) {
                  val timeStr = String.format("%02d:%02d", timeData.hour, timeData.minute)
                  
                  val item = mutableMapOf(
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
                  
                  data.oxygens?.let { item["oxygens"] = it.toList() }
                  data.ppgs?.let { item["ppgs"] = it.toList() }
                  data.ecgs?.let { item["ecgs"] = it.toList() }
                  data.resRates?.let { item["resRates"] = it.toList() }
                  data.sleepStates?.let { item["sleepStates"] = it.toList() }
                  data.apneaResults?.let { item["apneaResults"] = it.toList() }
                  data.hypoxiaTimes?.let { item["hypoxiaTimes"] = it.toList() }
                  data.cardiacLoads?.let { item["cardiacLoads"] = it.toList() }
                  data.bloodGlucose.let { item["bloodGlucose"] = it }
                  
                  module.sendEvent(ORIGIN_FIVE_MINUTE_DATA, mapOf(
                    "deviceId" to (module.connectedDeviceId ?: ""),
                    "data" to item
                  ))
                }
              } catch (e: Exception) {
                Log.e(TAG, "Error processing 5-minute data item", e)
              }
            }
          }
        }
        
        override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {
          try {
            if (data != null) {
              val items = buildHalfHourItems(data)
              for (item in items) {
                module.sendEvent(ORIGIN_HALF_HOUR_DATA, mapOf(
                  "deviceId" to (module.connectedDeviceId ?: ""),
                  "data" to item
                ))
              }
            }
          } catch (e: Exception) {
            Log.e(TAG, "Error in onOriginHalfHourDataChange", e)
            module.sendEvent(ERROR, mapOf(
              "code" to "ORIGIN_DATA_ERROR",
              "message" to (e.message ?: "Unknown error processing origin data"),
              "deviceId" to (module.connectedDeviceId ?: "")
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
            
            try {
              val items = mutableListOf<Map<String, Any>>()
              
              for (data in dataList) {
                val timeData = data.getmTime()
                val timeStr = if (timeData != null) {
                  String.format("%02d:%02d", timeData.hour, timeData.minute)
                } else {
                  ""
                }
                
                val item = mutableMapOf<String, Any>(
                  "time" to timeStr,
                  "date" to (data.date ?: ""),
                  "heartValue" to data.heartValue,
                  "value" to data.oxygenValue,
                  "rate" to data.respirationRate,
                  "isHypoxia" to data.isHypoxia,
                  "cardiacLoad" to data.cardiacLoad,
                  "temp1" to data.temp1,
                  "sportValue" to data.sportValue,
                  "apneaResult" to data.apneaResult,
                  "hypoxiaTime" to data.hypoxiaTime,
                  "hypopnea" to data.hypopnea,
                  "stepValue" to data.stepValue,
                  "allPackNumber" to data.allPackNumner,
                  "currentPackNumber" to data.currentPackNumber
                )
                
                items.add(item)
              }
              
              module.sendEvent(ORIGIN_SPO2_DATA, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "data" to items
              ))
            } catch (e: Exception) {
              Log.e(TAG, "Error processing SPO2 origin data", e)
            }
          }
        }
        
        override fun onReadOriginProgressDetail(day: Int, date: String?, allPack: Int, currentPack: Int) {
          try {
            val progress = if (allPack > 0) currentPack.toDouble() / allPack.toDouble() else 0.0
            Log.d(TAG, "onReadOriginProgressDetail: day=$day, progress=$progress")
            
            module.sendEvent(READ_ORIGIN_PROGRESS, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
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
            
            module.sendEvent(READ_ORIGIN_PROGRESS, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
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
            
            module.sendEvent(READ_ORIGIN_COMPLETE, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "success" to true
            ))
            
            promise.resolve(null)
          } catch (e: Exception) {
            Log.e(TAG, "Error in onReadOriginComplete", e)
            module.sendEvent(READ_ORIGIN_COMPLETE, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
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
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "readDeviceAllData: starting to read all device data")
    
    module.sendEvent(READ_ORIGIN_PROGRESS, mapOf(
      "deviceId" to (module.connectedDeviceId ?: ""),
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
            
            for (data in dataList3) {
              try {
                val timeData = data.getmTime()
                if (timeData != null) {
                  val timeStr = String.format("%02d:%02d", timeData.hour, timeData.minute)
                  
                  val item = mutableMapOf(
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
                  
                  data.oxygens?.let { item["oxygens"] = it.toList() }
                  data.ppgs?.let { item["ppgs"] = it.toList() }
                  data.ecgs?.let { item["ecgs"] = it.toList() }
                  data.resRates?.let { item["resRates"] = it.toList() }
                  data.sleepStates?.let { item["sleepStates"] = it.toList() }
                  data.apneaResults?.let { item["apneaResults"] = it.toList() }
                  data.hypoxiaTimes?.let { item["hypoxiaTimes"] = it.toList() }
                  data.cardiacLoads?.let { item["cardiacLoads"] = it.toList() }
                  data.bloodGlucose.let { item["bloodGlucose"] = it }
                  
                  module.sendEvent(ORIGIN_FIVE_MINUTE_DATA, mapOf(
                    "deviceId" to (module.connectedDeviceId ?: ""),
                    "data" to item
                  ))
                }
              } catch (e: Exception) {
                Log.e(TAG, "Error processing 5-minute data item in readDeviceAllData", e)
              }
            }
          }
        }
        
        override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {
          if (data != null) {
            val items = buildHalfHourItems(data)
            for (item in items) {
              module.sendEvent(ORIGIN_HALF_HOUR_DATA, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "data" to item
              ))
            }
          }
        }
        
        override fun onOriginHRVOriginListDataChange(dataList: List<HRVOriginData>?) {}
        
        override fun onOriginSpo2OriginListDataChange(dataList: List<Spo2hOriginData>?) {
          if (dataList != null && dataList.isNotEmpty()) {
            Log.d(TAG, "readDeviceAllData: onOriginSpo2OriginListDataChange: ${dataList.size} records")
            
            try {
              val items = mutableListOf<Map<String, Any>>()
              
              for (data in dataList) {
                val timeData = data.getmTime()
                val timeStr = if (timeData != null) {
                  String.format("%02d:%02d", timeData.hour, timeData.minute)
                } else {
                  ""
                }
                
                val item = mutableMapOf<String, Any>(
                  "time" to timeStr,
                  "date" to (data.date ?: ""),
                  "heartValue" to data.heartValue,
                  "value" to data.oxygenValue,
                  "rate" to data.respirationRate,
                  "isHypoxia" to data.isHypoxia,
                  "cardiacLoad" to data.cardiacLoad,
                  "temp1" to data.temp1,
                  "sportValue" to data.sportValue,
                  "apneaResult" to data.apneaResult,
                  "hypoxiaTime" to data.hypoxiaTime,
                  "hypopnea" to data.hypopnea,
                  "stepValue" to data.stepValue,
                  "allPackNumber" to data.allPackNumner,
                  "currentPackNumber" to data.currentPackNumber
                )
                
                items.add(item)
              }
              
              module.sendEvent(ORIGIN_SPO2_DATA, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "data" to items
              ))
            } catch (e: Exception) {
              Log.e(TAG, "Error processing SPO2 origin data in readDeviceAllData", e)
            }
          }
        }
        
        override fun onReadOriginProgressDetail(day: Int, date: String?, allPack: Int, currentPack: Int) {
          val progress = if (allPack > 0) currentPack.toDouble() / allPack.toDouble() else 0.0
          Log.d(TAG, "readDeviceAllData: onReadOriginProgressDetail: day=$day, progress=$progress")
          
          module.sendEvent(READ_ORIGIN_PROGRESS, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
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
          
          module.sendEvent(READ_ORIGIN_PROGRESS, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
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
          
          module.sendEvent(READ_ORIGIN_PROGRESS, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "progress" to mapOf(
              "readState" to "complete",
              "totalDays" to 1,
              "currentDay" to 1,
              "progress" to 1.0
            )
          ))
          
          module.sendEvent(READ_ORIGIN_COMPLETE, mapOf(
            "deviceId" to (module.connectedDeviceId ?: ""),
            "success" to true
          ))
          
          promise.resolve(true)
        }
      },
      0
    )
  }

  AsyncFunction("readSleepData") { date: String?, promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "readSleepData: reading sleep data")
    
    val isPromiseResolved = java.util.concurrent.atomic.AtomicBoolean(false)
    
    fun createEmptySleepResult(): List<Map<String, Any>> = listOf(mapOf(
      "date" to (date ?: ""),
      "items" to emptyList<Any>(),
      "summary" to mapOf(
        "totalDeepSleepMinutes" to 0,
        "totalLightSleepMinutes" to 0,
        "totalSleepMinutes" to 0,
        "averageSleepQuality" to 0,
        "totalWakeUpCount" to 0
      )
    ))
    
    fun resolveSleepOnce(result: List<Map<String, Any>>) {
      if (isPromiseResolved.compareAndSet(false, true)) {
        module.mainHandler.removeCallbacksAndMessages(null)
        promise.resolve(result)
      }
    }
    
    val timeoutRunnable = Runnable {
      Log.w(TAG, "readSleepData: timeout, returning empty result")
      resolveSleepOnce(createEmptySleepResult())
    }
    module.mainHandler.postDelayed(timeoutRunnable, 15000)
    
    manager.readSleepData(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code != Code.REQUEST_SUCCESS) {
            Log.e(TAG, "readSleepData: command failed with code $code, returning empty result")
            resolveSleepOnce(createEmptySleepResult())
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
            
            val deepSleepMinutes = sleepData.deepSleepTime
            val lightSleepMinutes = sleepData.lowSleepTime
            val totalSleepMinutes = sleepData.allSleepTime
            val sleepQuality = sleepData.sleepQulity
            val wakeUpCount = sleepData.wakeCount
            
            val item = mapOf(
              "date" to (sleepData.date ?: ""),
              "sleepTime" to sleepDownStr,
              "wakeTime" to sleepUpStr,
              "deepSleepMinutes" to deepSleepMinutes,
              "lightSleepMinutes" to lightSleepMinutes,
              "totalSleepMinutes" to totalSleepMinutes,
              "sleepQuality" to sleepQuality,
              "sleepLine" to (sleepData.sleepLine ?: ""),
              "wakeUpCount" to wakeUpCount
            )
            
            val items = listOf(item)
            
            val summary = mapOf(
              "totalDeepSleepMinutes" to deepSleepMinutes,
              "totalLightSleepMinutes" to lightSleepMinutes,
              "totalSleepMinutes" to totalSleepMinutes,
              "averageSleepQuality" to sleepQuality,
              "totalWakeUpCount" to wakeUpCount
            )
            
            val result = mapOf(
              "date" to (sleepData.date ?: ""),
              "items" to items,
              "summary" to summary
            )
            
            val resultList = listOf(result)
            
            module.sendEvent(SLEEP_DATA, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "date" to (sleepData.date ?: ""),
              "data" to resultList
            ))
            
            resolveSleepOnce(resultList)
          } else {
            Log.d(TAG, "onSleepDataChange: sleepData is null")
            resolveSleepOnce(createEmptySleepResult())
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
      module.watchday
    )
  }

  AsyncFunction("readSportStepData") { date: String?, promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
      promise.reject("DEVICE_NOT_CONNECTED", "Device not connected", null)
      return@AsyncFunction
    }
    
    val manager = VPOperateManager.getInstance() ?: run {
      promise.reject("SDK_NOT_INITIALIZED", "SDK manager is null", null)
      return@AsyncFunction
    }
    
    Log.d(TAG, "readSportStepData: reading sport step data")
    
    val isPromiseResolved = java.util.concurrent.atomic.AtomicBoolean(false)
    
    fun createEmptySportResult(): Map<String, Any> = mapOf(
      "date" to (date ?: ""),
      "stepCount" to 0,
      "distance" to 0.0,
      "calories" to 0.0
    )
    
    fun resolveSportOnce(result: Map<String, Any>) {
      if (isPromiseResolved.compareAndSet(false, true)) {
        module.mainHandler.removeCallbacksAndMessages(null)
        promise.resolve(result)
      }
    }
    
    val timeoutRunnable = Runnable {
      Log.w(TAG, "readSportStepData: timeout, returning empty result")
      resolveSportOnce(createEmptySportResult())
    }
    module.mainHandler.postDelayed(timeoutRunnable, 15000)
    
    manager.readSportStep(
      object : IBleWriteResponse {
        override fun onResponse(code: Int) {
          if (code != Code.REQUEST_SUCCESS) {
            Log.e(TAG, "readSportStepData: command failed with code $code, returning empty result")
            resolveSportOnce(createEmptySportResult())
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
            
            module.sendEvent(SPORT_STEP_DATA, mapOf(
              "deviceId" to (module.connectedDeviceId ?: ""),
              "date" to (date ?: ""),
              "data" to result
            ))
            
            resolveSportOnce(result)
          } else {
            Log.d(TAG, "onSportDataChange: sportData is null")
            resolveSportOnce(createEmptySportResult())
          }
        }
      }
    )
  }

  AsyncFunction("readOriginData") { dayOffset: Int, promise: Promise ->
    if (!module.isInitialized || module.connectedDeviceId == null) {
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
                
                val item = mutableMapOf(
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
                
                data.oxygens?.let { item["oxygens"] = it.toList() }
                data.ppgs?.let { item["ppgs"] = it.toList() }
                data.ecgs?.let { item["ecgs"] = it.toList() }
                data.resRates?.let { item["resRates"] = it.toList() }
                data.sleepStates?.let { item["sleepStates"] = it.toList() }
                data.apneaResults?.let { item["apneaResults"] = it.toList() }
                data.hypoxiaTimes?.let { item["hypoxiaTimes"] = it.toList() }
                data.cardiacLoads?.let { item["cardiacLoads"] = it.toList() }
                data.bloodGlucose.let { item["bloodGlucose"] = it }
                
                dataList.add(item)
              }
            }
          }
        }
        
        override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {}
        
        override fun onOriginHRVOriginListDataChange(dataList: List<HRVOriginData>?) {}
        
        override fun onOriginSpo2OriginListDataChange(spo2List: List<Spo2hOriginData>?) {
          if (spo2List != null && spo2List.isNotEmpty()) {
            Log.d(TAG, "readOriginData: onOriginSpo2OriginListDataChange: ${spo2List.size} records")
            
            try {
              val items = mutableListOf<Map<String, Any>>()
              
              for (data in spo2List) {
                val timeData = data.getmTime()
                val timeStr = if (timeData != null) {
                  String.format("%02d:%02d", timeData.hour, timeData.minute)
                } else {
                  ""
                }
                
                val item = mutableMapOf<String, Any>(
                  "time" to timeStr,
                  "date" to (data.date ?: ""),
                  "heartValue" to data.heartValue,
                  "value" to data.oxygenValue,
                  "rate" to data.respirationRate,
                  "isHypoxia" to data.isHypoxia,
                  "cardiacLoad" to data.cardiacLoad,
                  "temp1" to data.temp1,
                  "sportValue" to data.sportValue,
                  "apneaResult" to data.apneaResult,
                  "hypoxiaTime" to data.hypoxiaTime,
                  "hypopnea" to data.hypopnea,
                  "stepValue" to data.stepValue,
                  "allPackNumber" to data.allPackNumner,
                  "currentPackNumber" to data.currentPackNumber
                )
                
                items.add(item)
              }
              
              module.sendEvent(ORIGIN_SPO2_DATA, mapOf(
                "deviceId" to (module.connectedDeviceId ?: ""),
                "data" to items
              ))
            } catch (e: Exception) {
              Log.e(TAG, "Error processing SPO2 origin data in readOriginData", e)
            }
          }
        }
        
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
}
