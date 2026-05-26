package com.dgismaps

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.util.Base64
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.ThemedReactContext
import ru.dgis.sdk.Color
import ru.dgis.sdk.Duration
import ru.dgis.sdk.Meter
import ru.dgis.sdk.ScreenPoint
import ru.dgis.sdk.coordinates.Bearing
import ru.dgis.sdk.coordinates.GeoPoint
import ru.dgis.sdk.coordinates.Latitude
import ru.dgis.sdk.coordinates.Longitude
import ru.dgis.sdk.geometry.GeoPointWithElevation
import ru.dgis.sdk.map.Anchor
import ru.dgis.sdk.map.CameraAnimationType
import ru.dgis.sdk.map.CameraPosition
import ru.dgis.sdk.map.Circle
import ru.dgis.sdk.map.CircleOptions
import ru.dgis.sdk.map.DashedPolylineOptions
import ru.dgis.sdk.map.DragBeginData
import ru.dgis.sdk.map.Image
import ru.dgis.sdk.map.LogicalPixel
import ru.dgis.sdk.map.MapObjectManager
import ru.dgis.sdk.map.MapOptions
import ru.dgis.sdk.map.MapView
import ru.dgis.sdk.map.Marker
import ru.dgis.sdk.map.MarkerOptions
import ru.dgis.sdk.map.MyLocationControlModel
import ru.dgis.sdk.map.MyLocationControllerSettings
import ru.dgis.sdk.map.MyLocationMapObjectMarkerType
import ru.dgis.sdk.map.MyLocationMapObjectSource
import ru.dgis.sdk.map.Polygon
import ru.dgis.sdk.map.PolygonOptions
import ru.dgis.sdk.map.Polyline
import ru.dgis.sdk.map.PolylineOptions
import ru.dgis.sdk.map.SimpleClusterObject
import ru.dgis.sdk.map.SimpleClusterOptions
import ru.dgis.sdk.map.SimpleClusterRenderer
import ru.dgis.sdk.map.SimpleMapObject
import ru.dgis.sdk.map.TextPlacement
import ru.dgis.sdk.map.TextStyle
import ru.dgis.sdk.map.Tilt
import ru.dgis.sdk.map.TouchEventsObserver
import ru.dgis.sdk.map.Zoom
import ru.dgis.sdk.map.ZIndex
import ru.dgis.sdk.map.imageFromBitmap
import ru.dgis.sdk.map.Map as DGisMap
import kotlin.collections.Map as KotlinMap

data class DgisMarkerSpec(
  val id: String,
  val latitude: Double,
  val longitude: Double,
  val iconBase64: String?,
  // Pre-resolved URI from Image.resolveAssetSource on the JS side. http(s)
  // for the Metro packager or CDN, file:// for prod-packaged assets.
  val iconUri: String?,
  val iconWidth: Float,
  val anchorX: Float,
  val anchorY: Float,
  val zIndex: Int
)

data class DgisPolylineSpec(
  val id: String,
  val points: List<GeoPoint>,
  val color: Int,
  val width: Float,
  val dashLength: Float,
  val dashSpace: Float,
  val zIndex: Int
)

data class DgisPolygonSpec(
  val id: String,
  val points: List<GeoPoint>,
  val fillColor: Int,
  val strokeColor: Int,
  val strokeWidth: Float,
  val zIndex: Int
)

data class DgisCircleSpec(
  val id: String,
  val latitude: Double,
  val longitude: Double,
  val radiusMeters: Float,
  val fillColor: Int,
  val strokeColor: Int,
  val strokeWidth: Float,
  val zIndex: Int
)

class DgisMapsView(context: Context) : FrameLayout(context) {
  var eventSink: ((String, KotlinMap<String, Any>) -> Unit)? = null

  private var mapView: MapView? = null
  private var map: DGisMap? = null
  private var objectManager: MapObjectManager? = null
  private var lifecycle: Lifecycle? = null
  private var locationSource: MyLocationMapObjectSource? = null
  private var locationModel: MyLocationControlModel? = null
  private var objectTapCallback: ((ru.dgis.sdk.map.RenderedObjectInfo) -> Unit)? = null
  private val pending = ArrayDeque<() -> Unit>()

  private var didApplyInitialCamera = false

