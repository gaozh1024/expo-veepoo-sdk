import ExpoModulesCore
import CoreBluetooth
import VeepooBleSDK

/// 连接与蓝牙状态辅助方法
extension VeepooSDKModule {
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
    promise: Promise
  ) {
    #if !targetEnvironment(simulator)
    print("[VeepooSDK] performConnect - 开始, deviceId: \(deviceId)")
    
    connectionState = .connecting
    
    guard let manager = self.bleManager else {
      print("[VeepooSDK] performConnect - 错误: bleManager 为 nil")
      connectionState = .error("BLE manager is nil")
      promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
      return
    }
    
    print("[VeepooSDK] performConnect - 调用 veepooSDKConnectDevice")
    
    connectionTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      print("[VeepooSDK] performConnect - 连接超时")
      self.connectionState = .error("Connection timeout")
      self.sendEvent(DEVICE_CONNECT_STATUS, [
        "deviceId": deviceId,
        "status": "timeout"
      ])
      promise.reject("CONNECTION_TIMEOUT", "Connection timeout after 15 seconds")
    }
    
    manager.veepooSDKConnectDevice(model) { [weak self] connectState in
      guard let self = self else { return }
      
      self.connectionTimer?.invalidate()
      self.connectionTimer = nil
      
      print("[VeepooSDK] performConnect - 连接状态: \(connectState.rawValue)")
      
      switch connectState.rawValue {
      case 2:
        print("[VeepooSDK] performConnect - 连接成功")
        self.connectionState = .connected
        self.connectedDeviceId = deviceId
        self.sendEvent(DEVICE_CONNECTED, ["deviceId": deviceId, "isOadModel": false])
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "connected"])
        
        self.connectionState = .authenticating
        print("[VeepooSDK] performConnect - 准备认证，等待 0.3 秒")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
        }

        promise.resolve(nil)

      case 0:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "bluetoothOff"])
        promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is powered off")

      case 1:
        self.sendEvent(DEVICE_CONNECT_STATUS, [
          "deviceId": deviceId,
          "status": "connecting"
        ])

      case 3:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "failed"])
        promise.reject("CONNECTION_FAILED", "Connection failed")

      case 6:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "timeout"])
        promise.reject("TIMEOUT", "Connection timeout")

      default:
        self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "unknown", "code": connectState.rawValue])
        promise.reject("UNKNOWN", "Unknown connection error: \(connectState.rawValue)")
      }
    }
    #endif
  }

  func setupVeepooCallbacks() {
    #if !targetEnvironment(simulator)
    guard let manager = self.bleManager else { return }

    manager.vpBleCentralManageChangeBlock = { [weak self] _ in
      DispatchQueue.main.async {
        self?.emitBluetoothStatus()
      }
    }

    manager.vpBleConnectStateChangeBlock = { [weak self] state in
      guard let self = self else { return }

      let mac = self.connectedDeviceId ?? ""

      self.sendEvent(DEVICE_CONNECT_STATUS, [
        "deviceId": mac,
        "code": state.rawValue
      ])

      if state.rawValue == 0 {
        self.connectedDeviceId = nil
        self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": mac])
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

    self.discoveredDevices[exportId] = peripheralModel

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
      self.pendingConnectDeviceId = nil
      self.pendingConnectPromise = nil
      self.pendingConnectPassword = nil
      self.pendingConnectIs24Hour = false
      
      if let central = self.centralManager, self.isScanning {
        central.stopScan()
        self.isScanning = false
      }
      
      self.performConnect(
        model: peripheralModel,
        deviceId: exportId,
        password: pendingPassword,
        is24Hour: savedIs24Hour,
        promise: pendingPromise
      )
    }
    #endif
  }

  func verifyPasswordInternal(deviceId: String, password: String, is24Hour: Bool) {
    #if !targetEnvironment(simulator)
    print("[VeepooSDK] verifyPasswordInternal - 开始, deviceId: \(deviceId), password: \(password), 重试次数: \(authenticationRetryCount)")
    
    authenticationTimer?.invalidate()
    authenticationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      print("[VeepooSDK] verifyPasswordInternal - 认证超时")
      
      if self.authenticationRetryCount < self.maxAuthenticationRetries {
        self.authenticationRetryCount += 1
        print("[VeepooSDK] verifyPasswordInternal - 将进行第 \(self.authenticationRetryCount) 次重试")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
        }
      } else {
        self.connectionState = .error("Authentication timeout")
        self.sendEvent(PASSWORD_DATA, [
          "deviceId": deviceId,
          "data": [
            "status": "TIMEOUT",
            "password": password,
            "deviceNumber": "",
            "deviceVersion": "",
            "retryCount": self.authenticationRetryCount
          ]
        ])
        self.authenticationRetryCount = 0
      }
    }
    
    guard let manager = self.bleManager else {
      print("[VeepooSDK] verifyPasswordInternal - 错误: bleManager 为 nil")
      authenticationTimer?.invalidate()
      authenticationTimer = nil
      connectionState = .error("BLE manager is nil")
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": "FAILED",
          "password": password,
          "deviceNumber": "",
          "deviceVersion": "",
          "error": "BLE manager is nil"
        ]
      ])
      return
    }
    
    print("[VeepooSDK] verifyPasswordInternal - bleManager 存在")
    manager.is24HourFormat = is24Hour

    guard let passwordType = SynchronousPasswordType(rawValue: 0) else {
      print("[VeepooSDK] verifyPasswordInternal - 错误: SynchronousPasswordType 创建失败")
      authenticationTimer?.invalidate()
      authenticationTimer = nil
      connectionState = .error("Invalid password type")
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": "FAILED",
          "password": password,
          "deviceNumber": "",
          "deviceVersion": "",
          "error": "Invalid password type"
        ]
      ])
      return
    }

    print("[VeepooSDK] verifyPasswordInternal - 调用 veepooSDKSynchronousPassword")
    manager.veepooSDKSynchronousPassword(with: passwordType, password: password) { [weak self] result in
      guard let self = self else {
        print("[VeepooSDK] verifyPasswordInternal - 错误: self 为 nil")
        return
      }

      self.authenticationTimer?.invalidate()
      self.authenticationTimer = nil

      print("[VeepooSDK] verifyPasswordInternal - 密码验证结果: \(result.rawValue)")

      let success = (result.rawValue == 1) || (result.rawValue == 6)
      let status = success ? "SUCCESS" : "FAILED"

      self.sendEvent(PASSWORD_DATA, [
        "deviceId": deviceId,
        "data": [
          "status": status,
          "password": password,
          "deviceNumber": String(manager.peripheralModel?.deviceNumber ?? 0),
          "deviceVersion": manager.peripheralModel?.deviceVersion ?? "",
          "retryCount": self.authenticationRetryCount
        ]
      ])

      if success {
        print("[VeepooSDK] verifyPasswordInternal - 密码验证成功, 发送 DEVICE_READY 事件")
        self.connectionState = .ready
        self.authenticationRetryCount = 0
        self.sendEvent(DEVICE_READY, ["deviceId": deviceId, "isOadModel": false])
      } else {
        print("[VeepooSDK] verifyPasswordInternal - 密码验证失败, result: \(result.rawValue)")
        
        if self.authenticationRetryCount < self.maxAuthenticationRetries {
          self.authenticationRetryCount += 1
          print("[VeepooSDK] verifyPasswordInternal - 将进行第 \(self.authenticationRetryCount) 次重试")
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.verifyPasswordInternal(deviceId: deviceId, password: password, is24Hour: is24Hour)
          }
        } else {
          self.connectionState = .error("Authentication failed after \(self.authenticationRetryCount) retries")
          self.authenticationRetryCount = 0
        }
      }
    }
    #endif
  }

  func emitBluetoothStatus() {
    #if !targetEnvironment(simulator)
    var stateCode = 0
    var stateName = "unknown"

    if let central = centralManager {
      switch central.state {
      case .unknown: stateCode = 0; stateName = "unknown"
      case .resetting: stateCode = 1; stateName = "resetting"
      case .unsupported: stateCode = 2; stateName = "unsupported"
      case .unauthorized: stateCode = 3; stateName = "unauthorized"
      case .poweredOff: stateCode = 4; stateName = "poweredOff"
      case .poweredOn: stateCode = 5; stateName = "poweredOn"
      @unknown default: stateCode = 0; stateName = "unknown"
      }
    }

    let authorization: Int
    let authorizationName: String

    if #available(iOS 13.0, *) {
      switch CBManager.authorization {
      case .notDetermined: authorization = 0; authorizationName = "notDetermined"
      case .restricted: authorization = 1; authorizationName = "restricted"
      case .denied: authorization = 2; authorizationName = "denied"
      case .allowedAlways: authorization = 3; authorizationName = "allowedAlways"
      @unknown default: authorization = 0; authorizationName = "unknown"
      }
    } else {
      authorization = 0
      authorizationName = "unknown"
    }

    self.sendEvent(BLUETOOTH_STATE_CHANGED, [
      "state": stateCode,
      "stateName": stateName,
      "authorization": authorization,
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
    connectedDeviceId = nil
    isInitialized = false
    discoveredDevices.removeAll()
    connectionState = .idle
  }
}
