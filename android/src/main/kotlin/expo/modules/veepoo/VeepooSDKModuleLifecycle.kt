package expo.modules.veepoo

import android.util.Log
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

// 事件监听生命周期
fun ModuleDefinitionBuilder.defineLifecycle(module: VeepooSDKModule) {
  OnStartObserving {
    Log.d("VeepooSDKModule", "Started observing events")
  }

  OnStopObserving {
    Log.d("VeepooSDKModule", "Stopped observing events")
  }

  OnDestroy {
    module.cleanup()
  }
}