  private var markerSpecs: KotlinMap<String, DgisMarkerSpec> = emptyMap()
  private var polylineSpecs: KotlinMap<String, DgisPolylineSpec> = emptyMap()
  private var polygonSpecs: KotlinMap<String, DgisPolygonSpec> = emptyMap()
  private var circleSpecs: KotlinMap<String, DgisCircleSpec> = emptyMap()

  private val markers = mutableMapOf<String, Marker>()
  private val polylines = mutableMapOf<String, Polyline>()
  private val polygons = mutableMapOf<String, Polygon>()
  private val circles = mutableMapOf<String, Circle>()

  private var clusteringEnabled = false
  private var clusteringRadius = 80f
  private var clusterColor = 0xff007aff.toInt()
  private var clusterTextColor = 0xffffffff.toInt()
  private var cachedDefaultMarkerIcon: Image? = null

  init {
    setBackgroundColor(android.graphics.Color.rgb(240, 240, 240))
    createMapIfPossible()
  }

  fun createMapIfPossible() {
    if (mapView != null) {
      return
    }

    DGisSdkHolder.contextOrNull() ?: return

    val view = MapView(context, MapOptions())
    mapView = view

    addView(
      view,
      LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
    )

    val owner = (context as? ThemedReactContext)?.currentActivity as? LifecycleOwner
    lifecycle = owner?.lifecycle
    lifecycle?.addObserver(view)

    view.getMapAsync { readyMap ->
      map = readyMap
      recreateObjectManager()
      bindEvents(view, readyMap)
      flushPending()
      eventSink?.invoke("onMapReady", emptyMap())
    }
  }

  private fun bindEvents(view: MapView, readyMap: DGisMap) {
    view.setTouchEventsObserver(object : TouchEventsObserver {
      override fun onTap(point: ScreenPoint) {
        val geo = readyMap.camera.projection.screenToMap(point) ?: return
        eventSink?.invoke(
          "onMapTap",
          mapOf(
            "latitude" to geo.latitude.value,
            "longitude" to geo.longitude.value,
            "x" to point.x,
            "y" to point.y
          )
        )
      }

      override fun onLongTouch(point: ScreenPoint) = Unit

      override fun onDragBegin(data: DragBeginData) = Unit

      override fun onDragMove(point: ScreenPoint) = Unit

      override fun onDragEnd() = Unit
    })

    val callback: (ru.dgis.sdk.map.RenderedObjectInfo) -> Unit = { info ->
      val marker = info.item.item as? Marker
      val id = marker?.userData as? String
      if (marker != null && id != null) {
        eventSink?.invoke(
          "onMarkerPress",
          mapOf(
            "id" to id,
            "latitude" to marker.position.latitude.value,
            "longitude" to marker.position.longitude.value
          )
        )
      }
    }

    objectTapCallback = callback
    view.addObjectTappedCallback(callback)
  }

  private fun withMap(block: () -> Unit) {
    if (map == null || objectManager == null) {
      pending.add(block)
    } else {
      block()
    }
  }

  private fun flushPending() {
    while (pending.isNotEmpty()) {
      pending.removeFirst().invoke()
    }
  }

  fun applyInitialCamera(camera: ReadableMap?) {
    if (didApplyInitialCamera || camera == null || !camera.hasKey("latitude") || !camera.hasKey("longitude")) {
      return
    }

    didApplyInitialCamera = true
    flyTo(
      camera.getDouble("latitude"),
      camera.getDouble("longitude"),
      if (camera.hasKey("zoom")) camera.getDouble("zoom") else 16.0,
      if (camera.hasKey("tilt")) camera.getDouble("tilt") else 0.0,
      if (camera.hasKey("bearing")) camera.getDouble("bearing") else 0.0,
      0
    )
  }

  fun setMarkers(array: ReadableArray?) {
    val next = parseArray(array, ::parseMarker).associateBy { it.id }
    withMap {
      diff(markerSpecs, next, markers, ::addMarker)
      markerSpecs = next
    }
  }

  fun setPolylines(array: ReadableArray?) {
    val next = parseArray(array, ::parsePolyline).associateBy { it.id }
    withMap {
      diff(polylineSpecs, next, polylines, ::addPolyline)
      polylineSpecs = next
    }
  }

