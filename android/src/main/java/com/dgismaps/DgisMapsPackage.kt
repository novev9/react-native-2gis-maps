package com.dgismaps

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class DgisMapsPackage : BaseReactPackage() {
  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return listOf(DgisMapsViewManager())
  }

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return when (name) {
      DgisMapsModule.NAME -> DgisMapsModule(reactContext)
      else -> null
    }
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
    return ReactModuleInfoProvider {
      mapOf(
        DgisMapsModule.NAME to ReactModuleInfo(
          DgisMapsModule.NAME,
          DgisMapsModule.NAME,
          false,
          false,
          false,
          false,
          true
        )
      )
    }
  }
}
