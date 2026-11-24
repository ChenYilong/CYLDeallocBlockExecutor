package com.chenyilong.cyldeallocblockexecutor.rnexample

import android.app.Application
import android.content.ComponentCallbacks2
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost
import com.facebook.react.modules.core.DeviceEventManagerModule

class MainApplication : Application(), ReactApplication {

  override val reactHost: ReactHost by lazy {
    getDefaultReactHost(
      context = applicationContext,
      packageList =
        PackageList(this).packages.apply {
          // Packages that cannot be autolinked yet can be added manually here, for example:
          // add(MyReactNativePackage())
        },
    )
  }

  override fun onCreate() {
    super.onCreate()
    loadReactNative(this)
  }

  // Android has no `AppState` memoryWarning: forward the trim callbacks as the device event the library listens to.
  // `TRIM_MEMORY_UI_HIDDEN` (20) only means the UI went to the background, so it is not a warning (same rule as the Android binding).
  override fun onTrimMemory(level: Int) {
    super.onTrimMemory(level)
    if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW && level != ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
      emitMemoryWarning()
    }
  }

  override fun onLowMemory() {
    super.onLowMemory()
    emitMemoryWarning()
  }

  private fun emitMemoryWarning() {
    reactHost.currentReactContext
      ?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      ?.emit("cylMemoryWarning", null)
  }
}