  fun setPolygons(array: ReadableArray?) {
    val next = parseArray(array, ::parsePolygon).associateBy { it.id }
    withMap {
      diff(polygonSpecs, next, polygons, ::addPolygon)
      polygonSpecs = next
    }
  }

  fun setCircles(array: ReadableArray?) {
    val next = parseArray(array, ::parseCircle).associateBy { it.id }
    withMap {
      diff(circleSpecs, next, circles, ::addCircle)
      circleSpecs = next
    }
  }

  private fun <S, O : SimpleMapObject> diff(
    current: KotlinMap<String, S>,
    next: KotlinMap<String, S>,
    objects: MutableMap<String, O>,
    add: (S) -> O?
  ) {
    val manager = objectManager ?: return

    current.keys.filter { it !in next }.forEach { id ->
      objects.remove(id)?.let(manager::removeObject)
    }

    next.forEach { (id, spec) ->
      if (current[id] != spec) {
        objects.remove(id)?.let(manager::removeObject)
        add(spec)?.let { objects[id] = it }
      }
    }
  }

  private fun addMarker(spec: DgisMarkerSpec): Marker? {
    val manager = objectManager ?: return null
    // 2GIS does not render a default pin when `icon = null` — the marker is
    // silently invisible. Fall back to a built-in dot so consumers who omit
    // `iconSource` still see something on the map.
    val icon = decodeMarkerIcon(spec) ?: defaultMarkerIcon()

    val marker = Marker(
      MarkerOptions(
        position = geoPointWithElevation(spec.latitude, spec.longitude),
        icon = icon,
        anchor = Anchor(spec.anchorX, spec.anchorY),
        iconWidth = LogicalPixel(spec.iconWidth),
        userData = spec.id,
        zIndex = ZIndex(spec.zIndex),
        animatedAppearance = true
      )
    )

    manager.addObject(marker)
    return marker
  }

  private fun defaultMarkerIcon(): Image {
    cachedDefaultMarkerIcon?.let { return it }
    val bitmap = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    paint.color = 0xFFFFFFFF.toInt()
    canvas.drawCircle(32f, 32f, 30f, paint)
    paint.color = 0xFF1E88E5.toInt()
    canvas.drawCircle(32f, 32f, 26f, paint)
    val icon = imageFromBitmap(DGisSdkHolder.requireContext(), bitmap)
    cachedDefaultMarkerIcon = icon
    return icon
  }

  private fun addPolyline(spec: DgisPolylineSpec): Polyline? {
    val manager = objectManager ?: return null
    val dashed = if (spec.dashLength > 0f && spec.dashSpace > 0f) {
      DashedPolylineOptions(LogicalPixel(spec.dashLength), LogicalPixel(spec.dashSpace))
    } else {
      null
    }

    val polyline = Polyline(
      PolylineOptions(
        points = spec.points,
        width = LogicalPixel(spec.width),
        color = Color(spec.color),
        dashedPolylineOptions = dashed,
        userData = spec.id,
        zIndex = ZIndex(spec.zIndex)
      )
    )

    manager.addObject(polyline)
    return polyline
  }

  private fun addPolygon(spec: DgisPolygonSpec): Polygon? {
    val manager = objectManager ?: return null
    val polygon = Polygon(
      PolygonOptions(
        contours = listOf(spec.points),
        color = Color(spec.fillColor),
        strokeWidth = LogicalPixel(spec.strokeWidth),
        strokeColor = Color(spec.strokeColor),
        userData = spec.id,
        zIndex = ZIndex(spec.zIndex)
      )
    )

    manager.addObject(polygon)
    return polygon
  }

  private fun addCircle(spec: DgisCircleSpec): Circle? {
    val manager = objectManager ?: return null
    val circle = Circle(
      CircleOptions(
        position = geoPoint(spec.latitude, spec.longitude),
        radius = Meter(spec.radiusMeters),
        color = Color(spec.fillColor),
        strokeWidth = LogicalPixel(spec.strokeWidth),
        strokeColor = Color(spec.strokeColor),
        userData = spec.id,
        zIndex = ZIndex(spec.zIndex)
      )
    )

    manager.addObject(circle)
    return circle
  }

