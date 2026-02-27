import Foundation
import CoreBluetooth
import React

/// Veepoo 蓝牙连接助手
///
/// 职责：
/// - 管理 iOS 系统蓝牙状态 (`CBCentralManager`)
/// - 处理 Veepoo 设备的扫描、发现与缓存
/// - 处理设备的连接与断开逻辑
/// - 维护 UUID 与 MAC 地址的映射关系（iOS 无法直接获取 MAC，需通过广播包或 UUID 推断）
class VeepooConnectionHelper: NSObject, CBCentralManagerDelegate {
    
    // MARK: - Properties
    
    /// 事件回调闭包
    /// - Parameters:
    ///   - eventName: 事件名称（如 "VeepooDeviceFound"）
    ///   - body: 事件参数字典
    var onEvent: ((String, [String: Any]?) -> Void)?
    
    /// 扫描结果的读写队列
    private let scannedQueue = DispatchQueue(label: "VeepooConnectionHelper.scannedPeripherals")
    
    #if !targetEnvironment(simulator)
    /// 扫描到的设备缓存
    private var scannedPeripherals: [String: VPPeripheralModel] = [:]
    #endif
    
    /// 当前是否正在扫描
    /// 用于防止重复调用扫描方法
    private(set) var isScanning = false
    
    /// 标记 JS 侧是否有未完成的扫描请求
    /// 当蓝牙未开启时，此标记为 true，待蓝牙开启后自动触发扫描
    private var pendingScanStart = false
    
    /// 缓存上一次发送给 JS 的蓝牙状态码
    /// 用于去重，避免发送重复的状态变更事件
    private var lastBleStateCode: Int?
    
    /// 最近一次发起连接请求的目标 MAC 地址
    /// 用于在连接回调中定位目标设备
    private var connectingMacAddress: String?
    
    /// 待处理的连接 Promise Resolve
    private var pendingConnectResolve: RCTPromiseResolveBlock?
    
    /// 待处理的连接 Promise Reject
    private var pendingConnectReject: RCTPromiseRejectBlock?
    
    /// 当前是否正在执行连接流程
    private var isConnecting = false
    
    /// 最近一次“主动断开”的 MAC 地址
    /// 用于区分“用户主动断开”与“设备意外断开”，避免主动断开时抛出异常断开事件
    private var manualDisconnectMacAddress: String?
    
    /// MAC -> UUID 映射存储 Key (UserDefaults)
    private let kVeepooMacUuidMapKey = "kVeepooMacUuidMapKey"
    
    /// 系统蓝牙中心管理器
    /// 负责监听系统蓝牙开关状态，以及找回已连接设备
    private var centralManager: CBCentralManager?
    
    /// 获取持久化的 MAC -> UUID 映射
    /// 用于通过 MAC 地址找回 UUID，进而检索 CBPeripheral
    private var macToUuidMap: [String: String] {
        get {
            return UserDefaults.standard.dictionary(forKey: kVeepooMacUuidMapKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kVeepooMacUuidMapKey)
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // 延迟初始化，确保在主线程或适当的时机调用
    }
    
    /// 初始化 SDK
    /// 配置 Veepoo SDK 的基本参数，并建立系统蓝牙监听
    func initializeSDK() {
        print("🔵 [VeepooConnectionHelper] initializeSDK")
        #if targetEnvironment(simulator)
        print("❌ [VeepooConnectionHelper] iOS 模拟器跳过 SDK 初始化")
        #else
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let manager = VPBleCentralManage.sharedBleManager() else {
                print("🔴 [VeepooConnectionHelper] VPBleCentralManage.sharedBleManager() 返回 nil")
                return
            }
            print("🟢 [VeepooConnectionHelper] VPBleCentralManage 初始化完成")
            manager.isLogEnable = true
            manager.manufacturerIDFilter = false // 关闭厂商 ID 过滤，扫描更多设备
            manager.peripheralManage = VPPeripheralManage.shareVPPeripheralManager()
            
            self.ensureCentralManager()
            self.setupVeepooCallbacks()
            self.emitBluetoothStatusIfChanged()
        }
        #endif
    }
    
