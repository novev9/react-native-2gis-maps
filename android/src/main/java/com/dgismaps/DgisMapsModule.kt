package com.dgismaps

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.turbomodule.core.interfaces.TurboModule
import com.facebook.react.uimanager.UIManagerHelper

@ReactModule(name = DgisMapsModule.NAME)
class DgisMapsModule(private val reactContext: ReactApplicationContext) :
  NativeDgisMapsModuleSpec(reactContext),
  TurboModule {
  override fun getName(): String = NAME

  override fun initialize(options: ReadableMap, promise: Promise) {
    val apiKey = options.getString("apiKey")
    if (apiKey.isNullOrBlank()) {
      promise.reject("E_DGIS_INVALID_API_KEY", "apiKey is required")
      return
    }

    try {
      val result = DGisSdkHolder.initialize(
        reactContext,
        apiKey,
        if (options.hasKey("logLevel")) options.getString("logLevel") else null
      )
      promise.resolve(result)
    } catch (error: Throwable) {
      promise.reject("E_DGIS_INIT_FAILED", error.message, error)
    }
  }

  override fun isInitialized(): Boolean = DGisSdkHolder.isInitialized

  override fun flyTo(
    viewTag: Double,
    latitude: Double,
    longitude: Double,
    zoom: Double,
    tilt: Double,
    bearing: Double,
    durationMs: Double,
    promise: Promise
  ) {
    // TODO: Prefer generated Fabric commands for per-view operations after MVP.
    UiThreadUtil.runOnUiThread {
      val view = resolveDgisView(viewTag.toInt())
      if (view == null) {
        promise.reject("E_DGIS_VIEW_NOT_FOUND", "Could not find DgisMapsView for tag ${viewTag.toInt()}")
        return@runOnUiThread
      }

      view.flyTo(latitude, longitude, zoom, tilt, bearing, durationMs.toInt())
      promise.resolve(true)
    }
  }

  override fun centerOnUserLocation(viewTag: Double, durationMs: Double, promise: Promise) {
    // TODO: Prefer generated Fabric commands for per-view operations after MVP.
    UiThreadUtil.runOnUiThread {
      val view = resolveDgisView(viewTag.toInt())
      if (view == null) {
        promise.reject("E_DGIS_VIEW_NOT_FOUND", "Could not find DgisMapsView for tag ${viewTag.toInt()}")
        return@runOnUiThread
      }

      view.centerOnUserLocation(durationMs.toInt())
      promise.resolve(true)
    }
  }

  override fun requestLocationPermission(promise: Promise) {
    val activity = currentActivity
    if (activity == null) {
      promise.resolve(false)
      return
    }

    if (hasLocationPermissionValue()) {
      promise.resolve(true)
      return
    }

    ActivityCompat.requestPermissions(
      activity,
      arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION
      ),
      LOCATION_PERMISSION_REQUEST
    )
    promise.resolve(false)
  }

  override fun hasLocationPermission(promise: Promise) {
    promise.resolve(hasLocationPermissionValue())
  }

  private fun hasLocationPermissionValue(): Boolean {
    val fine = ContextCompat.checkSelfPermission(
      reactContext,
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    val coarse = ContextCompat.checkSelfPermission(
      reactContext,
      Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    return fine || coarse
  }

  private fun resolveDgisView(tag: Int): DgisMapsView? {
    val uiManager = UIManagerHelper.getUIManager(reactContext, tag) ?: return null
    return try {
      uiManager.resolveView(tag) as? DgisMapsView
    } catch (_: Throwable) {
      null
    }
  }

  companion object {
    const val NAME = "DgisMapsModule"
    private const val LOCATION_PERMISSION_REQUEST = 2615
  }
}
