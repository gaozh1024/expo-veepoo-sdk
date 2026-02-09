package expo.modules.veepoo;

import com.facebook.react.bridge.*;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.uimanager.annotations.ReactProp;
import android.util.Log;
import com.inuker.bluetooth.library.Code;
import com.veepoo.protocol.VPOperateManager;
import com.veepoo.protocol.listener.base.IBleWriteResponse;
import com.veepoo.protocol.listener.base.IConnectResponse;
import com.veepoo.protocol.listener.base.INotifyResponse;
import com.veepoo.protocol.listener.data.ICustomSettingDataListener;
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener;
import com.veepoo.protocol.listener.data.IPwdDataListener;
import com.veepoo.protocol.listener.data.ISocialMsgDataListener;
import com.veepoo.protocol.model.datas.*;
import com.veepoo.protocol.model.enums.EFunctionStatus;
import com.veepoo.protocol.model.enums.EPwdStatus;
import com.veepoo.protocol.model.enums.EOprateStauts;
import com.veepoo.protocol.model.enums.ESex;
import com.veepoo.protocol.model.enums.EOprateStauts;
import com.veepoo.protocol.model.settings.CustomSettingData;
import com.veepoo.protocol.shareprence.VpSpGetUtil;
import com.veepoo.protocol.model.datas.*;
import com.veepoo.protocol.util.VPLogger;

import expo.modules.core.interfaces.Module;
import expo.modules.core.interfaces.ExpoMethod;
import expo.modules.core.interfaces.Promise;
import expo.modules.core.interfaces.ReactContext;

import java.util.HashMap;
import java.util.Map;

import expo.modules.core.arguments.ExpoArguments;
import expo.modules.core.arguments.ReadableArguments;
import expo.modules.core.arguments.ReadableType;
import expo.modules.core.errors.ModuleNotFoundException;
import expo.modules.core.errors.ExpoUnexpectedNativeValueException;

@ExpoModule(name = "VeepooSDK")
public class VeepooSDKNativeModule extends Module {
  private static final String TAG = "VeepooSDKNativeModule";

  @ReactProp(name = "eventEmitter")
  public final DeviceEventEmitter eventEmitter;

  private Context context;
  private VeepooEventManager eventManager;
  private static VPOperateManager veepooManager;
  private static boolean isSDKInitialized = false;
  private static String connectedDeviceId = null;

  public VeepooSDKNativeModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.context = reactContext;
    this.eventEmitter = new DeviceEventEmitter(reactContext);
    this.eventManager = new VeepooEventManager(reactContext);
  }

  @Override
  public Map<String, Object> getConstants() {
    Map<String, Object> constants = new HashMap<>();
    return constants;
  }

  @Override
  public String getName() {
    return "VeepooSDK";
  }

  @ExpoMethod
  public Promise isBluetoothEnabled() {
    return new Promise((resolve, reject) -> {
      Thread.sleep(100);
      try {
        VPOperateManager manager = VPOperateManager.getInstance();
        if (manager == null) {
          resolve.reject("SDK_NOT_AVAILABLE", "Veepoo SDK Manager is null");
          return;
        }
        if (!isSDKInitialized) {
          resolve.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initSDK() first");
          return;
        }
        boolean enabled = manager.isBluetoothEnabled();
        Log.d(TAG, "Bluetooth enabled: " + enabled);
        resolve(enabled);
      } catch (Exception e) {
        Log.e(TAG, "Error checking Bluetooth status", e);
        reject("BLUETOOTH_ERROR", e.getMessage());
      }
    });
  }

  @ExpoMethod
  public Promise requestPermissions() {
    return new Promise((resolve, reject) -> {
      Thread.sleep(100);
      try {
        VPOperateManager manager = VPOperateManager.getInstance();
        if (manager == null) {
          resolve.reject("SDK_NOT_AVAILABLE", "Veepoo SDK Manager is null");
          return;
        }
        if (!isSDKInitialized) {
          resolve.reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initSDK() first");
          return;
        }
        boolean hasPermission = checkBluetoothPermission();
        Log.d(TAG, "Has Bluetooth permission: " + hasPermission);
        resolve(hasPermission);
      } catch (Exception e) {
        Log.e(TAG, "Error requesting permissions", e);
        reject("PERMISSION_ERROR", e.getMessage());
      }
    });
  }

  @ExpoMethod
  public void initSDK() {
    Log.d(TAG, "Initializing Veepoo SDK...");
    try {
      VPOperateManager manager = VPOperateManager.getInstance();
      if (manager == null) {
        Log.e(TAG, "Failed to get Veepoo Manager instance");
        return;
      }
      manager.init(context.getApplicationContext());
      manager.setLogEnable(true);
      manager.setManufacturerIDFilter(false);
      isSDKInitialized = true;
      Thread.sleep(500);
      Log.d(TAG, "Veepoo SDK initialized successfully");
    } catch (Exception e) {
      Log.e(TAG, "Error initializing Veepoo SDK", e);
    }
  }

  @ExpoMethod
  public void addListener(String eventName) {
    eventManager.addListener(eventName);
  }

  @ExpoMethod
  public void removeListeners(Integer count) {
    eventManager.removeListeners(count);
  }

  @ExpoMethod
  public Promise startScanDevice(ReadableMap options) {
    return new Promise((resolve, reject) -> {
      try {
        VPOperateManager manager = VPOperateManager.getInstance();
        if (manager == null) {
          reject("SDK_NOT_AVAILABLE", "Veepoo SDK Manager is null");
          return;
        }
        if (!isSDKInitialized) {
          reject("SDK_NOT_INITIALIZED", "SDK not initialized. Call initSDK() first");
          return;
        }
        boolean isBluetoothOn = manager.isBluetoothEnabled();
        if (!isBluetoothOn) {
          reject("BLUETOOTH_NOT_ENABLED", "Bluetooth is not enabled");
          return;
        }
        manager.startScanDevice(new SearchResponse() {
          @Override
          public void onSearchStarted() {
            Log.d(TAG, "Scan started");
          }

          @Override
          public void onDeviceFounded(SearchResult result) {
            if (result != null) {
              Map<String, Object> device = new HashMap<>();
              device.put("id", result.address);
              device.put("name", result.name);
              device.put("rssi", result.rssi);
              device.put("mac", result.address);
              Map<String, Object> payload = new HashMap<>();
              payload.put("device", device);
              eventManager.emitEvent("deviceFound", payload);
              Log.d(TAG, "Device found: " + result.name);
            }
          }

          @Override
          public void onSearchStopped() {
            Log.d(TAG, "Scan stopped");
          }

          @Override
          public void onSearchCanceled() {
            Log.d(TAG, "Scan canceled");
          }
        });
        resolve(null);
      } catch (Exception e) {
        Log.e(TAG, "Error starting scan", e);
        reject("SCAN_ERROR", e.getMessage());
      }
    });
  }

  @ExpoModule(name = "VeepooSDK")
  public class VeepooEventManager {
    private final DeviceEventEmitter eventEmitter;

    public VeepooEventManager(ReactApplicationContext reactContext, DeviceEventEmitter eventEmitter) {
      this.eventEmitter = eventEmitter;
    }

    public void addListener(String eventName) {
      eventEmitter.addListener(eventName);
    }

    public void removeListeners(Integer count) {
      eventEmitter.removeListeners(count);
    }

    public void emitEvent(String eventName, Map<String, Object> payload) {
      eventEmitter.emit(eventName, payload);
    }
  }
}
