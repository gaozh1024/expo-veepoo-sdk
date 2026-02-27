import Foundation
import React
import CoreBluetooth

/// Veepoo 蓝牙原生模块（iOS）
///
/// 作用：
/// - 作为 React Native 的桥接层，向 JS 暴露 Veepoo SDK 能力
/// - 不再包含具体业务逻辑，而是通过 Helper 类分发处理，以保持代码整洁
///
/// 架构设计：
/// - `VeepooBleModule`: 入口，负责 RN 桥接与事件分发
/// - `VeepooConnectionHelper`: 负责扫描、连接、蓝牙状态监听
/// - `VeepooDeviceHelper`: 负责设备基础操作（密码验证、设置个人信息、读取电量）
/// - `VeepooHealthHelper`: 负责健康数据读取（睡眠、计步、原始数据）
@objc(VeepooBleModule)
final class VeepooBleModule: RCTEventEmitter {
  
  // MARK: - Helpers
  
  /// 连接助手：处理扫描、连接、断开及蓝牙状态
  private lazy var connectionHelper: VeepooConnectionHelper = {
    let helper = VeepooConnectionHelper()
    // 转发连接助手发出的事件到 JS
    helper.onEvent = { [weak self] name, body in
        self?.emitEvent(name, body: body)
    }
    return helper
  }()
  
  /// 设备助手：处理密码验证、个人信息设置等
  private lazy var deviceHelper: VeepooDeviceHelper = {
    let helper = VeepooDeviceHelper()
    return helper
  }()
  
  /// 健康助手：处理睡眠、计步、原始数据读取
  private lazy var healthHelper: VeepooHealthHelper = {
    let helper = VeepooHealthHelper()
    // 转发健康助手发出的事件（如读取进度）到 JS
    helper.onEvent = { [weak self] name, body in
        self?.emitEvent(name, body: body)
    }
    return helper
  }()
  
  /// 测试助手：处理手动测量（心率等）
  private lazy var testHelper: VeepooTestHelper = {
    let helper = VeepooTestHelper()
    // 转发测试助手发出的事件（如实时心率）到 JS
    helper.onEvent = { [weak self] name, body in
        self?.emitEvent(name, body: body)
    }
    return helper
  }()
  
  // MARK: - Properties
  
  /// 标记 JS 侧是否有监听器（用于优化事件发送，无监听时不发送）
  private var hasListeners = false
  
  // MARK: - Lifecycle
  
  /// 初始化模块
  override init() {
    super.init()
    // SDK 初始化虽然主要由 initSDK 触发，但这里也预先调用连接助手的初始化
    // 确保在模块加载时就尝试建立 CBCentralManager
    DispatchQueue.main.async {
        self.connectionHelper.initializeSDK()
    }
  }
  
  /// 告知 RN 此模块需要在主线程初始化
  override static func requiresMainQueueSetup() -> Bool {
    true
  }
  
  /// 定义支持的事件列表
  /// JS 端使用 NativeEventEmitter 订阅这些事件
  override func supportedEvents() -> [String]! {
    [
      // --- Connection & System ---
      "VeepooDeviceFound",         // 扫描发现设备
      "VeepooDeviceConnected",     // 设备已连接
      "VeepooDeviceDisconnected",  // 设备已断开
      "VeepooDeviceConnectStatus", // 连接状态变更
      "VeepooDeviceReady",         // 设备准备就绪（可进行数据操作）
      "VeepooBluetoothStateChanged",// 系统蓝牙状态变更
      "VeepooDeviceFunction",      // 设备功能列表
      "VeepooDeviceVersion",       // 设备版本信息

      // --- Data Sync ---
      "VeepooReadOriginProgress",  // 原始数据读取进度
      "VeepooReadOriginComplete",  // 原始数据读取完成
      "VeepooOriginHalfHourData",  // 30分钟原始数据

      // --- Manual Testing ---
      "VeepooHeartRateData",       // 实时心率数据
      "VeepooBloodPressureData",   // 实时血压数据
      "VeepooOxygenData",          // 实时血氧数据
      "VeepooBloodGlucoseData",    // 实时血糖数据
      "VeepooStressData"           // 实时压力数据
    ]
  }
  
