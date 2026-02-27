package com.nutri_gene_app.veepoo

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule

/** Veepoo SDK 桥接模块 用于在 React Native 中调用 Veepoo Android SDK 的功能 */
@ReactModule(name = "VeepooBleModule")
class VeepooBleModule(reactContext: ReactApplicationContext) :
        ReactContextBaseJavaModule(reactContext) {

    private val eventEmitter = VeepooEventEmitter(reactContext)
    private val connectionHelper = VeepooConnectionHelper(reactContext, eventEmitter)
    private val deviceHelper = VeepooDeviceHelper(reactContext, eventEmitter)
    private val healthHelper = VeepooHealthHelper(eventEmitter)

    override fun getName(): String {
        return "VeepooBleModule"
    }

    // Required for React Native built-in Event Emitter Calls
    @ReactMethod fun addListener(eventName: String) {}

    @ReactMethod fun removeListeners(count: Int) {}

    /** 初始化 SDK 在 App 启动或组件挂载时调用 */
    @ReactMethod
    fun initSDK() {
        connectionHelper.initSDK()
    }

    /**
     * 连接设备
     * @param macAddress 设备 MAC 地址
     * @param uuid 设备 UUID (Android 忽略)
     * @param promise Promise 回调
     */
    @ReactMethod
    fun connectDevice(macAddress: String, uuid: String?, promise: Promise) {
        connectionHelper.connectDevice(macAddress, promise)
    }

    /**
     * 断开连接
     * @param macAddress 设备 MAC 地址
     */
    @ReactMethod
    fun disconnectDevice(macAddress: String) {
        connectionHelper.disconnectDevice(macAddress)
    }

    /**
     * 验证密码 (连接成功后必须调用)
     * @param password 密码 (默认 "0000")
     * @param is24HourModel 是否 24 小时制
     */
    @ReactMethod
    fun verifyPassword(password: String, is24HourModel: Boolean, promise: Promise) {
        connectionHelper.verifyPassword(password, is24HourModel, promise)
    }

    /** 开始扫描 (如果不想用 ble-plx) */
    @ReactMethod
    fun startScan() {
        connectionHelper.startScan()
    }

    /** 停止扫描 (如果不想用 ble-plx) */
    @ReactMethod
    fun stopScan() {
        connectionHelper.stopScan()
    }

    /** 读取电量 */
    @ReactMethod
    fun readBattery(promise: Promise) {
        deviceHelper.readBattery(promise)
    }

    /** 读取自动测量设置 */
    @ReactMethod
    fun readAutoMeasureSetting(promise: Promise) {
        deviceHelper.readAutoMeasureSetting(promise)
    }

    /** 修改自动测量设置 */
    @ReactMethod
    fun modifyAutoMeasureSetting(setting: ReadableMap, promise: Promise) {
        deviceHelper.modifyAutoMeasureSetting(setting, promise)
    }

    /** 读取运动步数 */
    @ReactMethod
    fun readSportStep(promise: Promise) {
        healthHelper.readSportStep(promise)
    }

    /** 开始心率监测 */
    @ReactMethod
    fun startDetectHeart(promise: Promise) {
        healthHelper.startDetectHeart(promise)
    }

    /** 停止心率监测 */
    @ReactMethod
    fun stopDetectHeart(promise: Promise) {
        healthHelper.stopDetectHeart(promise)
    }

    /** 读取睡眠数据 (今日) */
    @ReactMethod
    fun readSleepData(promise: Promise) {
        healthHelper.readSleepData(promise)
    }

    /** 开始血压测量 */
    @ReactMethod
    fun startDetectBP(promise: Promise) {
        healthHelper.startDetectBP(promise)
    }

    /** 停止血压测量 */
    @ReactMethod
    fun stopDetectBP(promise: Promise) {
        healthHelper.stopDetectBP(promise)
    }

    /** 开始血氧测量 */
    @ReactMethod
    fun startDetectSPO2H(promise: Promise) {
        healthHelper.startDetectSPO2H(promise)
    }

    /** 停止血氧测量 */
    @ReactMethod
    fun stopDetectSPO2H(promise: Promise) {
        healthHelper.stopDetectSPO2H(promise)
    }

    /** 开始体温测量 */
    @ReactMethod
    fun startDetectTempture(promise: Promise) {
        healthHelper.startDetectTempture(promise)
    }

    /** 停止体温监测 */
    @ReactMethod
    fun stopDetectTempture(promise: Promise) {
        healthHelper.stopDetectTempture(promise)
    }

    /** 开始测量压力 */
    @ReactMethod
    fun measurePressure(promise: Promise) {
        healthHelper.measurePressure(promise)
    }

    /** 停止测量压力 */
    @ReactMethod
    fun cancelMeasurePressure(promise: Promise) {
        healthHelper.cancelMeasurePressure(promise)
    }

    /** 开始测量血糖 */
    @ReactMethod
    fun measureBloodGlucose(promise: Promise) {
        healthHelper.measureBloodGlucose(promise)
    }

    /** 停止测量血糖 */
    @ReactMethod
    fun cancelMeasureBloodGlucose(promise: Promise) {
        healthHelper.cancelMeasureBloodGlucose(promise)
    }

    /**
     * 同步个人信息
     * @param sex 0: Female, 1: Male
     * @param height cm
     * @param weight kg
     * @param age years
     * @param stepAim target steps
     * @param sleepAim target sleep minutes
     */
    @ReactMethod
    fun syncPersonInfo(
            sex: Int,
            height: Int,
            weight: Int,
            age: Int,
            stepAim: Int,
            sleepAim: Int,
            promise: Promise
    ) {
        deviceHelper.syncPersonInfo(sex, height, weight, age, stepAim, sleepAim, promise)
    }

    /**
     * 读取日常健康数据 (5分钟粒度)
     * @param dayOffset 0: Today, 1: Yesterday, 2: Day before yesterday
     */
    @ReactMethod
    fun readOriginData(dayOffset: Int, promise: Promise) {
        healthHelper.readOriginData(dayOffset, promise)
    }
}
