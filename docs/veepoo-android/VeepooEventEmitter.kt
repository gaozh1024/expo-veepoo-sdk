package com.nutri_gene_app.veepoo

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

/** 
 * 发送事件到 React Native 的工具类
 * 封装了 DeviceEventManagerModule.RCTDeviceEventEmitter 的调用
 */
class VeepooEventEmitter(private val reactContext: ReactApplicationContext) {
    /**
     * 发送事件到 React Native 端
     * @param eventName 事件名称，需与 React Native 端监听的名称一致
     * @param params 携带的参数 (WritableMap)
     */
    fun sendEvent(eventName: String, params: WritableMap?) {
        if (reactContext.hasActiveCatalystInstance()) {
            reactContext
                    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                    .emit(eventName, params)
        }
    }
}
