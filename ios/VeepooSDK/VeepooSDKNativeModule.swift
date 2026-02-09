import Foundation
import ExpoModulesCore
import React

@objc(VeepooSDKNativeModule)
public class VeepooSDKNativeModule: Module {
  
  private var deviceContext: ReactContext?
  private var eventEmitter: EventEmitter?
  private var sdkManager: VPBleCentralManage?
  private var peripheralManage: VPPeripheralManage?
  
  private var connectedDeviceId: String?
  private var isConnecting = false
  private var isScanning = false
  private var isInitialized = false
  
  @objc
  public func initializeSDK() {
    guard let context = deviceContext else {
      NSLog("❌ [VeepooSDKNativeModule] deviceContext is nil")
      return
    }
    
    guard let manager = VPBleCentralManage.sharedBleManager() else {
      NSLog("❌ [VeepooSDKNativeModule] VPBleCentralManage.sharedBleManager() returned nil")
      return
    }
    
    isInitialized = true
    
    let peripheralManage = VPPeripheralManage.shareVPPeripheralManager()
    manager.peripheralManage = peripheralManage
    
    manager.isLogEnable = true
    manager.manufacturerIDFilter = false
    
    setupCallbacks()
    
    sdkManager = manager
    self.peripheralManage = peripheralManage
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      NSLog("✅ [VeepooSDKNativeModule] SDK initialized with 0.8s delay")
    }
  }
  
  @objc
  public func isBluetoothEnabled(promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    guard manager.state == .poweredOn else {
      promise.resolve(false)
      return
    }
    
    promise.resolve(true)
  }
  
  @objc
  public func requestPermissions(promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    #if targetEnvironment(simulator)
    promise.reject("SIMULATOR_UNSUPPORTED", "Bluetooth not supported on simulator")
    #else
    let authorization = CBManager.authorization

    if authorization != .allowedAlways && authorization != .notDetermined {
      promise.reject("PERMISSION_DENIED", "Bluetooth permissions not granted")
      return
    }

    promise.resolve(true)
    #endif
  }
  
  @objc
  public func startScanDevice(promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    guard !isScanning else {
      promise.resolve(nil)
      return
    }
    
    guard manager.state == .poweredOn else {
      promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
      return
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      NSLog("🔍 [VeepooSDKNativeModule] Starting BLE scan...")
      
      manager.veepooSDKStartScanDevice { [weak self] in
        guard let self = self else { return }
        
        override func onSearchStarted() {
          NSLog("🔍 Scan started")
        }
        
        override func onDeviceFounded(peripheralModel: VPPeripheralModel) {
          let deviceMap = self.createDeviceMap(from: peripheralModel)
          self.sendEvent("deviceFound", deviceMap)
          NSLog("📱 Device found: \\(peripheralModel.deviceName ?? "Unknown")")
        }
        
        override func onSearchStopped() {
          self.isScanning = false
          self.sendEvent("bluetoothStateChanged", self.createBluetoothStatusMap(state: .poweredOn))
          NSLog("✅ Scan stopped")
        }
        
        override func onSearchCanceled() {
          self.isScanning = false
          NSLog("⚠️ Scan canceled")
        }
      }
      
      self.isScanning = true
      promise.resolve(nil)
    }
  }
  
  @objc
  public func stopScanDevice(promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    manager.veepooSDKStopScanDevice()
    isScanning = false
    
    promise.resolve(nil)
    NSLog("✅ Scan stopped")
  }
  
  @objc
  public func connectToDevice(deviceId: String, options: [String: Any], promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    guard manager.state == .poweredOn else {
      promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
      return
    }
    
    guard !isConnecting else {
      NSLog("⚠️ Already connecting")
      promise.resolve(nil)
      return
    }
    
    isConnecting = true
    connectedDeviceId = deviceId
    
    let password = options["password"] as? String ?? "0000"
    let is24Hour = options["is24Hour"] as? Bool ?? false
    
    NSLog("📡 Connecting to device: \\(deviceId)")
    
    sendConnectionStatusEvent(deviceId, state: .connecting)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      manager.veepooSDKConnectDevice(
        VPPeripheralModel(deviceAddress: deviceId),
        deviceConnect: { [weak self] in
          guard let self = self else { return }
          
          let code = connectState.rawValue
          
          if code == 2 {
            self.isConnecting = false
            self.connectedDeviceId = deviceId
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              NSLog("✅ Device connected: \\(deviceId)")
              self.sendConnectionStatusEvent(deviceId, state: .connected)
              
              if profile != nil && !profile!.isOadModel() {
                self.sendEvent("deviceReady", ["deviceId": deviceId])
              }
            }
          } else if code == 0 {
            self.isConnecting = false
            self.connectedDeviceId = nil
            self.sendConnectionStatusEvent(deviceId, state: .disconnected)
            promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth powered off")
          } else if code == 3 {
            self.isConnecting = false
            self.connectedDeviceId = nil
            self.sendConnectionStatusEvent(deviceId, state: .disconnected)
            promise.reject("CONNECTION_FAILED", "Connection failed")
          } else if code == 6 {
            self.isConnecting = false
            self.connectedDeviceId = nil
            self.sendConnectionStatusEvent(deviceId, state: .disconnected)
            promise.reject("CONNECTION_TIMEOUT", "Connection timeout")
          } else {
            self.isConnecting = false
            self.sendConnectionStatusEvent(deviceId, state: .disconnected)
            promise.reject("UNKNOWN_ERROR", "Unknown connection error: \\(code)")
          }
        },
        { password, is24Hour }
      )
    }
  }
  
  @objc
  public func disconnectFromDevice(deviceId: String, promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    connectedDeviceId = nil
    isConnecting = false
    
    manager.veepooSDKDisconnectDevice()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.sendEvent("deviceDisconnected", ["deviceId": deviceId])
      self.sendConnectionStatusEvent(deviceId, state: .disconnected)
      NSLog("✅ Device disconnected: \\(deviceId)")
    }
    
    promise.resolve(nil)
  }
  
  @objc
  public func verifyPassword(password: String, is24Hour: Bool, promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    guard connectedDeviceId != nil else {
      promise.reject("DEVICE_NOT_CONNECTED", "No device connected to verify password")
      return
    }
    
    NSLog("🔐 Verifying password...")
    
    let deviceTimeSetting = VPDeviceTimeSetting(
      year: Calendar.current.component.year,
      month: Calendar.current.component.month,
      day: Calendar.current.component.day,
      hour: Calendar.current.component.hour,
      minute: Calendar.current.component.minute,
      second: Calendar.current.component.second,
      system: is24Hour ? 1 : 0
    )
    
    manager.confirmDevicePwd(password, deviceTimeSetting, { password, is24Hour })
    
    promise.resolve(true)
  }
  
  @objc
  public func getConnectionStatus(deviceId: String, promise: Promise) {
    guard let manager = sdkManager else {
      promise.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initializeSDK() first")
      return
    }
    
    let status: ConnectionStatus
    if connectedDeviceId == deviceId {
      status = .connected
    } else {
      status = .disconnected
    }
    
    let statusMap = ["status": status]
    promise.resolve(statusMap)
  }
  
  private func setupCallbacks() {
    guard let manager = sdkManager else { return }
    
    manager.vpBleCentralManageChangeBlock = { [weak self] in
      guard let self = self else { return }
      
      let newState = ConnectionStatus.from(manager.state)
      
      if newState != .poweredOn {
        if self.isScanning {
          manager.veepooSDKStopScanDevice()
          self.isScanning = false
        }
      }
      
      self.sendEvent("bluetoothStateChanged", self.createBluetoothStatusMap(state: newState))
      NSLog("📶 Bluetooth state changed: \\(newState)")
    }
    
    manager.vpBleConnectStateChangeBlock = { [weak self] in
      guard let self = self else { return }
    }
  }
  
  private func sendEvent(_ eventName: String, payload: [String: Any]? = nil) {
    guard let emitter = eventEmitter else { return }
    emitter.emit("VeepooSDK_\\(eventName)", payload ?? [:])
  }
  
  private func sendConnectionStatusEvent(_ deviceId: String, state: ConnectionStatus) {
    let payload: [String: Any] = [
      "status": state,
      "deviceId": deviceId
    ]
    sendEvent("connectionStatusChanged", payload)
  }
  
  private func createDeviceMap(from peripheralModel: VPPeripheralModel) -> [String: Any] {
    let address = peripheralModel.deviceAddress ?? ""
    let name = peripheralModel.deviceName ?? "Unknown"
    let rssi = peripheralModel.rssi ?? 0
    let uuid = peripheralModel.identifier.uuidString
    
    return [
      "id": address,
      "name": name,
      "rssi": rssi,
      "mac": address,
      "uuid": uuid
    ]
  }
  
  private func createBluetoothStatusMap(state: ConnectionStatus) -> [String: Any] {
    return [
      "state": state,
      "isScanning": isScanning,
      "isConnecting": isConnecting
    ]
  }
}

private enum ConnectionStatus: String {
  case disconnected = "disconnected"
  case connecting = "connecting"
  case connected = "connected"
  case disconnecting = "disconnecting"
  case ready = "ready"
  case error = "error"
}

extension ConnectionStatus {
  init(_ cbState: CBManagerState) {
    switch cbState {
    case .unknown:
      self = .error
    case .resetting:
      self = .error
    case .unsupported:
      self = .error
    case .unauthorized:
      self = .error
    case .poweredOff:
      self = .disconnected
    case .poweredOn:
      self = .connected
    @unknown default:
      self = .error
    }
  }
}
