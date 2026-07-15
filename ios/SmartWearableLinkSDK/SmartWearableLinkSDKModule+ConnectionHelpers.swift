import ExpoModulesCore
import CoreBluetooth
import VeepooBleSDK

/// 连接与蓝牙状态辅助方法
extension SmartWearableLinkSDKModule {
  func emitNativeError(code: String, message: String, deviceId: String? = nil, rawCode: Int? = nil) {
    var payload: [String: Any] = [
      "code": code,
      "message": message
    ]
    if let deviceId = deviceId, !deviceId.isEmpty {
      payload["deviceId"] = deviceId
    }
    if let rawCode = rawCode {
      payload["rawCode"] = rawCode
    }
    self.sendEvent(ERROR, payload)
  }

  func emitConnectionStatus(deviceId: String, status: String, code: Int? = nil) {
    var payload: [String: Any] = [
      "deviceId": deviceId,
      "status": status
    ]
    if let code = code {
      payload["code"] = code
    }
    self.sendEvent(DEVICE_CONNECT_STATUS, payload)
    self.sendEvent(CONNECTION_STATUS_CHANGED, [
      "deviceId": deviceId,
      "status": status
    ])
  }

  func ensureCentralManager() {
    #if !targetEnvironment(simulator)
    if centralManager != nil { return }
    centralManager = CBCentralManager(delegate: nil, queue: nil, options: [
      CBCentralManagerOptionShowPowerAlertKey: true
    ])
    #endif
  }

  func performConnect(
    model: VPPeripheralModel,
    deviceId: String,
    password: String,
    is24Hour: Bool,
    promise: Promise,
    fallbackToScan: (() -> Void)? = nil
  ) {
    #if !targetEnvironment(simulator)
    print("[SmartWearableLinkSDK] performConnect - 开始, deviceId: \(deviceId)")
    print("[SmartWearableLinkSDK] performConnect - 当前上下文, connectedDeviceId: \(self.connectedDeviceId ?? "nil"), activeConnectDeviceId: \(self.activeConnectDeviceId ?? "nil"), state: \(self.connectionState.rawValue), pendingScanStart: \(self.pendingScanStart), isScanning: \(self.isScanning)")

    activeConnectDeviceId = deviceId
    connectionState = .connecting

    guard let manager = self.bleManager else {
      print("[SmartWearableLinkSDK] performConnect - 错误: bleManager 为 nil")
      activeConnectDeviceId = nil
      connectionState = .error("BLE manager is nil")
      emitNativeError(code: "SDK_NOT_INITIALIZED", message: "BLE manager is nil", deviceId: deviceId)
      promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
      return
    }

    print("[SmartWearableLinkSDK] performConnect - calling native connect API")

    var isSettled = false

    connectionTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      guard !isSettled else { return }
      isSettled = true
      print("[SmartWearableLinkSDK] performConnect - 连接超时, deviceId: \(deviceId), state: \(self.connectionState.rawValue), connectedDeviceId: \(self.connectedDeviceId ?? "nil"), activeConnectDeviceId: \(self.activeConnectDeviceId ?? "nil")")
      self.connectionState = .error("Connection timeout")
      self.emitConnectionStatus(deviceId: deviceId, status: "error")
      self.emitNativeError(code: "CONNECTION_TIMEOUT", message: "Connection timeout after 15 seconds", deviceId: deviceId)
      if let fallbackToScan = fallbackToScan {
        fallbackToScan()
      } else {
        promise.reject("CONNECTION_TIMEOUT", "Connection timeout after 15 seconds")
      }
    }

