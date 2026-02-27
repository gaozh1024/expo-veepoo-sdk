package com.nutri_gene_app.veepoo

import com.facebook.react.bridge.*
import com.inuker.bluetooth.library.Code
import com.inuker.bluetooth.library.model.BleGattProfile
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.model.datas.*
import com.veepoo.protocol.model.enums.EFunctionStatus
import com.veepoo.protocol.model.enums.EPwdStatus
import com.veepoo.protocol.model.settings.CustomSettingData
import com.veepoo.protocol.util.VPLogger

/** 连接助手类 */
class VeepooConnectionHelper(
        private val reactContext: ReactApplicationContext,
        private val eventEmitter: VeepooEventEmitter
) {
    private val functionStatusCache = mutableMapOf<String, String>()

    /** 初始化 SDK */
    fun initSDK() {
        try {
            VPOperateManager.getInstance().init(reactContext.applicationContext)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /** 连接设备 */
    fun connectDevice(macAddress: String, promise: Promise) {
        val manager = VPOperateManager.getInstance()
        var isPromiseResolved = false

        UiThreadUtil.runOnUiThread {
            try {
                manager.connectDevice(
                        macAddress,
                        object : IConnectResponse {
                            override fun connectState(
                                    code: Int,
                                    profile: BleGattProfile?,
                                    isOadModel: Boolean
                            ) {
                                val statusMap = Arguments.createMap()
                                statusMap.putInt("code", code)
                                statusMap.putString("mac", macAddress)
                                eventEmitter.sendEvent("VeepooDeviceConnectStatus", statusMap)

                                if (code == Code.REQUEST_SUCCESS) {
                                    val map = Arguments.createMap()
                                    map.putString("status", "connected")
                                    map.putString("mac", macAddress)
                                    map.putBoolean("isOadModel", isOadModel)
                                    eventEmitter.sendEvent("VeepooDeviceConnected", map)

                                    if (!isPromiseResolved) {
                                        promise.resolve(true)
                                        isPromiseResolved = true
                                    }
                                } else {
                                    val map = Arguments.createMap()
                                    map.putString("status", "disconnected")
                                    map.putInt("code", code)
                                    eventEmitter.sendEvent("VeepooDeviceDisconnected", map)
                                }
                            }
                        },
                        object : INotifyResponse {
                            override fun notifyState(state: Int) {
                                if (state == Code.REQUEST_SUCCESS) {
                                    val map = Arguments.createMap()
                                    map.putString("status", "ready")
                                    map.putString("mac", macAddress)
                                    eventEmitter.sendEvent("VeepooDeviceReady", map)
                                }
                            }
                        }
                )
            } catch (e: Exception) {
                if (!isPromiseResolved) {
                    promise.reject("CONNECT_ERROR", e.message)
                    isPromiseResolved = true
                }
            }
        }
    }

    /** 断开设备连接 */
    fun disconnectDevice(macAddress: String) {
        VPOperateManager.getInstance()
                .disconnectWatch(
                        object : IBleWriteResponse {
                            override fun onResponse(code: Int) {
                                if (code == Code.REQUEST_SUCCESS) {
                                    val map = Arguments.createMap()
                                    map.putString("status", "disconnected_success")
                                    map.putString("mac", macAddress)
                                    eventEmitter.sendEvent("VeepooDeviceDisconnected", map)
                                }
                            }
                        }
                )
    }

    /** 验证密码 */
    fun verifyPassword(password: String, is24HourModel: Boolean, promise: Promise) {
        val manager = VPOperateManager.getInstance()

        manager.confirmDevicePwd(
                object : IBleWriteResponse {
                    override fun onResponse(code: Int) {}
                },
                object : IPwdDataListener {
                    override fun onPwdDataChange(pwdData: PwdData?) {
                        val status = pwdData?.getmStatus()
                        if (status == EPwdStatus.CHECK_SUCCESS ||
                                        status == EPwdStatus.CHECK_AND_TIME_SUCCESS
                        ) {
                            val map = Arguments.createMap()
                            map.putBoolean("success", true)
                            map.putString("deviceVersion", pwdData?.deviceVersion)
                            map.putString("deviceNumber", pwdData?.deviceNumber.toString())
                            eventEmitter.sendEvent("VeepooDeviceVersion", map)
                            promise.resolve(true)
                        } else {
                            promise.reject("AUTH_FAILED", "Password verification failed: " + status)
                        }
                    }
                },
                object : IDeviceFuctionDataListener {
                    // Helper function to map all fields using reflection and cache them
                    private fun mapObjectToWritableMap(data: Any): WritableMap {
                        val map = Arguments.createMap()
                        try {
                            val fields = data.javaClass.declaredFields
                            for (field in fields) {
                                field.isAccessible = true
                                val name = field.name
                                val value = field.get(data)?.toString() ?: ""
                                map.putString(name, value)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        return map
                    }

                    override fun onFunctionSupportDataChange(data: FunctionDeviceSupportData?) {
                        if (data != null) {
                            val map = mapObjectToWritableMap(data)
                            // Fallback to manual mapping if reflection failed (empty map)
                            if (!map.keySetIterator().hasNextKey()) {
                                try {
                                    map.putString("heart", data.heartDetect.toString())
                                    map.putString("bp", data.bp.toString())
                                    map.putString("spo2", data.spo2H.toString())
                                    map.putString("temp", data.temperatureFunction.toString())
                                    map.putString("ecg", data.ecg.toString())
                                    map.putString("sleep", data.precisionSleep.toString())
                                    map.putString("weather", data.weatherFunction.toString())
                                    map.putString("breath", data.beathFunction.toString())
                                    map.putString("female", data.women.toString())
                                    map.putString("screenStyle", data.screenStyleFunction.toString())
                                    map.putString("stress", data.stress.toString())
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }
                            eventEmitter.sendEvent("VeepooDeviceFunction", map)
                        }
                    }

                    override fun onDeviceFunctionPackage1Report(data: DeviceFunctionPackage1?) {
                        if (data != null) {
                            eventEmitter.sendEvent("VeepooDeviceFunction", mapObjectToWritableMap(data))
                        }
                    }

                    override fun onDeviceFunctionPackage2Report(data: DeviceFunctionPackage2?) {
                        if (data != null) {
                            eventEmitter.sendEvent("VeepooDeviceFunction", mapObjectToWritableMap(data))
                        }
                    }

                    override fun onDeviceFunctionPackage3Report(data: DeviceFunctionPackage3?) {
                        if (data != null) {
                            eventEmitter.sendEvent("VeepooDeviceFunction", mapObjectToWritableMap(data))
                        }
                    }

                    override fun onDeviceFunctionPackage4Report(data: DeviceFunctionPackage4?) {
                        if (data != null) {
                            eventEmitter.sendEvent("VeepooDeviceFunction", mapObjectToWritableMap(data))
                        }
                    }

                    override fun onDeviceFunctionPackage5Report(data: DeviceFunctionPackage5?) {
                        if (data != null) {
                            eventEmitter.sendEvent("VeepooDeviceFunction", mapObjectToWritableMap(data))
                        }
                    }
                },
                object : ISocialMsgDataListener {
                    override fun onSocialMsgSupportDataChange(data: FunctionSocailMsgData?) {}
                    override fun onSocialMsgSupportDataChange2(data: FunctionSocailMsgData?) {}
                },
                object : ICustomSettingDataListener {
                    override fun OnSettingDataChange(data: CustomSettingData?) {
                        if (data != null) {
                            val map = VeepooDataUtils.customSettingToMap(data)
                            eventEmitter.sendEvent("VeepooCustomSettingData", map)
                        }
                    }
                },
                password,
                is24HourModel
        )
    }

    /** 开始扫描设备 */
    fun startScan() {
        VPOperateManager.getInstance()
                .startScanDevice(
                        object : SearchResponse {
                            override fun onSearchStarted() {}
                            override fun onDeviceFounded(result: SearchResult?) {
                                if (result != null) {
                                    val map = Arguments.createMap()
                                    map.putString("mac", result.address)
                                    map.putString("name", result.name)
                                    map.putInt("rssi", result.rssi)
                                    eventEmitter.sendEvent("VeepooDeviceFound", map)
                                }
                            }
                            override fun onSearchStopped() {}
                            override fun onSearchCanceled() {}
                        }
                )
    }

    /** 停止扫描设备 */
    fun stopScan() {
        VPOperateManager.getInstance().stopScanDevice()
    }
}
