package com.dgismaps

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.DgisMapsViewManagerInterface
import com.facebook.react.viewmanagers.DgisMapsViewManagerDelegate

@ReactModule(name = DgisMapsViewManager.NAME)
class DgisMapsViewManager : SimpleViewManager<DgisMapsView>(),
  DgisMapsViewManagerInterface<DgisMapsView> {
  private val mDelegate: ViewManagerDelegate<DgisMapsView>

  init {
    mDelegate = DgisMapsViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<DgisMapsView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): DgisMapsView {
    return DgisMapsView(context)
  }

  @ReactProp(name = "color")
  override fun setColor(view: DgisMapsView?, color: Int?) {
    view?.setBackgroundColor(color ?: Color.TRANSPARENT)
  }

  companion object {
    const val NAME = "DgisMapsView"
  }
}
