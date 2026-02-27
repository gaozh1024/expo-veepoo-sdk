package com.nutri_gene_app.veepoo

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.inuker.bluetooth.library.Code
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.IAutoMeasureSettingDataListener
import com.veepoo.protocol.listener.data.IBatteryDataListener
import com.veepoo.protocol.listener.data.IPersonInfoDataListener
import com.veepoo.protocol.model.datas.AutoMeasureData
import com.veepoo.protocol.model.datas.BatteryData
import com.veepoo.protocol.model.datas.PersonInfoData
import com.veepoo.protocol.model.enums.EOprateStauts
import com.veepoo.protocol.model.enums.ESex
import com.veepoo.protocol.shareprence.VpSpGetUtil

/**
 * 设备操作帮助类 负责处理设备信息的读取和设置，包括：
 * - 电池电量读取
 * - 个人信息同步 (性别、身高、体重等)
 * - 自定义设置的读取和修改 (CustomSetting)
 * - 自动测量设置的读取和修改 (AutoMeasureSetting)
 */
class VeepooDeviceHelper(
        private val context: ReactApplicationContext,
        private val eventEmitter: VeepooEventEmitter
) {
    /**
     * 读取设备电量
     * @param promise Promise 回调，返回包含电量等级和百分比的 Map
     */
    fun readBattery(promise: Promise) {
        VPOperateManager.getInstance()
                .readBattery(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {}
                        },
                        object : IBatteryDataListener {
                            override fun onDataChange(batteryData: BatteryData?) {
                                if (batteryData != null) {
                                    val map = Arguments.createMap()
                                    // Veepoo SDK BatteryData
                                    map.putInt("level", batteryData.batteryLevel)
                                    map.putInt("percent", batteryData.batteryPercent)
                                    map.putInt("powerModel", batteryData.powerModel)
                                    map.putInt("state", batteryData.state)
                                    // bat is byte, convert to int
                                    map.putInt("bat", batteryData.bat.toInt())
                                    map.putBoolean("isLowBattery", batteryData.isLowBattery)
                                    map.putBoolean("isPercent", batteryData.isPercent)
                                    promise.resolve(map)
                                } else {
                                    promise.reject("READ_FAILED", "Battery data is null")
                                }
                            }
                        }
                )
    }

    /**
     * 同步个人信息到设备
     * @param sex 性别 (0: 女, 1: 男)
     * @param height 身高 (cm)
     * @param weight 体重 (kg)
     * @param age 年龄 (岁)
     * @param stepAim 目标步数
     * @param sleepAim 目标睡眠 (分钟)
     * @param promise Promise 回调
     */
    fun syncPersonInfo(
            sex: Int,
            height: Int,
            weight: Int,
            age: Int,
            stepAim: Int,
            sleepAim: Int,
            promise: Promise
    ) {
        val eSex = if (sex == 1) ESex.MAN else ESex.WOMEN
        val personInfo = PersonInfoData(eSex, height, weight, age, stepAim, sleepAim)

        VPOperateManager.getInstance()
                .syncPersonInfo(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code != Code.REQUEST_SUCCESS) {
                                    promise.reject("CMD_FAILED", "Sync person info failed: $code")
                                }
                            }
                        },
                        object : IPersonInfoDataListener {
                            override fun OnPersoninfoDataChange(status: EOprateStauts?) {
                                if (status == EOprateStauts.OPRATE_SUCCESS) {
                                    promise.resolve(true)
                                } else {
                                    promise.reject("SYNC_FAILED", "Sync failed: $status")
                                }
                            }
                        },
                        personInfo
                )
    }

    /**
     * 读取自动测量设置
     * @param promise Promise 回调，返回设置列表
     */
    fun readAutoMeasureSetting(promise: Promise) {
        if (!VpSpGetUtil.getVpSpVariInstance(context).isSupportAutoMeasure) {
            promise.reject("UNSUPPORTED", "Device does not support auto measure setting")
            return
        }

        VPOperateManager.getInstance()
                .readAutoMeasureSettingData(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code != Code.REQUEST_SUCCESS) {
                                    promise.reject(
                                            "CMD_FAILED",
                                            "Read auto measure setting failed: $code"
                                    )
                                }
                            }
                        },
                        object : IAutoMeasureSettingDataListener {
                            override fun onSettingDataChange(
                                    autoMeasureDataList: List<AutoMeasureData>?
                            ) {
                                if (autoMeasureDataList != null) {
                                    val array = Arguments.createArray()
                                    for (data in autoMeasureDataList) {
                                        array.pushMap(VeepooDataUtils.autoMeasureDataToMap(data))
                                    }
                                    promise.resolve(array)
                                } else {
                                    promise.reject("READ_FAILED", "Auto measure data list is null")
                                }
                            }

                            override fun onSettingDataChangeFail() {
                                promise.reject(
                                        "READ_FAILED",
                                        "Read auto measure setting failed callback"
                                )
                            }

                            override fun onSettingDataChangeSuccess() {
                                // usually ignored for read? or maybe called after
                                // onSettingDataChange
                            }
                        }
                )
    }

    /**
     * 修改自动测量设置
     * @param settingReadableMap 设置项
     * @param promise Promise 回调
     */
    fun modifyAutoMeasureSetting(settingReadableMap: ReadableMap, promise: Promise) {
        if (!VpSpGetUtil.getVpSpVariInstance(context).isSupportAutoMeasure) {
            promise.reject("UNSUPPORTED", "Device does not support auto measure setting")
            return
        }

        val autoMeasureData = VeepooDataUtils.mapToAutoMeasureData(settingReadableMap)

        VPOperateManager.getInstance()
                .setAutoMeasureSettingData(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code != Code.REQUEST_SUCCESS) {
                                    promise.reject(
                                            "CMD_FAILED",
                                            "Set auto measure setting failed: $code"
                                    )
                                }
                            }
                        },
                        autoMeasureData,
                        object : IAutoMeasureSettingDataListener {
                            override fun onSettingDataChange(
                                    autoMeasureDataList: List<AutoMeasureData>?
                            ) {
                                if (autoMeasureDataList != null) {
                                    val array = Arguments.createArray()
                                    for (data in autoMeasureDataList) {
                                        array.pushMap(VeepooDataUtils.autoMeasureDataToMap(data))
                                    }
                                    promise.resolve(array)
                                } else {
                                    // Sometimes setting doesn't return list immediately or null?
                                    // But interface says it returns list.
                                    promise.resolve(Arguments.createArray())
                                }
                            }

                            override fun onSettingDataChangeFail() {
                                promise.reject(
                                        "SET_FAILED",
                                        "Set auto measure setting failed callback"
                                )
                            }

                            override fun onSettingDataChangeSuccess() {
                                // Success callback
                            }
                        }
                )
    }
}
