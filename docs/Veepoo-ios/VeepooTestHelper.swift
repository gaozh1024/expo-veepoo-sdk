import Foundation
import React

/// Veepoo 手动测试助手
///
/// 职责：
/// - 处理设备的手动测量功能（心率、血氧、血压等）
/// - 监听测量过程中的实时数据回调
class VeepooTestHelper {
    
    // MARK: - Properties
    
    /// 事件回调闭包
    /// - Parameters:
    ///   - eventName: 事件名称（如 "VeepooHeartRateData"）
    ///   - body: 事件参数字典
    var onEvent: ((String, [String: Any]?) -> Void)?
    
    // MARK: - Heart Rate Test
    
    /// 开启/关闭心率手动测试
    /// - Parameters:
    ///   - enable: true 开启，false 关闭
    func testHeartRate(_ enable: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve(true)
        // 模拟发送一些测试数据
        if enable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.onEvent?("VeepooHeartRateData", ["status": "testing", "rate": 75, "isEnd": false])
            }
        }
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            // 调用 SDK 接口
            peripheralManage.veepooSDKTestHeartStart(enable) { [weak self] state, heartValue in
                // 处理回调
                self?.handleHeartRateTestResult(state: state, value: heartValue)
            }
            
            // 立即返回成功，因为这是一个持续的过程，结果通过事件发送
            resolve(true)
        }
        #endif
    }
    
    #if !targetEnvironment(simulator)
    /// 处理心率测试回调
    private func handleHeartRateTestResult(state: VPTestHeartState, value: UInt) {
        var statusStr = "unknown"
        var isEnd = false
        
        switch state {
        case .start:
            statusStr = "start"
        case .testing:
            statusStr = "testing"
        case .notWear:
            statusStr = "notWear"
            isEnd = true
        case .deviceBusy:
            statusStr = "deviceBusy"
            isEnd = true
        case .over:
            statusStr = "over"
            isEnd = true
        @unknown default:
            statusStr = "unknown"
        }
        
        let body: [String: Any] = [
            "status": statusStr,
            "rate": value,
            "isEnd": isEnd
        ]
        
        // 发送事件到 RN
        onEvent?("VeepooHeartRateData", body)
    }
    #endif

    // MARK: - Blood Pressure Test
    
    /// 开启/关闭血压手动测试
    /// - Parameters:
    ///   - enable: true 开启，false 关闭
    func testBloodPressure(_ enable: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve(true)
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            // 0 代表通用模式
            peripheralManage.veepooSDKTestBloodStart(enable, testMode: 0) { [weak self] state, progress, high, low in
                self?.handleBloodPressureTestResult(state: state, progress: progress, high: high, low: low)
            }
            
            resolve(true)
        }
        #endif
    }
    
    #if !targetEnvironment(simulator)
    /// 处理血压测试回调
    private func handleBloodPressureTestResult(state: VPTestBloodState, progress: UInt, high: UInt, low: UInt) {
        var statusStr = "unknown"
        var isEnd = false
        
        switch state {
        case .testing:
            statusStr = "testing"
        case .deviceBusy:
            statusStr = "deviceBusy"
            isEnd = true
        case .testFail:
            statusStr = "testFail"
            isEnd = true
        case .testInterrupt:
            statusStr = "testInterrupt"
            isEnd = true
        case .complete:
            statusStr = "complete"
            isEnd = true
        case .noFunction:
            statusStr = "noFunction"
            isEnd = true
        @unknown default:
            statusStr = "unknown"
        }
        
        let body: [String: Any] = [
            "status": statusStr,
            "progress": progress,
            "high": high,
            "low": low,
            "isEnd": isEnd
        ]
        
        onEvent?("VeepooBloodPressureData", body)
    }
    #endif
    
    // MARK: - Blood Oxygen Test
    
    /// 开启/关闭血氧手动测试
    /// - Parameters:
    ///   - enable: true 开启，false 关闭
    func testOxygen(_ enable: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve(true)
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            peripheralManage.veepooSDKTestOxygenStart(enable) { [weak self] state, value in
                self?.handleOxygenTestResult(state: state, value: value)
            }
            
            resolve(true)
        }
        #endif
    }
    
    #if !targetEnvironment(simulator)
    /// 处理血氧测试回调
    private func handleOxygenTestResult(state: VPTestOxygenState, value: UInt) {
        var statusStr = "unknown"
        var isEnd = false
        
        switch state {
        case .start:
            statusStr = "start"
        case .testing:
            statusStr = "testing"
        case .notWear:
            statusStr = "notWear"
            isEnd = true
        case .deviceBusy:
            statusStr = "deviceBusy"
            isEnd = true
        case .over:
            statusStr = "over"
            isEnd = true
        case .noFunction:
            statusStr = "noFunction"
            isEnd = true
        case .calibration:
            statusStr = "calibration"
        case .calibrationComplete:
            statusStr = "calibrationComplete"
        case .invalid:
            statusStr = "invalid"
            isEnd = true
        @unknown default:
            statusStr = "unknown"
        }
        
        let body: [String: Any] = [
            "status": statusStr,
            "value": value,
            "isEnd": isEnd
        ]
        
        onEvent?("VeepooOxygenData", body)
    }
    #endif
    
    // MARK: - Blood Glucose Test
    
    /// 开启/关闭血糖手动测试
    /// - Parameters:
    ///   - enable: true 开启，false 关闭
    func testBloodGlucose(_ enable: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve(true)
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }
            
            // isPersonalModel: false (默认)
            peripheralManage.veepooSDKTestBloodGlucoseStart(enable, isPersonalModel: false) { [weak self] state, progress, value, level in
                self?.handleBloodGlucoseTestResult(state: state, progress: progress, value: value, level: level)
            }
            
            resolve(true)
        }
        #endif
    }
    
    #if !targetEnvironment(simulator)
    /// 处理血糖测试回调
    private func handleBloodGlucoseTestResult(state: VPDeviceBloodGlucoseTestState, progress: UInt, value: UInt, level: UInt) {
        var statusStr = "unknown"
        var isEnd = false
        
        switch state {
        case .unsupported:
            statusStr = "unsupported"
            isEnd = true
        case .open:
            statusStr = "testing" // 使用 testing 统一语义，或者 open
        case .close:
            statusStr = "over" // 使用 over 统一语义
            isEnd = true
        case .lowPower:
            statusStr = "lowPower"
            isEnd = true
        case .deviceBusy:
            statusStr = "deviceBusy"
            isEnd = true
        case .notWear:
            statusStr = "notWear"
            isEnd = true
        @unknown default:
            statusStr = "unknown"
        }
        
        // 血糖值需要除以 100
        let finalValue = Double(value) / 100.0
        
        let body: [String: Any] = [
            "status": statusStr,
            "progress": progress,
            "value": finalValue,
            "level": level,
            "isEnd": isEnd
        ]
        
        onEvent?("VeepooBloodGlucoseData", body)
    }
    #endif

    // MARK: - Stress Test

    /// 开启/关闭压力手动测试
    /// - Parameters:
    ///   - enable: true 开启，false 关闭
    func testStress(_ enable: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve(true)
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let peripheralManage = manager.peripheralManage else {
                reject("BLE_MANAGER_UNAVAILABLE", "Veepoo BLE manager is unavailable.", nil)
                return
            }

            // 检查设备是否支持压力功能
            // 注意：SDK 文档提到 stressType > 1 表示支持 (0和1不支持)
            // 但也有文档说 stressType > 0，保险起见先尝试调用，或者 check stressType
            if let model = manager.peripheralModel, model.stressType <= 1 {
                 print("⚠️ [VeepooTestHelper] 设备似乎不支持压力测试 (stressType=\(model.stressType))")
                 // 可以选择 reject，也可以尝试调用看 SDK 反应
            }

            peripheralManage.veepooSDK_stressTestStart(enable) { [weak self] state, progress, stress in
                self?.handleStressTestResult(state: state, progress: progress, stress: stress)
            }

            resolve(true)
        }
        #endif
    }

    #if !targetEnvironment(simulator)
    /// 处理压力测试回调
    private func handleStressTestResult(state: VPDeviceStressTestState, progress: Int, stress: Int) {
        var statusStr = "unknown"
        var isEnd = false

        switch state {
        case .noFunction:
            statusStr = "unsupported"
            isEnd = true
        case .deviceBusy:
            statusStr = "deviceBusy"
            isEnd = true
        case .over:
            statusStr = "over"
            isEnd = true
        case .lowPower:
            statusStr = "lowPower"
            isEnd = true
        case .notWear:
            statusStr = "notWear"
            isEnd = true
        case .complete:
            statusStr = "complete"
            isEnd = true
        @unknown default:
            statusStr = "testing"
            isEnd = false
        }

        let body: [String: Any] = [
            "status": statusStr,
            "progress": progress,
            "value": stress,
            "isEnd": isEnd
        ]

        onEvent?("VeepooStressData", body)
    }
    #endif
}
