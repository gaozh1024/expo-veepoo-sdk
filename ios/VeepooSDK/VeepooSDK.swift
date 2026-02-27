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
    defineEvents()
    defineInitialization()
    definePermissions()
    defineScan()
    defineConnection()
    defineReadData()
    defineWriteData()
    defineTests()
    defineLifecycle()
  }
}
