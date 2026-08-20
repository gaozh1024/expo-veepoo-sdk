package expo.modules.smartwearablelink

import android.util.Log
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// 事件监听生命周期
fun ModuleDefinitionBuilder.defineLifecycle(module: SmartWearableLinkSDKModule) {
  OnStartObserving {
    Log.d("SmartWearableLinkSDKModule", "Started observing events")
    module.emitBluetoothStatus()
  }

  OnStopObserving {
    Log.d("SmartWearableLinkSDKModule", "Stopped observing events")
  }

  OnDestroy {
    module.cleanup()
  }
}
