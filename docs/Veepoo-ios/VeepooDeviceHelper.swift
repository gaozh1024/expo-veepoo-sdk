import Foundation
import React

/// Veepoo 设备基础操作助手
///
/// 职责：
/// - 处理设备连接后的基础指令
/// - 密码验证（连接后必须执行的第一步）
/// - 个人信息设置（影响算法准确性）
/// - 设备状态读取（电量等）
class VeepooDeviceHelper {
    
    // MARK: - Basic Operations
    
    /// 验证设备密码
    /// 连接成功后，必须先验证密码才能进行其他操作。
    /// - Parameters:
    ///   - password: 设备密码（默认为 "0000"）
    ///   - is24Hour: 是否使用 24 小时制
    func verifyPassword(_ password: String, is24Hour: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        print("❌ [VeepooDeviceHelper] 模拟器不支持密码验证，模拟成功")
        resolve(true)
        return
        #else
        print("🔐 [VeepooDeviceHelper] 开始验证密码: \(password), is24Hour: \(is24Hour)")
        
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager() else {
                print("❌ [VeepooDeviceHelper] Manager unavailable")
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            manager.is24HourFormat = is24Hour
            
            var hasResponded = false
            
            // 设置超时机制 (3秒)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if !hasResponded {
                    hasResponded = true
                    print("❌ [VeepooDeviceHelper] 验证密码超时")
                    reject("TIMEOUT", "Verify password timed out", nil)
                }
            }
            
            print("🔐 [VeepooDeviceHelper] 调用 SDK veepooSDKSynchronousPassword 接口")
            