  fun updateClustering(enabled: Boolean? = null, radius: Float? = null, color: Int? = null, textColor: Int? = null) {
    val nextEnabled = enabled ?: clusteringEnabled
    val nextRadius = radius ?: clusteringRadius
    val nextColor = color ?: clusterColor
    val nextTextColor = textColor ?: clusterTextColor

    if (
      nextEnabled == clusteringEnabled &&
      nextRadius == clusteringRadius &&
      nextColor == clusterColor &&
      nextTextColor == clusterTextColor
    ) {
      return
    }

    clusteringEnabled = nextEnabled
    clusteringRadius = nextRadius
    clusterColor = nextColor
    clusterTextColor = nextTextColor

    withMap {
      recreateObjectManager()
    }
  }

  private fun recreateObjectManager() {
    val readyMap = map ?: return
    // Close the previous manager fully — `removeAll()` alone leaves it
    // attached to the map, and a fresh `MapObjectManager.withClustering(...)`
    // ends up stacking ghost managers on the same map.
    objectManager?.let { manager ->
      runCatching { manager.removeAll() }
        .onFailure { android.util.Log.w("DgisMapsView", "removeAll failed", it) }
      runCatching { manager.close() }
        .onFailure { android.util.Log.w("DgisMapsView", "close failed", it) }
    }

    // `layerId` must be null — passing a custom string ("dgis-clusters") binds
    // the manager to a style layer of that name, and if the basemap style does
    // not declare such a Dynamic-Object layer, every added object silently
    // never paints. The default `null` puts objects on top of the basemap.
    objectManager = if (clusteringEnabled) {
      MapObjectManager.withClustering(
        readyMap,
        LogicalPixel(clusteringRadius),
        Zoom(18f),
        ClusterRenderer(clusterColor, clusterTextColor),
        Zoom(1f),
        null
      )
    } else {
      MapObjectManager(readyMap, null)
    }

    markers.clear()
    polylines.clear()
    polygons.clear()
    circles.clear()

    markerSpecs.values.forEach { spec -> addMarker(spec)?.let { markers[spec.id] = it } }
    polylineSpecs.values.forEach { spec -> addPolyline(spec)?.let { polylines[spec.id] = it } }
    polygonSpecs.values.forEach { spec -> addPolygon(spec)?.let { polygons[spec.id] = it } }
    circleSpecs.values.forEach { spec -> addCircle(spec)?.let { circles[spec.id] = it } }
  }

  fun setShowsUserLocation(enabled: Boolean) {
    withMap {
      val readyMap = map ?: return@withMap

      if (enabled) {
        if (locationSource != null) {
          return@withMap
        }

        val source = MyLocationMapObjectSource(
          context = DGisSdkHolder.requireContext(),
          controllerSettings = MyLocationControllerSettings(),
          markerType = MyLocationMapObjectMarkerType.MODEL
        )
        readyMap.addSource(source)
        locationSource = source
        locationModel = MyLocationControlModel(readyMap)
      } else {
        locationSource?.let { readyMap.removeSource(it) }
        locationSource = null
        locationModel = null
      }
    }
  }

  fun setGestures(scrollEnabled: Boolean, zoomEnabled: Boolean, rotateEnabled: Boolean, tiltEnabled: Boolean) {
    // TODO: 13.2 API missing: MapView exposes GestureManager, but exact per-gesture mutable flags need validation.
  }

  fun flyTo(lat: Double, lng: Double, zoom: Double, tilt: Double, bearing: Double, durationMs: Int) {
    withMap {
      val readyMap = map ?: return@withMap
      val position = CameraPosition(
        point = geoPoint(lat, lng),
        zoom = Zoom(zoom.toFloat()),
        tilt = Tilt(tilt.toFloat()),
        bearing = Bearing(bearing)
      )
      readyMap.camera.move(position, Duration.ofMilliseconds(durationMs.toLong()), CameraAnimationType.DEFAULT)
    }
  }

  fun centerOnUserLocation(durationMs: Int) {
    setShowsUserLocation(true)
    withMap {
      locationModel?.onClicked()
    }
  }