    manager.veepooSDKConnectDevice(model) { [weak self] connectState in
      guard let self = self else { return }

      print("[SmartWearableLinkSDK] performConnect - 连接状态: \(connectState.rawValue)")
      print("[SmartWearableLinkSDK] performConnect - 回调现场, deviceId: \(deviceId), state: \(self.connectionState.rawValue), connectedDeviceId: \(self.connectedDeviceId ?? "nil"), activeConnectDeviceId: \(self.activeConnectDeviceId ?? "nil"), isSettled: \(isSettled)")

      switch connectState.rawValue {
      case 2:
        guard !isSettled else { return }
        isSettled = true
        self.connectionTimer?.invalidate()
        self.connectionTimer = nil
        print("[SmartWearableLinkSDK] performConnect - 连接成功")
        self.connectionState = .connected
        self.connectedDeviceId = deviceId
        self.sendEvent(DEVICE_CONNECTED, ["deviceId": deviceId, "isOadModel": false])

        self.connectionState = .authenticating
        print("[SmartWearableLinkSDK] performConnect - 准备认证，等待 0.3 秒")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
        }

        promise.resolve(nil)

      case 0:
        guard !isSettled else { return }
        isSettled = true
        self.connectionTimer?.invalidate()
        self.connectionTimer = nil
        self.connectionState = .error("Device disconnected before connection completed")
        self.emitConnectionStatus(deviceId: deviceId, status: "error", code: connectState.rawValue)
        self.emitNativeError(
          code: "DEVICE_DISCONNECTED",
          message: "Device disconnected before connection completed",
          deviceId: deviceId,
          rawCode: connectState.rawValue
        )
        if let fallbackToScan = fallbackToScan {
          print("[SmartWearableLinkSDK] performConnect - 连接前断开，改走隐藏扫描兜底")
          fallbackToScan()
        } else {
          promise.reject("DEVICE_DISCONNECTED", "Device disconnected before connection completed")
        }

      case 1:
        self.connectionState = .connecting
        print("[SmartWearableLinkSDK] performConnect - 仍在连接中, deviceId: \(deviceId), 将继续等待成功/失败终态")
        self.emitConnectionStatus(deviceId: deviceId, status: "connecting", code: connectState.rawValue)

      case 3:
        guard !isSettled else { return }
        isSettled = true
        self.connectionTimer?.invalidate()
        self.connectionTimer = nil
        self.connectionState = .error("Connection failed")
        self.emitConnectionStatus(deviceId: deviceId, status: "error", code: connectState.rawValue)
        self.emitNativeError(
          code: "CONNECTION_FAILED",
          message: "Connection failed",
          deviceId: deviceId,
          rawCode: connectState.rawValue
        )
        if let fallbackToScan = fallbackToScan {
          fallbackToScan()
        } else {
          promise.reject("CONNECTION_FAILED", "Connection failed")
        }

      case 6:
        guard !isSettled else { return }
        isSettled = true
        self.connectionTimer?.invalidate()
        self.connectionTimer = nil
        self.connectionState = .error("Connection timeout")
        self.emitConnectionStatus(deviceId: deviceId, status: "error", code: connectState.rawValue)
        self.emitNativeError(
          code: "TIMEOUT",
          message: "Connection timeout",
          deviceId: deviceId,
          rawCode: connectState.rawValue
        )
        if let fallbackToScan = fallbackToScan {
          fallbackToScan()
        } else {
          promise.reject("TIMEOUT", "Connection timeout")
        }

      default:
        guard !isSettled else { return }
        isSettled = true
        self.connectionTimer?.invalidate()
        self.connectionTimer = nil
        self.connectionState = .error("Unknown connection error: \(connectState.rawValue)")
        self.emitConnectionStatus(deviceId: deviceId, status: "error", code: connectState.rawValue)
        self.emitNativeError(
          code: "UNKNOWN",
          message: "Unknown connection error: \(connectState.rawValue)",
          deviceId: deviceId,
          rawCode: connectState.rawValue
        )
        if let fallbackToScan = fallbackToScan {
          fallbackToScan()
        } else {
          promise.reject("UNKNOWN", "Unknown connection error: \(connectState.rawValue)")
        }
      }
    }
    #endif
  }

  func startScanConnectFallback(
    deviceId: String,
    password: String,
    is24Hour: Bool,
    promise: Promise,
    timeout: TimeInterval = 5.0
  ) {
    #if !targetEnvironment(simulator)
    print("[SmartWearableLinkSDK] startScanConnectFallback - 开始, deviceId: \(deviceId), timeout: \(timeout), isScanning: \(self.isScanning), discoveredCount: \(self.discoveredDevices.count)")
    self.pendingConnectDeviceId = deviceId
    self.pendingConnectPassword = password
    self.pendingConnectIs24Hour = is24Hour
    self.pendingConnectPromise = promise
    self.pendingScanStart = true

    if !self.isScanning {
      guard let manager = self.bleManager else {
        promise.reject("BLUETOOTH_UNAVAILABLE", "Bluetooth manager not available")
        return
      }
      self.isScanning = true
      self.emitBluetoothStatus()
      print("[SmartWearableLinkSDK] startScanConnectFallback - 启动扫描兜底, deviceId: \(deviceId)")
      manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] peripheralModel in
        guard let self = self, let model = peripheralModel else { return }
        self.handleDiscoveredDevice(model)
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      guard let self = self else { return }
      if self.pendingConnectDeviceId == deviceId {
        print("[SmartWearableLinkSDK] startScanConnectFallback - 扫描兜底超时, deviceId: \(deviceId), discoveredCount: \(self.discoveredDevices.count)")
        self.bleManager?.veepooSDKStopScanDevice()
        self.isScanning = false
        self.pendingScanStart = false
        self.emitBluetoothStatus()
        if let pendingPromise = self.pendingConnectPromise {
          self.pendingConnectPromise = nil
          self.pendingConnectDeviceId = nil
          self.pendingConnectPassword = nil
          self.pendingConnectIs24Hour = false
          pendingPromise.reject("DEVICE_NOT_FOUND", "Device not found after scanning.")
        }
      }
    }
    #endif
  }

  func setupSmartWearableLinkCallbacks() {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager else { return }

    manager.vpBleCentralManageChangeBlock = { [weak self] _ in
      DispatchQueue.main.async {
        self?.emitBluetoothStatus()
      }
    }

    manager.vpBleConnectStateChangeBlock = { [weak self] state in
      guard let self = self else { return }

      let deviceId = self.connectedDeviceId ?? self.activeConnectDeviceId ?? ""
      let status: String
      switch state.rawValue {
      case 0:
        status = "disconnected"
      case 1:
        status = "connecting"
      case 2:
        status = "connected"
      default:
        status = "error"
      }

      if !deviceId.isEmpty {
        self.emitConnectionStatus(deviceId: deviceId, status: status, code: state.rawValue)
      }

      if state.rawValue == 0 {
        let failedDuringConnect: Bool
        switch self.connectionState {
        case .connecting, .connected, .discoveringServices, .authenticating:
          failedDuringConnect = true
        default:
          failedDuringConnect = false
        }

        self.connectedDeviceId = nil
        self.activeConnectDeviceId = nil
        if !deviceId.isEmpty {
          self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
        }
        if failedDuringConnect {
          self.connectionState = .error("Device disconnected during connection")
          self.emitNativeError(
            code: "DEVICE_DISCONNECTED",
            message: "Device disconnected during connection",
            deviceId: deviceId,
            rawCode: state.rawValue
          )
        } else {
          self.connectionState = .disconnected
        }
      }
    }
    #endif
  }

  func handleDiscoveredDevice(_ peripheralModel: VPPeripheralModel) {
    #if !targetEnvironment(simulator)
    let rawAddr = peripheralModel.deviceAddress
    let uuid = peripheralModel.peripheral.identifier.uuidString
    let name = peripheralModel.deviceName ?? "Unknown"
    let rssi = peripheralModel.rssi ?? 0

    let exportId = rawAddr ?? uuid

    print("[SmartWearableLinkSDK] handleDiscoveredDevice - 发现设备, exportId: \(exportId), uuid: \(uuid), name: \(name), pendingConnectDeviceId: \(self.pendingConnectDeviceId ?? "nil")")

    self.discoveredDevices[exportId] = peripheralModel
    self.discoveredDevices[uuid] = peripheralModel

    self.sendEvent(DEVICE_FOUND, [
      "device": [
        "id": exportId,
        "name": name,
        "rssi": rssi,
        "mac": exportId,
        "uuid": uuid
      ],
      "timestamp": Date().timeIntervalSince1970 * 1000
    ])
    
    if let pendingId = self.pendingConnectDeviceId,
       let pendingPromise = self.pendingConnectPromise,
       let pendingPassword = self.pendingConnectPassword,
       (pendingId == exportId || pendingId == uuid) {
      let savedIs24Hour = self.pendingConnectIs24Hour
      let requestedDeviceId = pendingId
      self.pendingConnectDeviceId = nil
      self.pendingConnectPromise = nil
      self.pendingConnectPassword = nil
      self.pendingConnectIs24Hour = false

      if self.isScanning {
        self.bleManager?.veepooSDKStopScanDevice()
        self.isScanning = false
        self.pendingScanStart = false
        self.emitBluetoothStatus()
      }

      self.performConnect(
        model: peripheralModel,
        deviceId: requestedDeviceId,
        password: pendingPassword,
        is24Hour: savedIs24Hour,
        promise: pendingPromise
      )
    }
    #endif
  }

  func verifyPasswordInternal(deviceId: String, password: String, is24Hour: Bool) {
    #if !targetEnvironment(simulator)
    print("[SmartWearableLinkSDK] verifyPasswordInternal - 开始, deviceId: \(deviceId), password: \(password), 重试次数: \(authenticationRetryCount), state: \(self.connectionState.rawValue), connectedDeviceId: \(self.connectedDeviceId ?? "nil"), activeConnectDeviceId: \(self.activeConnectDeviceId ?? "nil")")
    
    authenticationTimer?.invalidate()
    authenticationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      print("[SmartWearableLinkSDK] verifyPasswordInternal - 认证超时")
      
      if self.authenticationRetryCount < self.maxAuthenticationRetries {
        self.authenticationRetryCount += 1
        print("[SmartWearableLinkSDK] verifyPasswordInternal - 将进行第 \(self.authenticationRetryCount) 次重试")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
        }
      } else {
        self.connectionState = .error("Authentication timeout")
      self.emitNativeError(
        code: "AUTH_TIMEOUT",
        message: "Authentication timeout",
        deviceId: deviceId
      )
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": "TIMEOUT",
          "rawStatus": "TIMEOUT",
          "password": password,
          "pwd": password,
          "deviceNumber": "",
          "deviceVersion": "",
          "retryCount": self.authenticationRetryCount
          ]
        ])
        self.authenticationRetryCount = 0
      }
    }
    
    guard let manager = self.bleManager else {
      print("[SmartWearableLinkSDK] verifyPasswordInternal - 错误: bleManager 为 nil")
      authenticationTimer?.invalidate()
      authenticationTimer = nil
      connectionState = .error("BLE manager is nil")
      self.emitNativeError(code: "SDK_NOT_INITIALIZED", message: "BLE manager is nil", deviceId: deviceId)
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": "FAILED",
          "rawStatus": "FAILED",
          "password": password,
          "pwd": password,
          "deviceNumber": "",
          "deviceVersion": "",
          "error": "BLE manager is nil"
        ]
      ])
      return
    }
    
    print("[SmartWearableLinkSDK] verifyPasswordInternal - bleManager 存在")
    manager.is24HourFormat = is24Hour

    guard let passwordType = SynchronousPasswordType(rawValue: 0) else {
      print("[SmartWearableLinkSDK] verifyPasswordInternal - 错误: SynchronousPasswordType 创建失败")
      authenticationTimer?.invalidate()
      authenticationTimer = nil
      connectionState = .error("Invalid password type")
      self.emitNativeError(code: "INVALID_PASSWORD_TYPE", message: "Invalid password type", deviceId: deviceId)
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": "FAILED",
          "rawStatus": "FAILED",
          "password": password,
          "pwd": password,
          "deviceNumber": "",
          "deviceVersion": "",
          "error": "Invalid password type"
        ]
      ])
      return
    }

    print("[SmartWearableLinkSDK] verifyPasswordInternal - calling native password API")
    manager.veepooSDKSynchronousPassword(with: passwordType, password: password) { [weak self] result in
      guard let self = self else {
        print("[SmartWearableLinkSDK] verifyPasswordInternal - 错误: self 为 nil")
        return
      }

      self.authenticationTimer?.invalidate()
      self.authenticationTimer = nil

      print("[SmartWearableLinkSDK] verifyPasswordInternal - 密码验证结果: \(result.rawValue)")

      let success = (result.rawValue == 1) || (result.rawValue == 6)
      let status = success ? "SUCCESS" : "FAILED"

      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": status,
          "rawStatus": result.rawValue,
          "password": password,
          "pwd": password,
          "deviceNumber": String(manager.peripheralModel?.deviceNumber ?? 0),
          "deviceVersion": manager.peripheralModel?.deviceVersion ?? "",
          "retryCount": self.authenticationRetryCount
        ]
      ])

      if success {
        print("[SmartWearableLinkSDK] verifyPasswordInternal - 密码验证成功, 发送 DEVICE_READY 事件")
        self.connectionState = .ready
        self.activeConnectDeviceId = nil
        self.authenticationRetryCount = 0
        self.sendEvent(DEVICE_READY, ["deviceId": deviceId, "isOadModel": false])
      } else {
        print("[SmartWearableLinkSDK] verifyPasswordInternal - 密码验证失败, result: \(result.rawValue)")
        
        if self.authenticationRetryCount < self.maxAuthenticationRetries {
          self.authenticationRetryCount += 1
          print("[SmartWearableLinkSDK] verifyPasswordInternal - 将进行第 \(self.authenticationRetryCount) 次重试")
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
          }
        } else {
          self.connectionState = .error("Authentication failed after \(self.authenticationRetryCount) retries")
          self.emitNativeError(
            code: "AUTH_FAILED",
            message: "Authentication failed after \(self.authenticationRetryCount) retries",
            deviceId: deviceId,
            rawCode: result.rawValue
          )
          self.authenticationRetryCount = 0
        }
      }
    }
    #endif
  }

  func emitBluetoothStatus() {
    #if !targetEnvironment(simulator)
    var stateName = "unknown"

    if let central = centralManager {
      switch central.state {
      case .unknown: stateName = "unknown"
      case .resetting: stateName = "resetting"
      case .unsupported: stateName = "unsupported"
      case .unauthorized: stateName = "unauthorized"
      case .poweredOff: stateName = "poweredOff"
      case .poweredOn: stateName = "poweredOn"
      @unknown default: stateName = "unknown"
      }
    }

    let authorizationName: String

    if #available(iOS 13.0, *) {
      switch CBManager.authorization {
      case .notDetermined: authorizationName = "notDetermined"
      case .restricted: authorizationName = "restricted"
      case .denied: authorizationName = "denied"
      case .allowedAlways: authorizationName = "allowedAlways"
      @unknown default: authorizationName = "notDetermined"
      }
    } else {
      authorizationName = "notDetermined"
    }

    self.sendEvent(BLUETOOTH_STATE_CHANGED, [
      "state": stateName,
      "stateName": stateName,
      "authorization": authorizationName,
      "authorizationName": authorizationName,
      "isScanning": isScanning,
      "pendingScanStart": pendingScanStart
    ])
    #endif
  }

  func cleanup() {
    #if !targetEnvironment(simulator)
    bleManager?.veepooSDKStopScanDevice()
    bleManager?.veepooSDKDisconnectDevice()
    
    authenticationTimer?.invalidate()
    authenticationTimer = nil
    
    connectionTimer?.invalidate()
    connectionTimer = nil
    
    authenticationRetryCount = 0
    #endif
    isScanning = false
    pendingScanStart = false
    connectedDeviceId = nil
    isInitialized = false
    pendingConnectDeviceId = nil
    pendingConnectPassword = nil
    pendingConnectIs24Hour = false
    pendingConnectPromise = nil
    discoveredDevices.removeAll()
    connectionState = .idle
    emitBluetoothStatus()
  }
}
