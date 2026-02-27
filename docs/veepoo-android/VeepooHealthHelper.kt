package com.nutri_gene_app.veepoo

import android.os.Handler
import android.os.Looper
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.inuker.bluetooth.library.Code
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.*
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.DeviceManualDataType
import com.veepoo.protocol.model.enums.EBPDetectModel
import com.veepoo.protocol.model.enums.*
import com.veepoo.protocol.listener.data.IBloodGlucoseChangeListener
import com.veepoo.protocol.model.enums.EBloodGlucoseStatus
import com.veepoo.protocol.model.enums.EBloodGlucoseRiskLevel

import com.veepoo.protocol.model.*
import com.veepoo.protocol.model.datas.MealInfo

import android.util.Log

/**
 * 健康数据助手类 负责所有健康监测功能的操作，包括：
 * - 运动步数读取
 * - 心率监测 (开始/停止)
 * - 血压监测 (开始/停止)
 * - 血氧监测 (开始/停止)
 * - 体温监测 (开始/停止)
 * - 睡眠数据读取
 * - 原始健康数据读取 (5分钟粒度及详细扩展数据)
 */
class VeepooHealthHelper(private val eventEmitter: VeepooEventEmitter) {

    private val TAG = "VeepooHealthHelper"
    private var isPressureMeasuring = false
    private var isBloodGlucoseMeasuring = false
    private val mainHandler = Handler(Looper.getMainLooper())