  override fun onDetachedFromWindow() {
    val view = mapView
    val callback = objectTapCallback

    if (view != null) {
      view.setTouchEventsObserver(null)
      if (callback != null) {
        view.removeObjectTappedCallback(callback)
      }
    }

    // Both calls — `removeAll()` empties the manager, `close()` detaches it
    // from the map. Without the second one the SDK keeps the manager bound
    // and a fresh re-attach (after RN remounts the view) would silently
    // stack ghost managers on the same map.
    objectManager?.let { manager ->
      runCatching { manager.removeAll() }
        .onFailure { android.util.Log.w("DgisMapsView", "removeAll on detach failed", it) }
      runCatching { manager.close() }
        .onFailure { android.util.Log.w("DgisMapsView", "close on detach failed", it) }
    }

    lifecycle?.let { currentLifecycle ->
      view?.let(currentLifecycle::removeObserver)
    }

    removeAllViews()
    objectTapCallback = null
    mapView = null
    map = null
    objectManager = null
    lifecycle = null

    super.onDetachedFromWindow()
  }

  private fun decodeMarkerIcon(spec: DgisMarkerSpec): Image? {
    // base64 wins when both are given (explicit override).
    spec.iconBase64?.takeIf { it.isNotBlank() }?.let { base64 ->
      runCatching {
        val bytes = Base64.decode(base64, Base64.DEFAULT)
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        if (bitmap != null) {
          return imageFromBitmap(DGisSdkHolder.requireContext(), bitmap)
        }
      }
    }

    spec.iconUri?.takeIf { it.isNotBlank() }?.let { uri ->
      runCatching {
        val bitmap = loadBitmapFromUri(uri)
        if (bitmap != null) {
          return imageFromBitmap(DGisSdkHolder.requireContext(), bitmap)
        }
      }
    }

    return null
  }

  // Synchronous URI loader for marker icons. Marker mutation already happens
  // off the UI thread when fed from JS so the network/disk fetch here is fine.
  // Sources covered: http(s) (Metro packager + arbitrary CDN), file:// (prod
  // bundle), and content:// (Android asset/content provider).
  private fun loadBitmapFromUri(uri: String): Bitmap? = runCatching {
    when {
      uri.startsWith("http://") || uri.startsWith("https://") -> {
        val connection = java.net.URL(uri).openConnection() as java.net.HttpURLConnection
        connection.connectTimeout = 5000
        connection.readTimeout = 5000
        connection.inputStream.use { BitmapFactory.decodeStream(it) }
      }
      uri.startsWith("file://") || uri.startsWith("/") -> {
        val path = if (uri.startsWith("file://")) uri.removePrefix("file://") else uri
        BitmapFactory.decodeFile(path)
      }
      uri.startsWith("content://") -> {
        context.contentResolver.openInputStream(android.net.Uri.parse(uri))?.use {
          BitmapFactory.decodeStream(it)
        }
      }
      else -> null
    }
  }.getOrNull()

  private fun <T> parseArray(array: ReadableArray?, parser: (ReadableMap) -> T?): List<T> {
    if (array == null) {
      return emptyList()
    }

    val items = mutableListOf<T>()
    for (i in 0 until array.size()) {
      array.getMap(i)?.let(parser)?.let(items::add)
    }
    return items
  }

  private fun parseMarker(map: ReadableMap): DgisMarkerSpec? {
    if (!map.hasKey("id") || !map.hasKey("latitude") || !map.hasKey("longitude")) {
      return null
    }

    return DgisMarkerSpec(
      id = map.getString("id") ?: return null,
      latitude = map.getDouble("latitude"),
      longitude = map.getDouble("longitude"),
      iconBase64 = if (map.hasKey("iconBase64")) map.getString("iconBase64") else null,
      iconUri = if (map.hasKey("iconUri")) map.getString("iconUri") else null,
      iconWidth = if (map.hasKey("iconWidth")) map.getDouble("iconWidth").toFloat() else 32f,
      anchorX = if (map.hasKey("anchorX")) map.getDouble("anchorX").toFloat() else 0.5f,
      anchorY = if (map.hasKey("anchorY")) map.getDouble("anchorY").toFloat() else 1f,
      zIndex = if (map.hasKey("zIndex")) map.getInt("zIndex") else 0
    )
  }

