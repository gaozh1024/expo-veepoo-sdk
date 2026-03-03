import ExpoModulesCore
import CoreBluetooth
import VeepooBleSDK

/// Veepoo Expo 模块入口
public class VeepooSDKModule: Module {
  var bleManager: VPBleCentralManage?
  var peripheralManage: VPPeripheralManage?
  var isScanning = false
  var connectedDeviceId: String?
  var isInitialized = false
  var centralManager: CBCentralManager?
  var pendingScanStart = false
  var discoveredDevices: [String: VPPeripheralModel] = [:]
  var pendingConnectDeviceId: String?
  var pendingConnectPassword: String?
  var pendingConnectIs24Hour: Bool = false
  var pendingConnectPromise: Promise?
  var cachedDeviceFunctions: [String: Any] = [:]

  public func definition() -> ModuleDefinition {
    Name("VeepooSDK")

    // Events
    Events(
      "deviceFound",
      "deviceConnected",
      "deviceDisconnected",
      "deviceReady",
      "bluetoothStateChanged",
      "error"
    )

    // Initialization
    AsyncFunction("init") { (promise: Promise) in
      DispatchQueue.main.async {
        #if targetEnvironment(simulator)
        self.isInitialized = true
        promise.resolve(nil)
        #else
        guard let manager = VPBleCentralManage.sharedBleManager() else {
          promise.reject("SDK_NOT_AVAILABLE", "Failed to initialize Veepoo SDK")
          return
        }

        self.bleManager = manager
        self.peripheralManage = VPPeripheralManage.shareVPPeripheralManager()
        manager.peripheralManage = self.peripheralManage
        manager.isLogEnable = true
        manager.manufacturerIDFilter = false

        self.isInitialized = true
        promise.resolve(nil)
        #endif
      }
    }

    // Bluetooth Status
    AsyncFunction("isBluetoothEnabled") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(true)
      #else
      guard let central = self.centralManager else {
        promise.resolve(false)
        return
      }
      let isEnabled = central.state == .poweredOn
      promise.resolve(isEnabled)
      #endif
    }

    // Request Permissions
    AsyncFunction("requestPermissions") { (promise: Promise) in
      let authorization = CBManager.authorization
      switch authorization {
      case .allowedAlways, .notDetermined:
        promise.resolve(true)
      default:
        promise.resolve(false)
      }
    }

    // Start Scan
    AsyncFunction("startScan") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      guard self.isInitialized else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      self.pendingScanStart = true

      guard let manager = self.bleManager else {
        promise.reject("SDK_NOT_INITIALIZED", "BLE manager is nil")
        return
      }

      if self.isScanning {
        promise.resolve(nil)
        return
      }

      self.isScanning = true

      manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { peripheralModel in
        guard let model = peripheralModel else { return }
        self.handleDiscoveredDevice(model)
      }

      promise.resolve(nil)
      #endif
    }

    // Stop Scan
    AsyncFunction("stopScan") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(nil)
      #else
      self.pendingScanStart = false
      self.isScanning = false
      self.bleManager?.veepooSDKStopScanDevice()
      promise.resolve(nil)
      #endif
    }

    // Connect
    AsyncFunction("connect") { (deviceId: String, password: String?, promise: Promise) in
      #if targetEnvironment(simulator)
      self.connectedDeviceId = deviceId
      self.sendEvent("deviceConnected", ["deviceId": deviceId])
      promise.resolve(nil)
      #else
      guard self.isInitialized else {
        promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized")
        return
      }

      guard let device = self.discoveredDevices[deviceId] else {
        promise.reject("DEVICE_NOT_FOUND", "Device not found in discovered list")
        return
      }

      self.pendingConnectDeviceId = deviceId
      self.pendingConnectPassword = password ?? "0000"
      self.pendingConnectPromise = promise

      self.bleManager?.veepooSDKConnectDevice(device) { state in
        self.handleConnectionState(state)
      }
      #endif
    }

    // Disconnect
    AsyncFunction("disconnect") { (promise: Promise) in
      #if targetEnvironment(simulator)
      self.connectedDeviceId = nil
      promise.resolve(nil)
      #else
      guard let device = self.peripheralManage?.peripheralModel else {
        promise.resolve(nil)
        return
      }
      self.bleManager?.veepooSDKDisconnectDevice()
      self.connectedDeviceId = nil
      promise.resolve(nil)
      #endif
    }

    // Read Battery
    AsyncFunction("readBattery") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(["level": 85])
      #else
      guard self.isInitialized, let _ = self.peripheralManage?.peripheralModel else {
        promise.reject("DEVICE_NOT_CONNECTED", "Device not connected")
        return
      }
      self.peripheralManage?.veepooSDKReadDeviceBatteryInfo { isPercent, isLowBattery, battery in
        promise.resolve([
          "level": battery,
          "isPercent": isPercent,
          "isLowBattery": isLowBattery
        ])
      }
      #endif
    }
  }

  // MARK: - Helper Methods

  private func handleDiscoveredDevice(_ model: VPPeripheralModel) {
    guard let name = model.peripheral?.name, !name.isEmpty else { return }
    let deviceId = model.deviceAddress ?? UUID().uuidString

    self.discoveredDevices[deviceId] = model

    self.sendEvent("deviceFound", [
      "device": [
        "id": deviceId,
        "name": name,
        "rssi": model.rssi ?? 0,
        "mac": model.deviceAddress ?? ""
      ]
    ])
  }

  private func handleConnectionState(_ state: DeviceConnectState) {
    switch state {
    case .BleConnectSuccess:
      if let deviceId = pendingConnectDeviceId {
        connectedDeviceId = deviceId
        sendEvent("deviceConnected", ["deviceId": deviceId])
        pendingConnectPromise?.resolve(nil)
        pendingConnectPromise = nil
      }
    case .BleConnectFailed, .BleConnectTimeout, .BlePoweredOff:
      let deviceId = connectedDeviceId
      connectedDeviceId = nil
      sendEvent("deviceDisconnected", ["deviceId": deviceId as Any])
    default:
      break
    }
  }
}