            // 调用 SDK 验证密码接口
            // SynchronousPasswordType 0 表示常规验证
            manager.veepooSDKSynchronousPassword(with: SynchronousPasswordType(rawValue: 0)!, password: password) { result in
                print("🔐 [VeepooDeviceHelper] 收到 SDK 验证回调: \(result.rawValue)")
                
                if hasResponded { return }
                hasResponded = true
                
                // result: 1=成功, 6=成功(新设备?), 其他=失败
                let success = (result.rawValue == 1) || (result.rawValue == 6)
                if success {
                    print("✅ [VeepooDeviceHelper] 验证密码成功")
                    resolve(true)
                } else {
                    print("❌ [VeepooDeviceHelper] 验证密码失败")
                    reject("VERIFY_PASSWORD_FAILED", "Verify password failed.", nil)
                }
            }
        }
        #endif
    }
    
    /// 同步个人信息
    /// 设置用户的基本身体数据，Veepoo SDK 依据这些数据计算卡路里、步距等。
    /// - Parameters:
    ///   - sex: 性别 (0:女, 1:男)
    ///   - height: 身高 (米)
    ///   - weight: 体重 (kg)
    ///   - age: 年龄
    ///   - stepAim: 目标步数
    ///   - sleepAim: 目标睡眠时长 (分钟)
    func syncPersonInfo(_ sex: Int, height: Double, weight: Double, age: Int, stepAim: Int, sleepAim: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        print("❌ [VeepooDeviceHelper] 模拟器跳过个人信息同步")
        resolve(true)
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager() else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            let info = VPSyncPersonalInfo()
            info.sex = Int32(sex)
            info.status = Int32(height * 100) // 转换单位：米 -> 厘米 (SDK 需要 cm)
            info.weight = Int32(weight)
            info.age = Int32(age)
            info.targetStep = Int32(stepAim)
            info.targetSleepDuration = Int32(sleepAim)
            
            manager.peripheralManage.veepooSDKSynchronousPersonalInformation(info) { result in
                // result: 1=设置成功
                if result == 1 {
                    resolve(true)
                } else {
                    reject("SYNC_PERSON_INFO_FAILED", "Sync person info failed.", nil)
                }
            }
        }
        #endif
    }
    
    /// 读取设备电量
    /// 返回包含电量百分比、充电状态等信息的字典。
    func readBattery(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        print("❌ [VeepooDeviceHelper] 模拟器返回假电量")
        resolve([
            "level": 0,
            "percent": 88,
            "powerModel": 0,
            "state": 1,
            "bat": 0,
            "isPercent": true,
            "isLowBattery": false,
        ])
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            // 防止 SDK 多次回调导致 Promise 重复 Resolve
            var hasResolved = false
            
            peripheralManage.veepooSDKReadDeviceBatteryAndChargeInfo { isPercent, chargeState, percenTypeIsLowBat, battery in
                if hasResolved {
                    print("⚠️ [VeepooDeviceHelper] readBattery callback called multiple times, ignoring.")
                    return
                }
                hasResolved = true
                
                // isPercent: 是否支持百分比显示
                // chargeState: 充电状态
                // battery: 电量值 (0-100 或 0-4 等级)
                resolve([
                    "level": isPercent ? 0 : battery,
                    "percent": isPercent ? battery : 0,
                    "powerModel": 0,
                    "state": chargeState.rawValue,
                    "bat": 0,
                    "isPercent": isPercent,
                    "isLowBattery": percenTypeIsLowBat,
                ])
            }
        }
        #endif
    }
    
    /// 获取设备版本号
    /// - Returns: 包含固件版本号的字典
    func getDeviceVersion(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve([
            "hardwareVersion": "1.0.0-SIMULATOR",
            "newVersion": "",
            "description": "Simulator Mode"
        ])
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let model = manager.peripheralModel else {
                reject("NO_DEVICE_CONNECTED", "No device connected or model unavailable.", nil)
                return
            }
            
            let version = model.deviceVersion ?? "unknown"
            // 同时检查是否有新版本（如果有网络升级版本信息）
            let newVersion = model.deviceNetVersion ?? ""
            let des = model.deviceNetVersionDes ?? ""
            
            resolve([
                "hardwareVersion": version, // 显示版本
                "newVersion": newVersion,   // 可升级的新版本
                "description": des          // 升级描述
            ])
        }
        #endif
    }
    
    /// 读取自动测量设置
    func readAutoMeasureSetting(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve([])
        return
        #else
        DispatchQueue.main.async(execute: {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }

            peripheralManage.veepooSDKReadAutoMonitSwitchInfo { settingList in
                 guard let list = settingList as? [VPAutoMonitTestModel] else {
                     reject("READ_FAILED", "Failed to read auto measure settings", nil)
                     return
                 }
                 
                 let result = list.map { model -> [String: Any] in
                     return [
                        "protocolType": 1, // Default protocol type
                        "funType": model.type.rawValue,
                        "isSwitchOpen": model.on,
                        "stepUnit": Int(model.minStepValue),
                        "isSlotModify": model.supportRangeTime,
                        "isIntervalModify": true, // Assuming true as it's not explicitly in model
                        "supportStartMinute": Int(model.startHourRef) * 60 + Int(model.startMinuteRef),
                        "supportEndMinute": Int(model.endHourRef) * 60 + Int(model.endMinuteRef),
                        "measureInterval": Int(model.timeInterval),
                        "currentStartMinute": Int(model.startHour) * 60 + Int(model.startMinute),
                        "currentEndMinute": Int(model.endHour) * 60 + Int(model.endMinute)
                     ]
                 }
                 resolve(result)
            }
        })
        #endif
    }

    /// 修改自动测量设置
    func modifyAutoMeasureSetting(_ setting: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve([])
        return
        #else
        DispatchQueue.main.async(execute: {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            // First read the current settings to get the correct model instance
            peripheralManage.veepooSDKReadAutoMonitSwitchInfo { settingList in
                guard let list = settingList as? [VPAutoMonitTestModel] else {
                    reject("READ_FAILED", "Failed to read settings before modifying", nil)
                    return
                }
                
                guard let funTypeInt = setting["funType"] as? Int,
                      let targetType = VPAutoMonitTestType(rawValue: UInt(funTypeInt)),
                      let model = list.first(where: { $0.type == targetType }) else {
                    reject("INVALID_TYPE", "Function type not found or invalid", nil)
                    return
                }
                
                // Update model properties
                if let isOpen = setting["isSwitchOpen"] as? Bool {
                    model.on = isOpen
                }
                if let measureInterval = setting["measureInterval"] as? Int {
                    model.timeInterval = UInt16(measureInterval)
                }
                if let currentStartMinute = setting["currentStartMinute"] as? Int {
                    model.startHour = UInt8(currentStartMinute / 60)
                    model.startMinute = UInt8(currentStartMinute % 60)
                }
                if let currentEndMinute = setting["currentEndMinute"] as? Int {
                    model.endHour = UInt8(currentEndMinute / 60)
                    model.endMinute = UInt8(currentEndMinute % 60)
                }
                
                // Write back the modified model
                peripheralManage.veepooSDKSetAutoMonitSwitch(with: model) { (success, resultModel) in
                     guard success else {
                         reject("MODIFY_FAILED", "Device returned failure", nil)
                         return
                     }
                     
                     var finalList = list
                     if let updatedModel = resultModel,
                        let index = finalList.firstIndex(where: { $0.type == updatedModel.type }) {
                         finalList[index] = updatedModel
                     }
                     
                     let result = finalList.map { m -> [String: Any] in
                         return [
                            "protocolType": 1,
                            "funType": m.type.rawValue,
                            "isSwitchOpen": m.on,
                            "stepUnit": Int(m.minStepValue),
                            "isSlotModify": m.supportRangeTime,
                            "isIntervalModify": true,
                            "supportStartMinute": Int(m.startHourRef) * 60 + Int(m.startMinuteRef),
                            "supportEndMinute": Int(m.endHourRef) * 60 + Int(m.endMinuteRef),
                            "measureInterval": Int(m.timeInterval),
                            "currentStartMinute": Int(m.startHour) * 60 + Int(m.startMinute),
                            "currentEndMinute": Int(m.endHour) * 60 + Int(m.endMinute)
                         ]
                     }
                     resolve(result)
                }
            }
        })
        #endif
    }
}