  private fun parsePolyline(map: ReadableMap): DgisPolylineSpec? {
    return DgisPolylineSpec(
      id = map.getString("id") ?: return null,
      points = parsePoints(if (map.hasKey("points")) map.getArray("points") else null),
      color = if (map.hasKey("color")) map.getInt("color") else 0xff007aff.toInt(),
      width = if (map.hasKey("width")) map.getDouble("width").toFloat() else 4f,
      dashLength = if (map.hasKey("dashLength")) map.getDouble("dashLength").toFloat() else 0f,
      dashSpace = if (map.hasKey("dashSpace")) map.getDouble("dashSpace").toFloat() else 0f,
      zIndex = if (map.hasKey("zIndex")) map.getInt("zIndex") else 0
    )
  }

  private fun parsePolygon(map: ReadableMap): DgisPolygonSpec? {
    return DgisPolygonSpec(
      id = map.getString("id") ?: return null,
      points = parsePoints(if (map.hasKey("points")) map.getArray("points") else null),
      fillColor = if (map.hasKey("fillColor")) map.getInt("fillColor") else 0x33007aff,
      strokeColor = if (map.hasKey("strokeColor")) map.getInt("strokeColor") else 0xff007aff.toInt(),
      strokeWidth = if (map.hasKey("strokeWidth")) map.getDouble("strokeWidth").toFloat() else 2f,
      zIndex = if (map.hasKey("zIndex")) map.getInt("zIndex") else 0
    )
  }

  private fun parseCircle(map: ReadableMap): DgisCircleSpec? {
    if (!map.hasKey("id") || !map.hasKey("latitude") || !map.hasKey("longitude") || !map.hasKey("radiusMeters")) {
      return null
    }

    return DgisCircleSpec(
      id = map.getString("id") ?: return null,
      latitude = map.getDouble("latitude"),
      longitude = map.getDouble("longitude"),
      radiusMeters = map.getDouble("radiusMeters").toFloat(),
      fillColor = if (map.hasKey("fillColor")) map.getInt("fillColor") else 0x33007aff,
      strokeColor = if (map.hasKey("strokeColor")) map.getInt("strokeColor") else 0xff007aff.toInt(),
      strokeWidth = if (map.hasKey("strokeWidth")) map.getDouble("strokeWidth").toFloat() else 2f,
      zIndex = if (map.hasKey("zIndex")) map.getInt("zIndex") else 0
    )
  }

  private fun parsePoints(array: ReadableArray?): List<GeoPoint> {
    if (array == null) {
      return emptyList()
    }

    val points = mutableListOf<GeoPoint>()
    for (i in 0 until array.size()) {
      val point = array.getMap(i) ?: continue
      if (point.hasKey("latitude") && point.hasKey("longitude")) {
        points.add(geoPoint(point.getDouble("latitude"), point.getDouble("longitude")))
      }
    }
    return points
  }

  private fun geoPoint(latitude: Double, longitude: Double): GeoPoint {
    return GeoPoint(Latitude(latitude), Longitude(longitude))
  }

  private fun geoPointWithElevation(latitude: Double, longitude: Double): GeoPointWithElevation {
    return GeoPointWithElevation(Latitude(latitude), Longitude(longitude))
  }

  private inner class ClusterRenderer(
    private val fill: Int,
    private val text: Int
  ) : SimpleClusterRenderer {
    // Single background icon reused for every cluster — the count is drawn by
    // the SDK as a text overlay via `SimpleClusterOptions.textStyle`, so the
    // bitmap is just the colored circle. Drawing the count into the bitmap as
    // well caused a visible double-render of the digits.
    private val backgroundIcon: Image by lazy {
      imageFromBitmap(DGisSdkHolder.requireContext(), makeClusterBackground())
    }

    override fun renderCluster(cluster: SimpleClusterObject): SimpleClusterOptions {
      val count = cluster.objectCount
      return SimpleClusterOptions(
        icon = backgroundIcon,
        anchor = Anchor(0.5f, 0.5f),
        text = count.toString(),
        textStyle = TextStyle(
          fontSize = LogicalPixel(15f),
          color = Color(text),
          textPlacement = TextPlacement.CENTER_CENTER
        ),
        iconWidth = LogicalPixel(44f),
        userData = count.toString(),
        zIndex = ZIndex(10),
        animatedAppearance = false
      )
    }

    private fun makeClusterBackground(): Bitmap {
      val bitmap = Bitmap.createBitmap(88, 88, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bitmap)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG)
      paint.color = fill
      canvas.drawCircle(44f, 44f, 44f, paint)
      return bitmap
    }
  }
}
