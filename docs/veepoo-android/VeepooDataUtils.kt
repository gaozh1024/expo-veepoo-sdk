package com.nutri_gene_app.veepoo

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.veepoo.protocol.model.datas.AutoMeasureData
import com.veepoo.protocol.model.enums.EAutoMeasureType
import com.veepoo.protocol.model.settings.CustomSettingData

/** 数据转换工具类，用于将 SDK 的数据对象转换为 React Native 可用的 WritableMap 封装了数据转换的逻辑，确保数据在 React Native 端的正确展示 */
object VeepooDataUtils {
    /**
     * 将 AutoMeasureData 转换为 WritableMap
     * @param data Veepoo SDK 返回的自动测量数据对象
     * @return 包含所有设置项的 WritableMap
     */
    fun autoMeasureDataToMap(data: AutoMeasureData): WritableMap {
        val map = Arguments.createMap()
        map.putInt("protocolType", data.protocolType)
        map.putInt("funType", data.funType.value)
        map.putBoolean("isSwitchOpen", data.isSwitchOpen)
        map.putInt("stepUnit", data.stepUnit)
        map.putBoolean("isSlotModify", data.isSlotModify)
        map.putBoolean("isIntervalModify", data.isIntervalModify)
        map.putInt("supportStartMinute", data.supportStartMinute)
        map.putInt("supportEndMinute", data.supportEndMinute)
        map.putInt("measureInterval", data.measureInterval)
        map.putInt("currentStartMinute", data.currentStartMinute)
        map.putInt("currentEndMinute", data.currentEndMinute)
        return map
    }

    /**
     * 将 ReadableMap 转换为 AutoMeasureData
     * @param map React Native 传递的参数
     * @return AutoMeasureData 对象
     */
    fun mapToAutoMeasureData(map: ReadableMap): AutoMeasureData {
        val data = AutoMeasureData()
        if (map.hasKey("protocolType")) data.protocolType = map.getInt("protocolType")
        if (map.hasKey("funType")) {
             EAutoMeasureType.fromValue(map.getInt("funType"))?.let {
                 data.funType = it
             }
        }
        if (map.hasKey("isSwitchOpen")) data.isSwitchOpen = map.getBoolean("isSwitchOpen")
        if (map.hasKey("stepUnit")) data.stepUnit = map.getInt("stepUnit")
        if (map.hasKey("isSlotModify")) data.isSlotModify = map.getBoolean("isSlotModify")
        if (map.hasKey("isIntervalModify")) data.isIntervalModify = map.getBoolean("isIntervalModify")
        if (map.hasKey("supportStartMinute")) data.supportStartMinute = map.getInt("supportStartMinute")
        if (map.hasKey("supportEndMinute")) data.supportEndMinute = map.getInt("supportEndMinute")
        if (map.hasKey("measureInterval")) data.measureInterval = map.getInt("measureInterval")
        if (map.hasKey("currentStartMinute")) data.currentStartMinute = map.getInt("currentStartMinute")
        if (map.hasKey("currentEndMinute")) data.currentEndMinute = map.getInt("currentEndMinute")
        return data
    }

    /**
     * 将 CustomSettingData 转换为 WritableMap
     * @param data Veepoo SDK 返回的自定义设置数据对象
     * @return 包含所有设置项的 WritableMap，可直接发送给 React Native
     */
    fun customSettingToMap(data: CustomSettingData): WritableMap {
        val map = Arguments.createMap()
        // 1. 公制/英制 (EFunctionStatus) - 对应 React Native 端的 isMetric
        map.putString("metricSystem", data.metricSystem.toString())
        // 2. 24小时制 (Boolean) - 对应 React Native 端的 is24Hour
        map.putBoolean("is24Hour", data.is24Hour)
        // 3. 自动心率检测开关 (EFunctionStatus) - 对应 React Native 端的 autoHeart
        map.putString("autoHeartDetect", data.autoHeartDetect.toString())
        // 4. 自动血压检测开关 (EFunctionStatus) - 对应 React Native 端的 autoBP
        map.putString("autoBpDetect", data.autoBpDetect.toString())

        // 以下为 EFunctionStatus 类型，返回字符串状态 (SUPPORT, UNSUPPORT, SUPPORT_OPEN, SUPPORT_CLOSE)
        // 运动过量提醒
        map.putString("sportOverRemain", data.sportOverRemain.toString())
        // 血压/心率播报
        map.putString("voiceBpHeart", data.voiceBpHeart.toString())
        // 查找手机UI
        map.putString("findPhoneUi", data.findPhoneUi.toString())
        // 秒表功能
        map.putString("secondsWatch", data.secondsWatch.toString())
        // 低血氧报警提醒
        map.putString("lowSpo2hRemain", data.lowSpo2hRemain.toString())
        // 肤色功能
        map.putString("skin", data.skin.toString())
        // 自动体温检测
        map.putString("autoTemperatureDetect", data.autoTemperatureDetect.toString())
        // 断连提醒
        map.putString("disconnectRemind", data.disconnectRemind.toString())
        // SOS 求救功能
        map.putString("sos", data.getSOS().toString())
        // 自动 HRV 检测
        map.putString("autoHrv", data.autoHrv.toString())
        // 自动接听来电
        map.putString("autoIncall", data.autoIncall.toString())
        // PPG 功能
        map.putString("ppg", data.ppg.toString())
        // 音乐控制
        map.putString("musicControl", data.musicControl.toString())
        // 长按锁屏功能
        map.putString("longClickLockScreen", data.longClickLockScreen.toString())
        // 消息亮屏功能
        map.putString("messageScreenLight", data.messageScreenLight.toString())
        // ECG 常开功能
        map.putString("ecgAlwaysOpen", data.ecgAlwaysOpen.toString())
        // 血糖检测功能
        map.putString("bloodGlucoseDetection", data.bloodGlucoseDetection.toString())
        // 梅托检测功能
        map.putString("metDetect", data.getMETDetect().toString())
        // 压力检测功能
        map.putString("stressDetect", data.stressDetect.toString())
        // 血液成分检测功能
        map.putString("bloodComponentDetect", data.bloodComponentDetect.toString())
        // 跌倒检测功能
        map.putString("fallDetection", data.fallDetection.toString())

        // 其他非 EFunctionStatus 字段
        // 肤色等级 (Int)
        map.putInt("skinLevel", data.skinLevel)
        // 温度单位
        map.putString("temperatureUnit", data.temperatureUnit.toString())
        // 血糖单位
        map.putString("bloodGlucoseUnit", data.bloodGlucoseUnit.toString())
        // 尿酸单位
        map.putString("uricAcidUnit", data.uricAcidUnit.toString())
        // 血脂单位
        map.putString("bloodFatUnit", data.bloodFatUnit.toString())
        // 是否有公制系统
        map.putBoolean("isHaveMetricSystem", data.isHaveMetricSystem())
        // 是否为公制系统
        map.putBoolean("metricSystemValue", data.isMetricSystemValue())
        // 是否开启自动心率检测
        map.putBoolean("isOpenAutoHeartDetect", data.isOpenAutoHeartDetect())
        // 是否开启自动血压检测
        map.putBoolean("isOpenAutoBpDetect", data.isOpenAutoBpDetect())
        // 索引
        map.putInt("index", data.index)

        return map
    }
}