  /// JS 端开始监听事件时的回调
  override func startObserving() {
    hasListeners = true
    // 重新发送当前的蓝牙状态，确保 JS 获得最新状态（例如进入页面时蓝牙已关闭）
    DispatchQueue.main.async {
        let payload = self.connectionHelper.currentBluetoothStatusPayload()
        self.emitEvent("VeepooBluetoothStateChanged", body: payload)
    }
  }
  
  /// JS 端停止监听事件时的回调
  override func stopObserving() {
    hasListeners = false
  }
  
  /// 发送事件的内部辅助方法
  /// - Parameters:
  ///   - name: 事件名称
  ///   - body: 事件携带的数据
  private func emitEvent(_ name: String, body: Any?) {
    if hasListeners {
        sendEvent(withName: name, body: body)
    }
  }
  
  // MARK: - Bridge Methods
  
  /// 初始化 SDK
  /// 通常在 App 启动或进入设备管理页时调用
  @objc
  func initSDK() {
    print("🔵 [VeepooBleModule] initSDK 已调用")
    connectionHelper.initializeSDK()
  }
  
  /// 获取当前蓝牙状态
  /// - Returns: Promise 返回包含 state, authorization, isScanning 等状态的字典
  @objc(getBluetoothStatus:reject:)
  func getBluetoothStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject _: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
        resolve(self.connectionHelper.currentBluetoothStatusPayload())
    }
  }
  
  /// 开始扫描设备
  /// 会触发 VeepooDeviceFound 事件
  @objc
  func startScan() {
    connectionHelper.startScan()
  }
  
  /// 停止扫描
  @objc
  func stopScan() {
    connectionHelper.stopScan()
  }
  
  /// 连接指定设备
  /// - Parameters:
  ///   - macAddress: 设备的 MAC 地址
  ///   - uuid: 设备的 UUID（可选，但推荐传入以提高连接成功率）
  /// - Returns: Promise 成功表示连接请求已发送（具体成功需监听 VeepooDeviceConnected）
  @objc(connectDevice:uuid:resolve:reject:)
  func connectDevice(_ macAddress: String, uuid: String?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    connectionHelper.connectDevice(macAddress, uuid: uuid, resolve: resolve, reject: reject)
  }
  
  /// 断开设备连接
  /// - Parameter macAddress: 目标设备 MAC
  @objc(disconnectDevice:)
  func disconnectDevice(_ macAddress: String) {
    connectionHelper.disconnectDevice(macAddress)
  }
  
  /// 验证连接密码
  /// Veepoo 设备连接后需验证密码才能通信，默认密码通常为 "0000"
  /// - Parameters:
  ///   - password: 密码字符串
  ///   - is24Hour: 是否使用 24 小时制（部分设备在此步骤同步时间格式）
  @objc(verifyPassword:is24Hour:resolve:reject:)
  func verifyPassword(_ password: String, is24Hour: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    deviceHelper.verifyPassword(password, is24Hour: is24Hour, resolve: resolve, reject: reject)
  }
  
  /// 同步个人信息
  /// 设置用户的身高、体重等，影响卡路里计算算法
  /// - Parameters:
  ///   - sex: 性别 (0:女, 1:男)
  ///   - height: 身高 (米)
  ///   - weight: 体重 (kg)
  ///   - age: 年龄
  ///   - stepAim: 目标步数
  ///   - sleepAim: 目标睡眠时长 (分钟)
  @objc(syncPersonInfo:height:weight:age:stepAim:sleepAim:resolve:reject:)
  func syncPersonInfo(_ sex: Int, height: Double, weight: Double, age: Int, stepAim: Int, sleepAim: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    deviceHelper.syncPersonInfo(sex, height: height, weight: weight, age: age, stepAim: stepAim, sleepAim: sleepAim, resolve: resolve, reject: reject)
  }
  
  /// 读取自动测量设置
  @objc(readAutoMeasureSetting:reject:)
  func readAutoMeasureSetting(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    deviceHelper.readAutoMeasureSetting(resolve, reject: reject)
  }
  
  /// 修改自动测量设置
  @objc(modifyAutoMeasureSetting:resolve:reject:)
  func modifyAutoMeasureSetting(_ setting: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard let dict = setting as? [String: Any] else {
      reject("INVALID_PARAMS", "Invalid setting parameters", nil)
      return
    }
    deviceHelper.modifyAutoMeasureSetting(dict, resolve: resolve, reject: reject)
  }
  
  /// 读取设备电量
  /// - Returns: Promise 返回电量信息字典
  @objc(readBattery:reject:)
  func readBattery(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    deviceHelper.readBattery(resolve, reject: reject)
  }
  
  /// 获取设备版本号
  /// - Returns: Promise 返回包含 hardwareVersion, newVersion, description 的字典
  @objc(getDeviceVersion:reject:)
  func getDeviceVersion(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    deviceHelper.getDeviceVersion(resolve, reject: reject)
  }
  
  /// 读取原始健康数据（5分钟粒度）
  /// - Parameter dayOffset: 距离今天的天数偏移
  @objc(readOriginData:resolve:reject:)
  func readOriginData(_ dayOffset: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    healthHelper.readOriginData(dayOffset, resolve: resolve, reject: reject)
  }
  
  /// 读取睡眠数据
  /// - Parameter dayOffset: 距离今天的天数偏移
  @objc(readSleepData:resolve:reject:)
  func readSleepData(_ dayOffset: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    healthHelper.readSleepData(dayOffset, resolve: resolve, reject: reject)
  }
  
  /// 读取计步数据
  /// - Returns: Promise 返回包含步数、距离、卡路里的字典
  @objc(readSportStep:reject:)
  func readSportStep(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    healthHelper.readSportStep(resolve, reject: reject)
  }
  
  /// 读取设备全部数据（同步所有历史数据）
  /// 这是一个耗时操作，会有进度事件回调
  @objc(readDeviceAllData:reject:)
  func readDeviceAllData(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    healthHelper.readDeviceAllData(resolve, reject: reject)
  }
  
  /// 开始心率检测（手动测量）
  /// 开启后，设备会实时测量心率，并通过 VeepooHeartRateData 事件返回数据
  @objc(startDetectHeart:reject:)
  func startDetectHeart(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testHeartRate(true, resolve: resolve, reject: reject)
  }
  
  /// 停止心率检测
  @objc(stopDetectHeart:reject:)
  func stopDetectHeart(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testHeartRate(false, resolve: resolve, reject: reject)
  }
  
  /// 开始血压检测（手动测量）
  /// 开启后，设备会实时测量血压，并通过 VeepooBloodPressureData 事件返回数据
  @objc(startDetectBP:reject:)
  func startDetectBP(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testBloodPressure(true, resolve: resolve, reject: reject)
  }
  
  /// 停止血压检测
  @objc(stopDetectBP:reject:)
  func stopDetectBP(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testBloodPressure(false, resolve: resolve, reject: reject)
  }
  
  /// 开始血氧检测（手动测量）
  /// 开启后，设备会实时测量血氧，并通过 VeepooOxygenData 事件返回数据
  @objc(startDetectSPO2H:reject:)
  func startDetectSPO2H(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testOxygen(true, resolve: resolve, reject: reject)
  }
  
  /// 停止血氧检测
  @objc(stopDetectSPO2H:reject:)
  func stopDetectSPO2H(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testOxygen(false, resolve: resolve, reject: reject)
  }

  /// 开始压力检测（手动测量）
  /// 开启后，设备会实时测量压力，并通过 VeepooStressData 事件返回数据
  @objc(startDetectStress:reject:)
  func startDetectStress(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testStress(true, resolve: resolve, reject: reject)
  }

  /// 停止压力检测
  @objc(stopDetectStress:reject:)
  func stopDetectStress(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testStress(false, resolve: resolve, reject: reject)
  }
  
  /// 开始血糖检测（手动测量）
  /// 开启后，设备会实时测量血糖，并通过 VeepooBloodGlucoseData 事件返回数据
  @objc(measureBloodGlucose:reject:)
  func measureBloodGlucose(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testBloodGlucose(true, resolve: resolve, reject: reject)
  }
  
  /// 停止血糖检测
  @objc(cancelMeasureBloodGlucose:reject:)
  func cancelMeasureBloodGlucose(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    testHelper.testBloodGlucose(false, resolve: resolve, reject: reject)
  }
}
