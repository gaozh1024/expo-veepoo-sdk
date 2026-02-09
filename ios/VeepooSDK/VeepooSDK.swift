import ExpoModulesCore

public class VeepooSDKModule: Module {
  public func definition() -> ModuleDefinition {
    Name("VeepooSDK")

    Constants([
      "NAME": "VeepooSDK"
    ])

    AsyncFunction("isBluetoothEnabled") { (promise: Promise) in
      guard let bluetoothManager = self.bluetoothManager else {
        promise.reject("BLUETOOTH_NOT_SUPPORTED", "Bluetooth not supported on this device")
        return
      }

      guard bluetoothManager.state == .poweredOn else {
        promise.resolve(false)
        return
      }

      promise.resolve(true)
    }

    AsyncFunction("requestPermissions") { (promise: Promise) in
      guard let bluetoothManager = self.bluetoothManager else {
        promise.reject("BLUETOOTH_NOT_SUPPORTED", "Bluetooth not supported on this device")
        return
      }

      if bluetoothManager.authorization != .allowedAlways && bluetoothManager.authorization != .notDetermined {
        promise.reject("PERMISSION_DENIED", "Bluetooth permissions not granted. Please request permissions from your app.")
        return
      }

      promise.resolve(true)
    }

    AsyncFunction("startScanning") { (options: [String: Any]?, promise: Promise) in
      guard let bluetoothManager = self.bluetoothManager else {
        promise.reject("BLUETOOTH_NOT_SUPPORTED", "Bluetooth not available")
        return
      }

      guard bluetoothManager.state == .poweredOn else {
        promise.reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled")
        return
      }

      Log.info("Starting BLE scan...")
      promise.resolve(nil)
    }

    AsyncFunction("stopScanning") { (promise: Promise) in
      Log.info("Stopping BLE scan...")
      promise.resolve(nil)
    }

    AsyncFunction("connectToDevice") { (deviceId: String, options: [String: Any]?, promise: Promise) in
      Log.info("Connecting to device: \(deviceId)")
      promise.resolve(nil)
    }

    AsyncFunction("disconnectFromDevice") { (deviceId: String, promise: Promise) in
      Log.info("Disconnecting from device: \(deviceId)")
      promise.resolve(nil)
    }

    AsyncFunction("getConnectionStatus") { (deviceId: String, promise: Promise) in
      promise.resolve("disconnected")
    }

    AsyncFunction("sendData") { (deviceId: String, data: [Int], promise: Promise) in
      Log.info("Sending data to device: \(deviceId)")
      promise.resolve(nil)
    }
  }

  private var bluetoothManager: CBCentralManager? {
    appContext?.bluetoothManager
  }
}

public class VeepooSDK: NSObject {
  override init() {
    super.init()
  }
}