    // MARK: - Scanning
    
    /// 开始扫描
    /// 如果蓝牙未开启，会记录意图，待蓝牙开启后自动扫描
    func startScan() {
        print("🔵 [VeepooConnectionHelper] startScan")
        #if targetEnvironment(simulator)
        print("❌ [VeepooConnectionHelper] iOS 模拟器不支持蓝牙，请使用真机。")
        #else
        
        pendingScanStart = true
        DispatchQueue.main.async {
            self.startScanIfPossible()
        }
        #endif
    }
    
    /// 停止扫描
    func stopScan() {
        DispatchQueue.main.async {
            self.pendingScanStart = false
            self.isScanning = false
            #if !targetEnvironment(simulator)
            guard let manager = VPBleCentralManage.sharedBleManager() else { return }
            manager.veepooSDKStopScanDevice()
            #endif
        }
    }
    
    /// 尝试执行扫描逻辑
    /// 检查权限和蓝牙状态，满足条件才调用 SDK 扫描接口
    private func startScanIfPossible() {
        #if targetEnvironment(simulator)
        return
        #else
        print("🔵 [VeepooConnectionHelper] startScanIfPossible")
        ensureCentralManager()

        let status = currentBluetoothStatusPayload()
        let stateName = status["stateName"] as? String
        let authorizationName = status["authorizationName"] as? String
        
        print("ℹ️ [VeepooConnectionHelper] 蓝牙状态: state=\(stateName ?? "nil"), auth=\(authorizationName ?? "nil")")

        guard stateName == "poweredOn" else {
            print("⚠️ [VeepooConnectionHelper] 蓝牙未开启，等待中...")
            emitBluetoothStatusIfChanged(force: true)
            return
        }
        if authorizationName == "denied" || authorizationName == "restricted" {
            print("⚠️ [VeepooConnectionHelper] 蓝牙权限被拒绝或受限。")
            emitBluetoothStatusIfChanged(force: true)
            return
        }

        // 扫描前先尝试找回已连接的设备（处理系统已连但 App 未知的情况）
        if self.retrieveConnectedPeripherals() {
            print("🟢 [VeepooConnectionHelper] 已通过 Retrieve 找到并重连设备，跳过扫描")
            return
        }

        guard pendingScanStart else {
            print("⚠️ [VeepooConnectionHelper] pendingScanStart 为 false，中止扫描。")
            return
        }
        
        if isScanning {
            print("⚠️ [VeepooConnectionHelper] 正在扫描中，跳过。")
            return
        }
        
        isScanning = true
        print("🟢 [VeepooConnectionHelper] 开始 Veepoo SDK 扫描...")

        // 优先回放缓存的设备，以便 UI 能够立即显示
        // 注意：这是为了满足“再次打开时需要立刻展示扫描结果”的需求
        var cachedItems: [VPPeripheralModel] = []
        self.scannedQueue.sync {
            // 去重：因为字典中可能同时存在 MAC 和 UUID 指向同一个 Model
            let uniqueModels = Set(self.scannedPeripherals.values)
            cachedItems = Array(uniqueModels)
        }
        
        if !cachedItems.isEmpty {
            print("📦 [VeepooConnectionHelper] 回放 \(cachedItems.count) 个缓存设备")
            for model in cachedItems {
                self.handleDiscoveredDevice(model)
            }
        }
        
        guard let manager = VPBleCentralManage.sharedBleManager() else {
            print("🔴 [VeepooConnectionHelper] startScan 期间 Manager 为 nil")
            return
        }
        
        // 调用 Veepoo SDK 扫描接口
        manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] peripheralModel in
            guard let self = self else { return }
            guard let peripheralModel = peripheralModel else {
                print("⚠️ [VeepooConnectionHelper] 发现空的 peripheral model")
                return
            }
            self.handleDiscoveredDevice(peripheralModel)
        }
        #endif
    }
    
    /// 处理发现的设备
    /// 仅发送事件，不保存任何数据
    #if !targetEnvironment(simulator)
    private func handleDiscoveredDevice(_ peripheralModel: VPPeripheralModel) {
        let rawAddr = peripheralModel.deviceAddress
        let uuid = peripheralModel.peripheral.identifier.uuidString
        let name = peripheralModel.deviceName ?? "Unknown"
        let rssi = peripheralModel.rssi ?? 0
        
        // 尝试获取 MAC 地址
        var finalMac: String? = nil
        if let raw = rawAddr, raw.contains(":") {
            finalMac = raw
        } else {
            // 尝试从持久化映射中反查 MAC (遍历 Map)
            if let entry = self.macToUuidMap.first(where: { $0.value == uuid }) {
                finalMac = entry.key
            }
        }
        
        let exportId = finalMac ?? rawAddr ?? uuid
        
        // 更新内存缓存 (用于加速后续连接)
        self.scannedQueue.async {
            // 优先使用 MAC 作为 Key，如果只有 UUID 则用 UUID
            if let mac = finalMac {
                self.scannedPeripherals[mac] = peripheralModel
            }
            // 同时也用 UUID 存一份，以防万一
            self.scannedPeripherals[uuid] = peripheralModel
        }
        
        // 1. 发送发现事件
        self.onEvent?("VeepooDeviceFound", [
            "name": name,
            "mac": exportId,
            "rssi": rssi,
            "uuid": uuid
        ])
        
        // 2. 检查是否是正在寻找的连接目标 (Scan-to-Connect)
        if let targetMac = self.connectingMacAddress,
           let currentMac = finalMac,
           targetMac.caseInsensitiveCompare(currentMac) == .orderedSame {
            
            print("🎯 [VeepooConnectionHelper] 扫描到目标设备: \(targetMac)，准备连接...")
            
            // 停止扫描 (找到目标后通常停止扫描以提高连接稳定性)
            self.stopScan()
            
            // 延迟执行连接，确保扫描已完全停止，且蓝牙协议栈准备就绪
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performConnection(peripheralModel, macAddress: targetMac)
            }
        }
    }
    #endif
    
    /// 找回系统已连接的设备
    /// 当设备已在系统蓝牙设置中连接，App 可能收不到扫描广播，需要主动 Retrieve
    /// - Returns: 是否找到并启动了连接
    private func retrieveConnectedPeripherals() -> Bool {
        #if !targetEnvironment(simulator)
        print("🔵 [VeepooConnectionHelper] retrieveConnectedPeripherals")
        guard let central = centralManager else { return false }
        
        // Veepoo 常见的 Service UUIDs
        let serviceUUIDs = [
            CBUUID(string: "FEE7"),
            CBUUID(string: "180D"), // Heart Rate
            CBUUID(string: "180F"), // Battery Service
        ]
        
        let connectedPeripherals = central.retrieveConnectedPeripherals(withServices: serviceUUIDs)
        print("ℹ️ [VeepooConnectionHelper] 找到 \(connectedPeripherals.count) 个已连接设备")
        
        var connectionInitiated = false
        
        for peripheral in connectedPeripherals {
            // 将系统 CBPeripheral 包装成 Veepoo 的 VPPeripheralModel
            if let model = VPPeripheralModel(peripher: peripheral) {
                // 不调用 handleDiscoveredDevice，因为不想触发普通的扫描发现逻辑，而是单独处理
                
                let uuid = peripheral.identifier.uuidString
                let rawAddr = model.deviceAddress
                
                // 尝试找回 MAC 地址
                var finalMac: String? = nil
                if let raw = rawAddr, raw.contains(":") {
                    finalMac = raw
                } else {
                    // 尝试从持久化映射中反查 MAC (遍历 Map)
                    // 注意：这可能效率不高，但对于少量设备是可以接受的
                    if let entry = self.macToUuidMap.first(where: { $0.value == uuid }) {
                        finalMac = entry.key
                    }
                }
                
                let exportId = finalMac ?? rawAddr ?? uuid
                
                // 发送带 isConnected=true 的特殊事件
                self.onEvent?("VeepooDeviceFound", [
                    "name": model.deviceName ?? peripheral.name ?? "Unknown",
                    "mac": exportId,
                    "rssi": model.rssi ?? 0,
                    "isConnected": true,
                    "uuid": uuid
                ])
                
                // 检查是否是正在寻找的连接目标 (Scan-to-Connect)
                // 如果设备已在系统蓝牙中连接（但 App 未知），也应在此处触发连接流程
                if let targetMac = self.connectingMacAddress,
                   let currentMac = finalMac,
                   targetMac.caseInsensitiveCompare(currentMac) == .orderedSame {
                    
                    print("🎯 [VeepooConnectionHelper] 在已连接设备中找到目标: \(targetMac)，直接连接...")
                    self.performConnection(model, macAddress: targetMac)
                    connectionInitiated = true
                }
            }
        }
        
        return connectionInitiated
        #else
        return false
        #endif
    }
    
    // MARK: - Connection
    
    /// 连接设备
    /// - Parameters:
    ///   - macAddress: 目标设备 MAC
    ///   - uuid: 目标设备 UUID（可选提示）
    func connectDevice(_ macAddress: String, uuid: String?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        
        // 防止重复连接请求
        if isConnecting {
            if self.connectingMacAddress == macAddress {
                print("⚠️ [VeepooConnectionHelper] 已在连接设备 \(macAddress) 中，忽略重复请求")
                // 这里可以选择 resolve(true) 或者保持沉默等待上一个请求完成
                // 为避免 Promise 泄漏，这里直接 resolve，认为“请求已接收”
                resolve(true)
                return
            } else {
                print("⚠️ [VeepooConnectionHelper] 正在连接其他设备，拒绝 \(macAddress) 的连接请求")
                reject("BUSY", "Already connecting to another device", nil)
                return
            }
        }
        
        // 标记开始连接
        self.isConnecting = true
        
        // 保存 Promise
        self.pendingConnectResolve = resolve
        self.pendingConnectReject = reject
        self.connectingMacAddress = macAddress
        
        #if targetEnvironment(simulator)
        print("❌ [VeepooConnectionHelper] iOS 模拟器不支持连接设备")
        reject("SIMULATOR_UNSUPPORTED", "Connection not supported on simulator", nil)
        self.isConnecting = false
        return
        #else
        
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let central = self.centralManager else {
                self.rejectConnection("BLE_MANAGER_UNAVAILABLE", "Manager unavailable")
                return
            }
            
            // 按照指示：直接使用 UUID 连接，不做任何映射缓存判断
            var directConnectionAttempted = false
            if let uuidString = uuid, let uuidObj = UUID(uuidString: uuidString) {
                print("🔗 [VeepooConnectionHelper] 尝试通过 UUID 直接连接: \(uuidString)")
                let peripherals = central.retrievePeripherals(withIdentifiers: [uuidObj])
                if let peripheral = peripherals.first {
                    print("🔗 [VeepooConnectionHelper] 成功找回设备，尝试直接连接")
                    if let model = VPPeripheralModel(peripher: peripheral) {
                        self.performConnection(model, macAddress: macAddress)
                        directConnectionAttempted = true
                        // 注意：这里不再 return，而是继续执行下面的扫描逻辑作为双重保障
                        // 因为仅靠 retrievePeripherals 有时会卡在“连接中”状态，需要扫描来激活或刷新
                    }
                } else {
                    print("⚠️ [VeepooConnectionHelper] 无法通过 UUID 找回设备 (可能系统已遗忘)")
                }
            } else {
                print("⚠️ [VeepooConnectionHelper] 未提供有效的 UUID，跳过 UUID 连接步骤")
            }
            
            // 降级逻辑：如果 UUID 无法连接，仍然需要尝试扫描 MAC (否则新设备无法连接)
            // 但不再依赖 macToUuidMap 进行判断，而是仅作为 fallback
            
            // 尝试从内存缓存中查找 (Scan-to-Connect 优化)
            // 如果已经发起了直连，就不需要再查缓存了，反正都要启动扫描做兜底
            if !directConnectionAttempted {
                var cachedModel: VPPeripheralModel? = nil
                self.scannedQueue.sync {
                    cachedModel = self.scannedPeripherals[macAddress]
                }
                
                if let model = cachedModel {
                    print("🔗 [VeepooConnectionHelper] 命中内存缓存，直接连接: \(macAddress)")
                    self.performConnection(model, macAddress: macAddress)
                    // 同样不 return，继续扫描以防缓存连接失效
                    directConnectionAttempted = true
                }
            }
            
            print("🔍 [VeepooConnectionHelper] 启动辅助扫描以确保连接: \(macAddress)")
            
            self.pendingScanStart = true
            
            if !self.isScanning {
                self.startScanIfPossible()
            } else {
                print("ℹ️ [VeepooConnectionHelper] 已在扫描中，等待发现目标设备...")
            }
        }
        #endif
    }
    
    /// 执行 SDK 连接
    #if !targetEnvironment(simulator)
    private func performConnection(_ peripheralModel: VPPeripheralModel, macAddress: String) {
        guard let manager = VPBleCentralManage.sharedBleManager() else {
            self.rejectConnection("SDK_ERROR", "VPBleCentralManage is nil")
            return
        }
        
        // 如果正在扫描，停止它
        // 注意：如果之前已经调用了 stopScan (例如在 Scan-to-Connect 流程中)，这里再次调用是安全的
        // 但如果是在异步延迟后调用，可能已经停止了
        if self.isScanning {
            self.stopScan()
        }
        
        print("🔗 [VeepooConnectionHelper] 调用 SDK 连接接口: \(macAddress)")
        
        var finished = false
        
        manager.veepooSDKConnectDevice(peripheralModel, deviceConnect: { [weak self] connectState in
            guard let self = self else { return }
            
            switch connectState.rawValue {
            case 2: // Connected
                print("✅ [VeepooConnectionHelper] 连接成功 (Callback): \(macAddress)")
                
                // 1. 连接成功后，更新持久化映射 (MAC -> UUID)
                let uuid = peripheralModel.peripheral.identifier.uuidString
                if self.macToUuidMap[macAddress] != uuid {
                    print("💾 [VeepooConnectionHelper] 更新持久化映射: \(macAddress) -> \(uuid)")
                    self.macToUuidMap[macAddress] = uuid
                }
                 print("✅ [VeepooConnectionHelper] 发送成功事件")

                // 2. 发送成功事件 (仍然在这里发送，因为它是一次性成功信号，不是状态流)
                // 延迟发送 Ready 事件，确保 SDK 内部状态完全就绪
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("✅ [VeepooConnectionHelper] 发送 DeviceReady 事件")
                    self.onEvent?("VeepooDeviceConnected", ["mac": macAddress])
                    self.onEvent?("VeepooDeviceReady", ["mac": macAddress])
                }

                 print("✅ [VeepooConnectionHelper] 发送成功事件完成")
                
                // 3. 发送版本信息
                if let pModel = manager.peripheralModel {
                    let versionPayload: [String: Any] = [
                        "hardwareVersion": pModel.deviceVersion ?? "unknown",
                        "newVersion": pModel.deviceNetVersion ?? "",
                        "description": pModel.deviceNetVersionDes ?? ""
                    ]
                    self.onEvent?("VeepooDeviceVersion", versionPayload)
                }
                
                // 4. 完成 Promise
                if !finished {
                    finished = true
                    if let resolve = self.pendingConnectResolve {
                        resolve(true)
                        self.clearPendingPromise()
                    }
                }
                
                // 连接成功，重置连接状态
                self.isConnecting = false
                
            case 0: // Powered Off
                if !finished {
                    finished = true
                    self.rejectConnection("BLE_POWERED_OFF", "Bluetooth powered off")
                }
                
            case 3: // Failed
                if !finished {
                    finished = true
                    // 如果是 Scan-to-Connect 失败，可能需要重试? 暂时直接报错
                    self.rejectConnection("BLE_CONNECT_FAILED", "Connection failed")
                }
                
            case 6: // Timeout
                if !finished {
                    finished = true
                    self.rejectConnection("BLE_CONNECT_TIMEOUT", "Connection timeout")
                }
                
            default:
                break
            }
        })
    }
    #endif
    
    private func rejectConnection(_ code: String, _ message: String) {
        if let reject = self.pendingConnectReject {
            reject(code, message, nil)
            self.clearPendingPromise()
        }
        self.connectingMacAddress = nil
        self.isConnecting = false // 重置连接状态
    }
    
    private func clearPendingPromise() {
        self.pendingConnectResolve = nil
        self.pendingConnectReject = nil
    }
    
    /// 断开设备连接
    func disconnectDevice(_ macAddress: String) {
        // 标记为主动断开
        self.manualDisconnectMacAddress = macAddress
        
        // 重置连接状态，防止死锁（例如卡在连接中时用户强制断开）
        self.isConnecting = false
        
        DispatchQueue.main.async {
            #if targetEnvironment(simulator)
            print("❌ [VeepooConnectionHelper] 模拟器断开连接 (模拟)")
            self.onEvent?("VeepooDeviceDisconnected", [
                "mac": macAddress,
                "uuid": "SIMULATOR-UUID"
            ])
            #else
            guard let manager = VPBleCentralManage.sharedBleManager() else { return }
            
            // 尝试查找 UUID 以便发送更完整的事件（可选）
            let uuid = self.macToUuidMap[macAddress] ?? ""
            
            manager.veepooSDKDisconnectDevice()
            
            // 立即发送断开事件
            self.onEvent?("VeepooDeviceDisconnected", [
                "mac": macAddress,
                "uuid": uuid
            ])
            #endif
        }
    }
    
    // MARK: - Bluetooth State & Manager Delegate
    
    /// 确保系统 CBCentralManager 已初始化
    private func ensureCentralManager() {
        if centralManager != nil { return }
        print("🔵 [VeepooConnectionHelper] 创建本地 CBCentralManager...")
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
    }
    
    /// 注册 Veepoo SDK 的全局状态回调
    private func setupVeepooCallbacks() {
        #if !targetEnvironment(simulator)
        guard let manager = VPBleCentralManage.sharedBleManager() else { return }

        // 监听系统蓝牙开关变化
        manager.vpBleCentralManageChangeBlock = { [weak self] _ in
            DispatchQueue.main.async {
                self?.emitBluetoothStatusIfChanged(force: true)
            }
        }

        // 监听设备连接状态变化（覆盖所有情况，包括意外断开）
        manager.vpBleConnectStateChangeBlock = { [weak self] state in
            guard let self = self else { return }
            
            var mac = self.currentConnectedMacAddress()
            
            // 修复: 如果获取到的 mac 是 UUID (iOS 常见情况)，尝试还原为真实 MAC
            // 优先检查 connectingMacAddress，因为如果是连接中，我们知道目标是谁
            if mac == nil || (mac?.count ?? 0) > 17 { // 简单判断 UUID 长度通常比 MAC 长
                if let connecting = self.connectingMacAddress {
                    mac = connecting
                } else if let uuidStr = mac, let entry = self.macToUuidMap.first(where: { $0.value == uuidStr }) {
                    mac = entry.key
                }
            }
            
            // 透传状态码
            self.onEvent?("VeepooDeviceConnectStatus", [
                "mac": mac ?? "",
                "code": state.rawValue,
            ])

            // 处理断开连接 (rawValue == 0)
            if state.rawValue == 0 {
                // 如果是用户主动断开的，忽略此次回调（因为 disconnectDevice 已发送过事件）
                if let mac = mac, mac == self.manualDisconnectMacAddress {
                    self.manualDisconnectMacAddress = nil
                    return
                }
                // 意外断开，发送事件
                if let mac = mac {
                    self.onEvent?("VeepooDeviceDisconnected", ["mac": mac])
                }
            }
        }
        #endif
    }
    
    /// 获取当前 SDK 已连接设备的 MAC
    private func currentConnectedMacAddress() -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard let manager = VPBleCentralManage.sharedBleManager() else { return nil }
        return manager.peripheralModel?.deviceAddress
        #endif
    }
    
    /// CBCentralManager 状态代理回调
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("ℹ️ [VeepooConnectionHelper] centralManagerDidUpdateState: \(central.state.rawValue)")
        DispatchQueue.main.async {
            self.emitBluetoothStatusIfChanged()

            if central.state != .poweredOn {
                // 蓝牙关闭时，停止扫描
                if self.isScanning {
                    self.stopScan()
                }
                return
            }

            // 蓝牙恢复开启时，如果之前有 pending 任务，自动恢复扫描
            if self.pendingScanStart {
                self.startScanIfPossible()
            }
        }
    }
    
    /// 发送蓝牙状态变更事件
    /// - Parameter force: 是否强制发送（忽略去重）
    private func emitBluetoothStatusIfChanged(force: Bool = false) {
        let payload = currentBluetoothStatusPayload()
        let stateCode = payload["state"] as? Int
        if !force, stateCode == lastBleStateCode { return }
        lastBleStateCode = stateCode

        onEvent?("VeepooBluetoothStateChanged", payload)
    }
    
    /// 构造当前蓝牙状态的数据字典
    func currentBluetoothStatusPayload() -> [String: Any] {
        // ensureCentralManager() // 移除主动初始化，避免仅仅查询状态时触发权限请求

        let stateCode: Int
        let stateName: String
        if let central = centralManager {
            switch central.state {
            case .unknown:      stateCode = 0; stateName = "unknown"
            case .resetting:    stateCode = 1; stateName = "resetting"
            case .unsupported:  stateCode = 2; stateName = "unsupported"
            case .unauthorized: stateCode = 3; stateName = "unauthorized"
            case .poweredOff:   stateCode = 4; stateName = "poweredOff"
            case .poweredOn:    stateCode = 5; stateName = "poweredOn"
            @unknown default:   stateCode = 0; stateName = "unknown"
            }
        } else {
            // 如果 manager 尚未初始化，状态视为 unknown 或根据需求定义
            stateCode = 0
            stateName = "unknown"
        }

        let authorization: Int
        let authorizationName: String
        
        // 兼容 iOS 13+ 的权限判断
        if #available(iOS 13.0, *) {
            switch CBManager.authorization {
            case .notDetermined: authorization = 0; authorizationName = "notDetermined"
            case .restricted:    authorization = 1; authorizationName = "restricted"
            case .denied:        authorization = 2; authorizationName = "denied"
            case .allowedAlways: authorization = 3; authorizationName = "allowedAlways"
            @unknown default:    authorization = 0; authorizationName = "unknown"
            }
        } else {
             switch CBPeripheralManager.authorizationStatus() {
             case .notDetermined: authorization = 0; authorizationName = "notDetermined"
             case .restricted:    authorization = 1; authorizationName = "restricted"
             case .denied:        authorization = 2; authorizationName = "denied"
             case .authorized:    authorization = 3; authorizationName = "allowedAlways"
             @unknown default:    authorization = 0; authorizationName = "unknown"
             }
        }

        return [
            "state": stateCode,
            "stateName": stateName,
            "authorization": authorization,
            "authorizationName": authorizationName,
            "isScanning": isScanning,
            "pendingScanStart": pendingScanStart,
        ]
    }
}
