package com.dgismaps

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.Event
import com.facebook.react.viewmanagers.DgisMapsViewManagerDelegate
import com.facebook.react.viewmanagers.DgisMapsViewManagerInterface

@ReactModule(name = DgisMapsViewManager.NAME)
class DgisMapsViewManager : SimpleViewManager<DgisMapsView>(),
  DgisMapsViewManagerInterface<DgisMapsView> {
  private val delegate = DgisMapsViewManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<DgisMapsView> = delegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): DgisMapsView {
    return DgisMapsView(context).also { view ->
      view.eventSink = { name, body ->
        val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
        dispatcher?.dispatchEvent(
          DgisMapsEvent(
            UIManagerHelper.getSurfaceId(view),
            view.id,
            name,
            body
          )
        )
      }
    }
  }

  @ReactProp(name = "apiKey")
  override fun setApiKey(view: DgisMapsView?, value: String?) {
    view?.createMapIfPossible()
  }

  @ReactProp(name = "initialCamera")
  override fun setInitialCamera(view: DgisMapsView?, value: ReadableMap?) {
    view?.applyInitialCamera(value)
  }

  @ReactProp(name = "markers")
  override fun setMarkers(view: DgisMapsView?, value: ReadableArray?) {
    view?.setMarkers(value)
  }

  @ReactProp(name = "polylines")
  override fun setPolylines(view: DgisMapsView?, value: ReadableArray?) {
    view?.setPolylines(value)
  }

  @ReactProp(name = "polygons")
  override fun setPolygons(view: DgisMapsView?, value: ReadableArray?) {
    view?.setPolygons(value)
  }

  @ReactProp(name = "circles")
  override fun setCircles(view: DgisMapsView?, value: ReadableArray?) {
    view?.setCircles(value)
  }

  @ReactProp(name = "showsUserLocation", defaultBoolean = false)
  override fun setShowsUserLocation(view: DgisMapsView?, value: Boolean) {
    view?.setShowsUserLocation(value)
  }

  @ReactProp(name = "clusteringEnabled", defaultBoolean = false)
  override fun setClusteringEnabled(view: DgisMapsView?, value: Boolean) {
    view?.updateClustering(enabled = value)
  }

  @ReactProp(name = "clusteringRadius", defaultFloat = 80f)
  override fun setClusteringRadius(view: DgisMapsView?, value: Float) {
    view?.updateClustering(radius = value)
  }

  @ReactProp(name = "clusterColor")
  override fun setClusterColor(view: DgisMapsView?, value: Int) {
    view?.updateClustering(color = value)
  }

  @ReactProp(name = "clusterTextColor")
  override fun setClusterTextColor(view: DgisMapsView?, value: Int) {
    view?.updateClustering(textColor = value)
  }

  @ReactProp(name = "scrollEnabled", defaultBoolean = true)
  override fun setScrollEnabled(view: DgisMapsView?, value: Boolean) {
    view?.setGestures(scrollEnabled = value, zoomEnabled = true, rotateEnabled = true, tiltEnabled = true)
  }

  @ReactProp(name = "zoomEnabled", defaultBoolean = true)
  override fun setZoomEnabled(view: DgisMapsView?, value: Boolean) {
    view?.setGestures(scrollEnabled = true, zoomEnabled = value, rotateEnabled = true, tiltEnabled = true)
  }

  @ReactProp(name = "rotateEnabled", defaultBoolean = true)
  override fun setRotateEnabled(view: DgisMapsView?, value: Boolean) {
    view?.setGestures(scrollEnabled = true, zoomEnabled = true, rotateEnabled = value, tiltEnabled = true)
  }

  @ReactProp(name = "tiltEnabled", defaultBoolean = true)
  override fun setTiltEnabled(view: DgisMapsView?, value: Boolean) {
    view?.setGestures(scrollEnabled = true, zoomEnabled = true, rotateEnabled = true, tiltEnabled = value)
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> {
    return mutableMapOf(
      "onMapReady" to mapOf("registrationName" to "onMapReady"),
      "onMapTap" to mapOf("registrationName" to "onMapTap"),
      "onMarkerPress" to mapOf("registrationName" to "onMarkerPress"),
      "onCameraChanged" to mapOf("registrationName" to "onCameraChanged"),
      "onUserLocationChanged" to mapOf("registrationName" to "onUserLocationChanged")
    )
  }

  private class DgisMapsEvent(
    surfaceId: Int,
    viewTag: Int,
    private val reactEventName: String,
    private val body: Map<String, Any>
  ) : Event<DgisMapsEvent>(surfaceId, viewTag) {
    override fun getEventName(): String = reactEventName

    override fun getEventData() = Arguments.createMap().also { writable ->
      body.forEach { (key, value) ->
        when (value) {
          is String -> writable.putString(key, value)
          is Int -> writable.putInt(key, value)
          is Float -> writable.putDouble(key, value.toDouble())
          is Double -> writable.putDouble(key, value)
          is Boolean -> writable.putBoolean(key, value)
        }
      }
    }
  }

  companion object {
    const val NAME = "DgisMapsView"
  }
}