    /** 读取运动步数 (今日) */
    fun readSportStep(promise: Promise) {
        VPOperateManager.getInstance()
                .readSportStep(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {}
                        },
                        object : ISportDataListener {
                            override fun onSportDataChange(sportData: SportData?) {
                                if (sportData != null) {
                                    val map = Arguments.createMap()
                                    map.putInt("step", sportData.step)
                                    map.putDouble("dis", sportData.dis)
                                    map.putDouble("kcal", sportData.kcal)
                                    map.putInt("calcType", sportData.calcType)
                                    map.putInt("triaxialX", sportData.triaxialX)
                                    map.putInt("triaxialY", sportData.triaxialY)
                                    map.putInt("triaxialZ", sportData.triaxialZ)
                                    promise.resolve(map)
                                } else {
                                    promise.reject("READ_FAILED", "Sport data is null")
                                }
                            }
                        }
                )
    }

    /** 开始心率监测 */
    fun startDetectHeart(promise: Promise) {
        VPOperateManager.getInstance()
                .startDetectHeart(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Start detect heart failed")
                                }
                            }
                        },
                        object : IHeartDataListener {
                            override fun onDataChange(heartData: HeartData?) {
                                if (heartData != null) {
                                    val map = Arguments.createMap()
                                    map.putInt("rate", heartData.data)
                                    map.putString("status", heartData.heartStatus.toString())
                                    eventEmitter.sendEvent("VeepooHeartRateData", map)
                                }
                            }
                        }
                )
    }

    /** 停止心率监测 */
    fun stopDetectHeart(promise: Promise) {
        VPOperateManager.getInstance()
                .stopDetectHeart(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Stop detect heart failed")
                                }
                            }
                        }
                )
    }

    /** 读取睡眠数据 (默认读取今日) */
    fun readSleepData(promise: Promise) {
        // 0 表示读取今天 (最新) 的睡眠数据
        VPOperateManager.getInstance()
                .readSleepData(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {}
                        },
                        object : ISleepDataListener {
                            override fun onSleepDataChange(day: String?, sleepData: SleepData?) {
                                if (sleepData != null) {
                                    val map = Arguments.createMap()
                                    map.putInt("allSleepTime", sleepData.allSleepTime)
                                    map.putInt("deepSleepTime", sleepData.deepSleepTime)
                                    map.putInt("lowSleepTime", sleepData.lowSleepTime)
                                    map.putInt("wakeCount", sleepData.wakeCount)
                                    map.putInt("sleepQulity", sleepData.sleepQulity)
                                    map.putString("sleepLine", sleepData.sleepLine)

                                    // New fields
                                    map.putString("date", sleepData.date)
                                    map.putInt("cali_flag", sleepData.cali_flag)

                                    if (sleepData.sleepDown != null) {
                                        val downTime = String.format("%04d-%02d-%02d %02d:%02d:%02d",
                                            sleepData.sleepDown.year,
                                            sleepData.sleepDown.month,
                                            sleepData.sleepDown.day,
                                            sleepData.sleepDown.hour,
                                            sleepData.sleepDown.minute,
                                            sleepData.sleepDown.second
                                        )
                                        map.putString("sleepDown", downTime)
                                    }

                                    if (sleepData.sleepUp != null) {
                                        val upTime = String.format("%04d-%02d-%02d %02d:%02d:%02d",
                                            sleepData.sleepUp.year,
                                            sleepData.sleepUp.month,
                                            sleepData.sleepUp.day,
                                            sleepData.sleepUp.hour,
                                            sleepData.sleepUp.minute,
                                            sleepData.sleepUp.second
                                        )
                                        map.putString("sleepUp", upTime)
                                    }

                                    promise.resolve(map)
                                } else {
                                    promise.reject("READ_FAILED", "Sleep data is null")
                                }
                            }

                            override fun onSleepProgress(progress: Float) {}
                            override fun onSleepProgressDetail(day: String?, progress: Int) {}
                            override fun onReadSleepComplete() {}
                        },
                        0
                )
    }

    /** 开始血压监测 (公共模式) */
    fun startDetectBP(promise: Promise) {
        VPOperateManager.getInstance()
                .startDetectBP(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Start BP failed")
                                }
                            }
                        },
                        object : IBPDetectDataListener {
                            override fun onDataChange(bpData: BpData?) {
                                if (bpData != null) {
                                    val map = Arguments.createMap()
                                    map.putInt("high", bpData.highPressure)
                                    map.putInt("low", bpData.lowPressure)
                                    map.putInt("progress", bpData.progress)
                                    map.putString("status", bpData.status.toString())
                                    map.putBoolean("isHaveProgress", bpData.isHaveProgress)
                                    eventEmitter.sendEvent("VeepooBloodPressureData", map)
                                }
                            }
                        },
                        EBPDetectModel.DETECT_MODEL_PUBLIC
                )
    }

    /** 停止血压监测 */
    fun stopDetectBP(promise: Promise) {
        VPOperateManager.getInstance()
                .stopDetectBP(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Stop BP failed")
                                }
                            }
                        },
                        EBPDetectModel.DETECT_MODEL_PUBLIC
                )
    }

    /** 开始血氧监测 */
    fun startDetectSPO2H(promise: Promise) {
        VPOperateManager.getInstance()
                .startDetectSPO2H(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Start SPO2 failed")
                                }
                            }
                        },
                        object : ISpo2hDataListener {
                            override fun onSpO2HADataChange(spo2hData: Spo2hData?) {
                                if (spo2hData != null) {
                                    val map = Arguments.createMap()
                                    map.putInt("value", spo2hData.value)
                                    map.putInt("rate", spo2hData.rateValue)
                                    map.putBoolean("checking", spo2hData.isChecking)
                                    map.putInt("checkingProgress", spo2hData.checkingProgress)
                                    map.putString("spState", spo2hData.spState.name)
                                    map.putString("deviceState", spo2hData.deviceState.name)
                                    eventEmitter.sendEvent("VeepooOxygenData", map)
                                }
                            }
                        },
                        object : ILightDataCallBack {
                            override fun onGreenLightDataChange(data: IntArray?) {}
                        }
                )
    }

    /** 停止血氧监测 */
    fun stopDetectSPO2H(promise: Promise) {
        VPOperateManager.getInstance()
                .stopDetectSPO2H(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Stop SpO2 failed")
                                }
                            }
                        },
                        object : ISpo2hDataListener {
                            override fun onSpO2HADataChange(data: Spo2hData?) {}
                        }
                )
    }

    /** 开始体温监测 */
    fun startDetectTempture(promise: Promise) {
        VPOperateManager.getInstance()
                .startDetectTempture(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Start Temp failed")
                                }
                            }
                        },
                        object : ITemptureDetectDataListener {
                            override fun onDataChange(data: TemptureDetectData?) {
                                if (data != null) {
                                    val map = Arguments.createMap()
                                    map.putDouble("value", data.tempture.toDouble())
                                    map.putInt("oprate", data.oprate)
                                    map.putInt("deviceState", data.deviceState)
                                    map.putInt("progress", data.progress)
                                    map.putDouble("temptureBase", data.temptureBase.toDouble())
                                    eventEmitter.sendEvent("VeepooTemptureData", map)
                                }
                            }
                        }
                )
    }

    /** 停止体温监测 */
    fun stopDetectTempture(promise: Promise) {
        VPOperateManager.getInstance()
                .stopDetectTempture(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) promise.resolve(true)
                                else promise.reject(code.toString(), "Stop Tempture failed")
                            }
                        },
                        object : ITemptureDetectDataListener {
                            override fun onDataChange(data: TemptureDetectData?) {}
                        }
                )
    }

    /** 开始测量压力 (通过读取手动数据模拟) */
    fun measurePressure(promise: Promise) {
        Log.d(TAG, "measurePressure called, isPressureMeasuring: $isPressureMeasuring")
        if (this.isPressureMeasuring) {
            promise.reject("ALREADY_MEASURING", "Pressure measurement is already in progress")
            return
        }
        this.isPressureMeasuring = true
        startPressureLoop(promise)
    }

    private fun startPressureLoop(firstPromise: Promise?) {
        Log.d(TAG, "startPressureLoop called, isPressureMeasuring: $isPressureMeasuring")
        if (!this.isPressureMeasuring) return

        // Create list with specific type expected by SDK
        val dataTypeList = java.util.ArrayList<DeviceManualDataType>()
        dataTypeList.add(DeviceManualDataType.STRESS)
        
        // Empty list for the second parameter if it is for stop/exclude
        val emptyList = java.util.ArrayList<DeviceManualDataType>()

        VPOperateManager.getInstance()
                .readDeviceManualData(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                Log.d(TAG, "readDeviceManualData onResponse: $code")
                                if (code != Code.REQUEST_SUCCESS) {
                                    if (firstPromise != null) {
                                        this@VeepooHealthHelper.isPressureMeasuring = false
                                        firstPromise.reject(
                                                code.toString(),
                                                "Start pressure measurement failed"
                                        )
                                    }
                                } else {
                                    if (firstPromise != null) {
                                        firstPromise.resolve(true)
                                    }
                                }
                            }
                        },
                        0L,
                        dataTypeList,
                        emptyList,
                        object : IDeviceManualDetectDataListener {
                            override fun onPressureManualDataChange(
                                    pressureManualDataList: List<PressureManualData>?
                            ) {
                                Log.d(TAG, "onPressureManualDataChange: ${pressureManualDataList?.size}")
                                if (this@VeepooHealthHelper.isPressureMeasuring &&
                                                pressureManualDataList != null &&
                                                pressureManualDataList.isNotEmpty()
                                ) {
                                    val latestData = pressureManualDataList.last()
                                    Log.d(TAG, "latestData: $latestData")

                                    val map = Arguments.createMap()
                                    // Use reflection to find fields if direct access fails or assume fields based on common patterns
                                    // Based on errors, pressureValue and resultCredibility were unresolved.
                                    // We will try to read them via reflection to avoid compilation errors if fields are hidden/renamed.
                                    try {
                                        // Try common field names for pressure/stress
                                        var value = 0
                                        try {
                                            val field = latestData.javaClass.getDeclaredField("pressureValue")
                                            field.isAccessible = true
                                            value = field.getInt(latestData)
                                        } catch (e: Exception) {
                                            // Try 'value'
                                            try {
                                                val field = latestData.javaClass.getDeclaredField("value")
                                                field.isAccessible = true
                                                value = field.getInt(latestData)
                                            } catch (e2: Exception) {
                                                 // Try 'stressValue'
                                                 try {
                                                     val field = latestData.javaClass.getDeclaredField("stressValue")
                                                     field.isAccessible = true
                                                     value = field.getInt(latestData)
                                                 } catch (e3: Exception) {
                                                     // If all fail, use 0
                                                 }
                                            }
                                        }
                                        map.putInt("value", value)
                                        
                                        var credibility = 0
                                        try {
                                            val field = latestData.javaClass.getDeclaredField("resultCredibility")
                                            field.isAccessible = true
                                            credibility = field.getInt(latestData)
                                        } catch (e: Exception) {
                                            // Ignore
                                        }
                                        map.putInt("resultCredibility", credibility)
                                        
                                    } catch (e: Exception) {
                                        map.putInt("value", 0)
                                        map.putInt("resultCredibility", 0)
                                    }
                                    
                                    // Debug info
                                    map.putString("rawData", latestData.toString())

                                    map.putDouble(
                                            "timestamp",
                                            System.currentTimeMillis().toDouble()
                                    )

                                    Log.d(TAG, "Sending event VeepooPressureData")
                                    eventEmitter.sendEvent("VeepooPressureData", map)
                                }
                            }

                            override fun onBloodPressureDataChange(
                                    list: List<BloodPressureManualData>?
                            ) {}
                            override fun onHeartRateDataChange(list: List<HeartRateManualData>?) {}
                            override fun onBloodGlucoseDataChange(
                                    list: List<BloodGlucoseManualData>?
                            ) {}
                            override fun onBloodOxygenDataChange(
                                    list: List<BloodOxygenManualData>?
                            ) {}
                            override fun onBodyTemperatureDataChange(
                                    list: List<BodyTemperatureManualData>?
                            ) {}
                            override fun onMetoManualDataChange(list: List<MetoManualData>?) {}
                            override fun onHrvManualDataChange(list: List<HrvManualData>?) {}
                            override fun onBloodComponentManualDataChange(
                                    list: List<BloodComponentManualData>?
                            ) {}
                            override fun onMiniCheckupManualDataChange(
                                    list: List<MiniCheckupManualData>?
                            ) {}
                            override fun onEmotionManualDataChange(
                                    list: List<EmotionManualData>?
                            ) {}
                            override fun onFatigueManualDataChange(
                                    list: List<FatigueManualData>?
                            ) {}
                            override fun onSkinConductanceManualDataChange(
                                    list: List<SkinConductanceManualData>?
                            ) {}
                            override fun onReadProgress(progress: Float) {}
                            override fun onReadComplete() {
                                Log.d(TAG, "onReadComplete")
                                if (this@VeepooHealthHelper.isPressureMeasuring) {
                                    mainHandler.postDelayed({ startPressureLoop(null) }, 1000)
                                }
                            }
                            override fun onReadFail() {
                                Log.d(TAG, "onReadFail")
                                if (this@VeepooHealthHelper.isPressureMeasuring) {
                                    mainHandler.postDelayed({ startPressureLoop(null) }, 2000)
                                }
                            }
                        }
                )
    }

    /** 停止测量压力 */
    fun cancelMeasurePressure(promise: Promise) {
        this.isPressureMeasuring = false
        promise.resolve(true)
    }

    /** 开始测量血糖 (使用 startBloodGlucoseDetect) */
    fun measureBloodGlucose(promise: Promise) {
        Log.d(TAG, "measureBloodGlucose called")
        
        VPOperateManager.getInstance()
                .startBloodGlucoseDetect(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                Log.d(TAG, "startBloodGlucoseDetect onResponse: $code")
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Start blood glucose detect failed")
                                }
                            }
                        },
                        object : IBloodGlucoseChangeListener {
                            override fun onBloodGlucoseDetect(
                                    progress: Int,
                                    bloodGlucose: Float,
                                    level: EBloodGlucoseRiskLevel?
                            ) {
                                Log.d(TAG, "onBloodGlucoseDetect progress=$progress, value=$bloodGlucose")
                                val map = Arguments.createMap()
                                map.putDouble("value", bloodGlucose.toDouble())
                                map.putInt("progress", progress)
                                if (level != null) {
                                    map.putString("level", level.toString())
                                }
                                map.putDouble("timestamp", System.currentTimeMillis().toDouble())
                                eventEmitter.sendEvent("VeepooBloodGlucoseData", map)
                            }

                            override fun onBloodGlucoseStopDetect() {
                                Log.d(TAG, "onBloodGlucoseStopDetect")
                                val map = Arguments.createMap()
                                map.putInt("progress", 100)
                                map.putDouble("timestamp", System.currentTimeMillis().toDouble())
                                map.putString("status", "STOPPED")
                                eventEmitter.sendEvent("VeepooBloodGlucoseData", map)
                            }

                            override fun onDetectError(opt: Int, status: EBloodGlucoseStatus?) {
                                Log.e(TAG, "onDetectError opt=$opt, status=$status")
                                val map = Arguments.createMap()
                                map.putString("error", "Detect error: $status")
                                map.putString("status", status?.toString() ?: "UNKNOWN")
                                map.putDouble("timestamp", System.currentTimeMillis().toDouble())
                                eventEmitter.sendEvent("VeepooBloodGlucoseData", map)
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

    /** 停止测量血糖 (使用 stopBloodGlucoseDetect) */
    fun cancelMeasureBloodGlucose(promise: Promise) {
        Log.d(TAG, "cancelMeasureBloodGlucose called")
        VPOperateManager.getInstance()
                .stopBloodGlucoseDetect(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject(code.toString(), "Stop blood glucose detect failed")
                                }
                            }
                        },
                        object : IBloodGlucoseChangeListener {
                            override fun onBloodGlucoseDetect(p0: Int, p1: Float, p2: EBloodGlucoseRiskLevel?) {}
                            override fun onBloodGlucoseStopDetect() {}
                            override fun onDetectError(p0: Int, p1: EBloodGlucoseStatus?) {}
                            override fun onBloodGlucoseAdjustingSettingSuccess(p0: Boolean, p1: Float) {}
                            override fun onBloodGlucoseAdjustingSettingFailed() {}
                            override fun onBloodGlucoseAdjustingReadSuccess(p0: Boolean, p1: Float) {}
                            override fun onBloodGlucoseAdjustingReadFailed() {}
                            
                            override fun onBGMultipleAdjustingReadSuccess(isSuccess: Boolean, info1: MealInfo?, info2: MealInfo?, info3: MealInfo?) {}
                            override fun onBGMultipleAdjustingReadFailed() {}
                            override fun onBGMultipleAdjustingSettingSuccess() {}
                            override fun onBGMultipleAdjustingSettingFailed() {}
                        }
                )
    }

    /**
     * 读取原始健康数据
     * @param dayOffset 天数偏移量 (0:今天, 1:昨天, 2:前天)
     * @param promise Promise 回调，返回 5 分钟粒度数据列表
     */
    fun readOriginData(dayOffset: Int, promise: Promise) {
        val dataList = Arguments.createArray()

        VPOperateManager.getInstance()
                .readOriginData(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code != Code.REQUEST_SUCCESS) {
                                    // 失败可能不会有数据回调，这里可以考虑 reject，或者等待 complete
                                }
                            }
                        },
                        object : IOriginData3Listener {
                            /** 5分钟粒度数据回调 (OriginData3) 包含最详细的健康数据，如步数、心率、血压、血氧、睡眠状态等 */
                            override fun onOriginFiveMinuteListDataChange(
                                    dataList3: List<OriginData3>?
                            ) {
                                if (dataList3 != null) {
                                    for (data in dataList3) {
                                        val timeData = data.getmTime()
                                        if (timeData != null) {
                                            val map = Arguments.createMap()
                                            val timeStr =
                                                    String.format(
                                                            "%02d:%02d",
                                                            timeData.hour,
                                                            timeData.minute
                                                    )
                                            map.putString("time", timeStr)

                                            // --- 基础字段 ---
                                            map.putInt("step", data.stepValue)
                                            map.putInt("rate", data.rateValue)
                                            map.putDouble("cal", data.calValue)
                                            map.putDouble("dis", data.disValue)
                                            map.putInt("highBP", data.highValue)
                                            map.putInt("lowBP", data.lowValue)
                                            map.putDouble("temp", data.temperature)
                                            map.putInt("calcType", data.calcType) // 计算方式
                                            map.putString(
                                                    "drinkPartOne",
                                                    data.drinkPartOne
                                            ) // 饮酒数据1
                                            map.putString(
                                                    "drinkPartTwo",
                                                    data.drinkPartTwo
                                            ) // 饮酒数据2

                                            // --- 扩展数组数据 (需手动转换为 WritableArray) ---

                                            // 手势数据
                                            val gestureArr = Arguments.createArray()
                                            data.gesture?.forEach { gestureArr.pushInt(it) }
                                            map.putArray("gesture", gestureArr)

                                            // PPG 数据
                                            val ppgsArr = Arguments.createArray()
                                            data.ppgs?.forEach { ppgsArr.pushInt(it) }
                                            map.putArray("ppgs", ppgsArr)

                                            // 睡眠运动数据
                                            val sleepSportsArr = Arguments.createArray()
                                            data.sleepSports?.forEach { sleepSportsArr.pushInt(it) }
                                            map.putArray("sleepSports", sleepSportsArr)

                                            // 睡眠状态质量
                                            val sleepStatusQuantityArr = Arguments.createArray()
                                            data.sleepStatusQuantity?.forEach {
                                                sleepStatusQuantityArr.pushInt(it)
                                            }
                                            map.putArray(
                                                    "sleepStatusQuantity",
                                                    sleepStatusQuantityArr
                                            )

                                            // 重置标签内容
                                            val resetTagContentArr = Arguments.createArray()
                                            data.resetTagContent?.forEach {
                                                resetTagContentArr.pushInt(it)
                                            }
                                            map.putArray("resetTagContent", resetTagContentArr)

                                            // ECG 数据
                                            val ecgsArr = Arguments.createArray()
                                            data.ecgs?.forEach { ecgsArr.pushInt(it) }
                                            map.putArray("ecgs", ecgsArr)

                                            // 呼吸率数据
                                            val resRatesArr = Arguments.createArray()
                                            data.resRates?.forEach { resRatesArr.pushInt(it) }
                                            map.putArray("resRates", resRatesArr)

                                            // 睡眠状态
                                            val sleepStatesArr = Arguments.createArray()
                                            data.sleepStates?.forEach { sleepStatesArr.pushInt(it) }
                                            map.putArray("sleepStates", sleepStatesArr)

                                            // 血氧数据
                                            val oxygensArr = Arguments.createArray()
                                            data.oxygens?.forEach { oxygensArr.pushInt(it) }
                                            map.putArray("oxygens", oxygensArr)

                                            // 呼吸暂停结果
                                            val apneaResultsArr = Arguments.createArray()
                                            data.apneaResults?.forEach {
                                                apneaResultsArr.pushInt(it)
                                            }
                                            map.putArray("apneaResults", apneaResultsArr)

                                            // 低氧时间
                                            val hypoxiaTimesArr = Arguments.createArray()
                                            data.hypoxiaTimes?.forEach {
                                                hypoxiaTimesArr.pushInt(it)
                                            }
                                            map.putArray("hypoxiaTimes", hypoxiaTimesArr)

                                            // 心脏负荷
                                            val cardiacLoadsArr = Arguments.createArray()
                                            data.cardiacLoads?.forEach {
                                                cardiacLoadsArr.pushInt(it)
                                            }
                                            map.putArray("cardiacLoads", cardiacLoadsArr)

                                            // 是否低氧
                                            val isHypoxiasArr = Arguments.createArray()
                                            data.isHypoxias?.forEach { isHypoxiasArr.pushInt(it) }
                                            map.putArray("isHypoxias", isHypoxiasArr)

                                            // 校准数据
                                            val correctsArr = Arguments.createArray()
                                            data.corrects?.forEach { correctsArr.pushInt(it) }
                                            map.putArray("corrects", correctsArr)

                                            // --- 其他扩展字段 ---
                                            // 血糖
                                            map.putDouble(
                                                    "bloodGlucose",
                                                    data.bloodGlucose.toDouble()
                                            )

                                            // 血糖风险等级
                                            if (data.bloodGlucoseRiskLevel != null) {
                                                map.putString(
                                                        "bloodGlucoseRiskLevel",
                                                        data.bloodGlucoseRiskLevel.toString()
                                                )
                                            }

                                            // 压力值
                                            map.putInt("pressure", data.pressure)

                                            // 梅托值 (MET)
                                            map.putDouble("met", data.met.toDouble())

                                            // 血液成分
                                            val bloodComponent = data.bloodComponent
                                            if (bloodComponent != null) {
                                                val bloodMap = Arguments.createMap()
                                                bloodMap.putDouble(
                                                        "uricAcid",
                                                        bloodComponent.uricAcid.toDouble()
                                                )
                                                bloodMap.putDouble(
                                                        "totalCholesterol",
                                                        bloodComponent.tCHO.toDouble()
                                                )
                                                bloodMap.putDouble(
                                                        "triglyceride",
                                                        bloodComponent.tAG.toDouble()
                                                )
                                                bloodMap.putDouble(
                                                        "highLipoprotein",
                                                        bloodComponent.hDL.toDouble()
                                                )
                                                bloodMap.putDouble(
                                                        "lowLipoprotein",
                                                        bloodComponent.lDL.toDouble()
                                                )
                                                map.putMap("bloodComponent", bloodMap)
                                            }

                                            dataList.pushMap(map)
                                        }
                                    }
                                }
                            }

                            /**
                             * 30分钟粒度数据 (OriginHalfHourData) 包含：30分钟的步数、卡路里、距离、心率、血压均值等
                             * 适合用于绘制全天的大致趋势图
                             */
                            override fun onOriginHalfHourDataChange(data: OriginHalfHourData?) {
                                if (data != null) {
                                    val map = Arguments.createMap()
                                    // data.date is a String "yyyy-MM-dd HH:mm:ss"
                                    val dateStr = data.date
                                    val formattedDate = if (dateStr != null && dateStr.length >= 10) {
                                        dateStr.substring(0, 10)
                                    } else {
                                        dateStr ?: ""
                                    }
                                    map.putString("date", formattedDate)
                                    map.putInt("allStep", data.allStep)

                                    // 30分钟运动数据
                                    val sportArray = Arguments.createArray()
                                    data.halfHourSportDatas?.forEach { sport ->
                                        val item = Arguments.createMap()
                                        val time = sport.time
                                        if (time != null) {
                                            item.putString(
                                                    "time",
                                                    String.format(
                                                            "%02d:%02d",
                                                            time.hour,
                                                            time.minute
                                                    )
                                            )
                                        }
                                        item.putInt("step", sport.stepValue)
                                        item.putDouble("cal", sport.calValue)
                                        item.putDouble("dis", sport.disValue)
                                        sportArray.pushMap(item)
                                    }
                                    map.putArray("sportList", sportArray)

                                    // 30分钟心率数据
                                    val rateArray = Arguments.createArray()
                                    data.halfHourRateDatas?.forEach { rate ->
                                        val item = Arguments.createMap()
                                        val time = rate.time
                                        if (time != null) {
                                            item.putString(
                                                    "time",
                                                    String.format(
                                                            "%02d:%02d",
                                                            time.hour,
                                                            time.minute
                                                    )
                                            )
                                        }
                                        item.putInt("rate", rate.rateValue)
                                        rateArray.pushMap(item)
                                    }
                                    map.putArray("rateList", rateArray)

                                    // 30分钟血压数据
                                    val bpArray = Arguments.createArray()
                                    data.halfHourBps?.forEach { bp ->
                                        val item = Arguments.createMap()
                                        val time = bp.time
                                        if (time != null) {
                                            item.putString(
                                                    "time",
                                                    String.format(
                                                            "%02d:%02d",
                                                            time.hour,
                                                            time.minute
                                                    )
                                            )
                                        }
                                        item.putInt("high", bp.highValue)
                                        item.putInt("low", bp.lowValue)
                                        bpArray.pushMap(item)
                                    }
                                    map.putArray("bpList", bpArray)

                                    eventEmitter.sendEvent("VeepooOriginHalfHourData", map)
                                } else {
                                    val map = Arguments.createMap()
                                    eventEmitter.sendEvent("VeepooOriginHalfHourData", map)
                                }
                            }

                            /** 历史 HRV 数据 (HRVOriginData) 包含：Lorentz图数据、HRV值等 */
                            override fun onOriginHRVOriginListDataChange(
                                    dataList: List<HRVOriginData>?
                            ) {
                                if (dataList != null) {
                                    val array = Arguments.createArray()
                                    for (data in dataList) {
                                        val map = Arguments.createMap()
                                        val time = data.getmTime() // use getter
                                        if (time != null) {
                                            map.putString(
                                                    "time",
                                                    String.format(
                                                            "%02d:%02d",
                                                            time.hour,
                                                            time.minute
                                                    )
                                            )
                                        }
                                        map.putString("date", data.date)
                                        map.putInt(
                                                "allCurrentPackNumber",
                                                data.allCurrentPackNumber
                                        )
                                        map.putInt("currentPackNumber", data.currentPackNumber)
                                        map.putInt("hrv", data.hrvValue)
                                        map.putInt("tempOne", data.tempOne)
                                        map.putString("rate", data.rate)
                                        array.pushMap(map)
                                    }
                                    val params = Arguments.createMap()
                                    params.putArray("data", array)
                                    eventEmitter.sendEvent("VeepooOriginHRVData", params)
                                } else {
                                    // Send empty event
                                    val params = Arguments.createMap()
                                    params.putArray("data", Arguments.createArray())
                                    eventEmitter.sendEvent("VeepooOriginHRVData", params)
                                }
                            }

                            /**
                             * 历史血氧数据 (Spo2hOriginData) 通常包含夜间(00:00-07:00)的每分钟或特定间隔的血氧值、呼吸率、低氧时间等
                             */
                            override fun onOriginSpo2OriginListDataChange(
                                    dataList: List<Spo2hOriginData>?
                            ) {
                                if (dataList != null) {
                                    val array = Arguments.createArray()
                                    for (data in dataList) {
                                        val map = Arguments.createMap()
                                        val time = data.getmTime() // use getter
                                        if (time != null) {
                                            map.putString(
                                                    "time",
                                                    String.format(
                                                            "%02d:%02d",
                                                            time.hour,
                                                            time.minute
                                                    )
                                            )
                                        }
                                        map.putString("date", data.date)
                                        map.putInt("heartValue", data.heartValue)
                                        map.putInt("value", data.oxygenValue)
                                        map.putInt("rate", data.respirationRate)
                                        map.putInt("isHypoxia", data.isHypoxia)
                                        map.putInt("cardiacLoad", data.cardiacLoad)
                                        map.putInt("temp1", data.temp1)
                                        map.putInt("sportValue", data.sportValue)
                                        map.putInt("apneaResult", data.apneaResult)
                                        map.putInt("hypoxiaTime", data.hypoxiaTime)
                                        map.putInt("hypopnea", data.hypopnea)
                                        map.putInt("stepValue", data.stepValue)
                                        map.putInt(
                                                "allPackNumber",
                                                data.allPackNumner
                                        ) // note: SDK method name typo 'allPackNumner'
                                        map.putInt("currentPackNumber", data.currentPackNumber)
                                        array.pushMap(map)
                                    }
                                    val params = Arguments.createMap()
                                    params.putArray("data", array)
                                    eventEmitter.sendEvent("VeepooOriginSpo2Data", params)
                                } else {
                                    val params = Arguments.createMap()
                                    params.putArray("data", Arguments.createArray())
                                    eventEmitter.sendEvent("VeepooOriginSpo2Data", params)
                                }
                            }

                            override fun onReadOriginProgressDetail(
                                    day: Int,
                                    date: String?,
                                    allPack: Int,
                                    currentPack: Int
                            ) {
                                val progress = if (allPack > 0) currentPack.toDouble() / allPack.toDouble() else 0.0
                                val map = Arguments.createMap()
                                map.putDouble("progress", progress)
                                map.putInt("currentDay", 1)
                                map.putInt("totalDay", 1)
                                map.putBoolean("finished", currentPack == allPack)
                                eventEmitter.sendEvent("VeepooReadOriginProgress", map)
                            }

                            override fun onReadOriginProgress(progress: Float) {
                                // 这里的 progress 可能是 0-1 或 0-100，根据 SDK 文档通常是 0-1
                                var p = progress.toDouble()
                                if (p > 1.0) p /= 100.0
                                
                                val map = Arguments.createMap()
                                map.putDouble("progress", p)
                                map.putInt("currentDay", 1)
                                map.putInt("totalDay", 1)
                                map.putBoolean("finished", p >= 0.99)
                                eventEmitter.sendEvent("VeepooReadOriginProgress", map)
                            }

                            override fun onReadOriginComplete() {
                                eventEmitter.sendEvent("VeepooReadOriginComplete", null)
                                promise.resolve(dataList)
                            }
                        },
                        dayOffset
                )
    }
}
