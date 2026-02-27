import ExpoModulesCore
import CoreBluetooth
import VeepooBleSDK

/// 连接相关接口
extension VeepooSDKModule {
  func defineConnection() {
    AsyncFunction("connect") { (deviceId: String, options: [String: Any]?, promise: Promise) in
      #if targetEnvironment(simulator)
      self.connectedDeviceId = deviceId
      self.sendEvent(DEVICE_CONNECTED, ["deviceId": deviceId, "isOadModel": false])
      self.sendEvent(DEVICE_READY, ["deviceId": deviceId, "isOadModel": false])
      promise.resolve(nil)
      #else
      guard self.isInitialized else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      guard let _ = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
        return
      }

      let password = options?["password"] as? String ?? "0000"
      let is24Hour = options?["is24Hour"] as? Bool ?? false
      let uuidString = options?["uuid"] as? String

      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "connecting"])

      var peripheralModel: VPPeripheralModel? = self.discoveredDevices[deviceId]

      if peripheralModel == nil,
         let uuidStr = uuidString,
         let uuid = UUID(uuidString: uuidStr),
         let central = self.centralManager {
        let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
          peripheralModel = VPPeripheralModel(peripher: peripheral)
        }
      }

      if let model = peripheralModel {
        self.performConnect(
          model: model,
          deviceId: deviceId,
          password: password,
          is24Hour: is24Hour,
          promise: promise
        )
      } else {
        self.pendingConnectDeviceId = deviceId
        self.pendingConnectPassword = password
        self.pendingConnectIs24Hour = is24Hour
        self.pendingConnectPromise = promise
        
        self.ensureCentralManager()
        if let central = self.centralManager {
          central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
          ])
          self.isScanning = true
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.pendingConnectDeviceId == deviceId {
              central.stopScan()
              self.isScanning = false
              if let pendingPromise = self.pendingConnectPromise {
                self.pendingConnectPromise = nil
                self.pendingConnectDeviceId = nil
                pendingPromise.reject("DEVICE_NOT_FOUND", "Device not found after scanning. Please ensure device is powered on and nearby.")
              }
            }
          }
        } else {
          promise.reject("BLUETOOTH_UNAVAILABLE", "Bluetooth manager not available")
        }
      }
      #endif
    }

    AsyncFunction("disconnect") { (deviceId: String, promise: Promise) in
      #if targetEnvironment(simulator)
      self.connectedDeviceId = nil
      self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "disconnected"])
      promise.resolve(nil)
      #else
      self.bleManager?.veepooSDKDisconnectDevice()
      self.connectedDeviceId = nil
      self.sendEvent(DEVICE_DISCONNECTED, ["deviceId": deviceId])
      self.sendEvent(DEVICE_CONNECT_STATUS, ["deviceId": deviceId, "status": "disconnected"])
      promise.resolve(nil)
      #endif
    }

    AsyncFunction("getConnectionStatus") { (deviceId: String, promise: Promise) in
      let status = self.connectedDeviceId == deviceId ? "connected" : "disconnected"
      promise.resolve(status)
    }

    AsyncFunction("verifyPassword") { (password: String, is24Hour: Bool, promise: Promise) in
      #if targetEnvironment(simulator)
      self.sendEvent(PASSWORD_DATA, [
        "deviceId": self.connectedDeviceId ?? "",
        "data": [
          "status": "SUCCESS",
          "password": password,
          "deviceNumber": "",
          "deviceVersion": ""
        ]
      ])
      self.sendEvent(DEVICE_READY, ["deviceId": self.connectedDeviceId ?? "", "isOadModel": false])
      promise.resolve([
        "status": "SUCCESS",
        "password": password,
        "deviceNumber": "",
        "deviceVersion": ""
      ])
      #else
      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
        return
      }

      manager.is24HourFormat = is24Hour

      manager.veepooSDKSynchronousPassword(with: SynchronousPasswordType(rawValue: 0)!, password: password) { result in
        let success = (result.rawValue == 1) || (result.rawValue == 6)
        let status = success ? "SUCCESS" : "FAILED"

        let resultData: [String: Any] = [
          "status": status,
          "password": password,
          "deviceNumber": String(manager.peripheralModel?.deviceNumber ?? 0),
          "deviceVersion": manager.peripheralModel?.deviceVersion ?? ""
        ]

        self.sendEvent(PASSWORD_DATA, [
          "deviceId": self.connectedDeviceId ?? "",
          "data": resultData
        ])

        if success {
          self.cacheDeviceFunctions()
          self.sendEvent(DEVICE_READY, ["deviceId": self.connectedDeviceId ?? "", "isOadModel": false])
        }

        promise.resolve(resultData)
      }
      #endif
    }
  }
}
