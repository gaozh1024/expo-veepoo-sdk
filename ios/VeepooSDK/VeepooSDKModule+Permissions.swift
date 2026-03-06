import ExpoModulesCore
import CoreBluetooth
import VeepooBleSDK
import UIKit
import os

/// 权限回调委托
final class PermissionDelegate: NSObject, CBCentralManagerDelegate {
  private weak var module: VeepooSDKModule?

  /// 初始化权限委托
  init(module: VeepooSDKModule) {
    self.module = module
  }

  /// 处理蓝牙状态变化
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    module?.handlePermissionStateUpdate(central)
  }
}

/// 蓝牙状态与权限
extension VeepooSDKModule {
  func definePermissions() {
    AsyncFunction("isBluetoothEnabled") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve(true)
      #else
      self.ensureCentralManager()
      guard let central = self.centralManager else {
        promise.reject("SDK_NOT_INITIALIZED", "Central manager not initialized")
        return
      }
      let isEnabled = central.state == .poweredOn
      promise.resolve(isEnabled)
      #endif
    }

    AsyncFunction("requestPermissions") { (promise: Promise) in
      #if targetEnvironment(simulator)
      promise.resolve("granted")
      #else
      let authorization = CBManager.authorization
      switch authorization {
      case .allowedAlways:
        promise.resolve("granted")
      case .restricted:
        promise.resolve("restricted")
      case .notDetermined:
        if self.permissionDelegate == nil {
          self.permissionDelegate = PermissionDelegate(module: self)
        }
        self.permissionPromise = promise
        self.permissionCentralManager = CBCentralManager(delegate: self.permissionDelegate, queue: nil, options: [:])
        self.centralManager = self.permissionCentralManager
      case .denied:
        promise.resolve("denied")
      @unknown default:
        promise.resolve("unknown")
      }
      #endif
    }
  }
  
  /// 处理权限回调状态
  func handlePermissionStateUpdate(_ central: CBCentralManager) {
    guard let promise = self.permissionPromise else { return }
    self.permissionPromise = nil
    
    switch central.state {
    case .poweredOn:
      promise.resolve("granted")
    case .poweredOff:
      promise.resolve("poweredOff")
    case .unauthorized:
      promise.resolve("denied")
    default:
      promise.resolve("unknown")
    }
  }
}
