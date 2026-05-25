import CoreLocation
import DGis
import Foundation
import UIKit

public typealias DgisMapsViewEventCallback = (_ eventName: NSString, _ body: NSDictionary) -> Void

private func dgisLogicalPixel(_ value: Float) -> LogicalPixel {
  LogicalPixel(value: max(0, value))
}

private func dgisZoom(_ value: Float) -> Zoom {
  Zoom(value: value)
}

private func dgisZIndex(_ value: Int32) -> ZIndex {
  ZIndex(value: UInt32(bitPattern: value))
}

private func dgisGeoPoint(latitude: Double, longitude: Double) -> GeoPoint {
  GeoPoint(latitude: Latitude(value: latitude), longitude: Longitude(value: longitude))
}

private func dgisGeoPointWithElevation(latitude: Double, longitude: Double) -> GeoPointWithElevation {
  GeoPointWithElevation(latitude: Latitude(value: latitude), longitude: Longitude(value: longitude))
}

private struct MarkerSpec: Equatable {
  let id: String
  let latitude: Double
  let longitude: Double
  let iconBase64: String?
  let iconWidth: Float
  let anchorX: Float
  let anchorY: Float
  let zIndex: Int32

  init?(_ raw: NSDictionary) {
    guard
      let id = raw["id"] as? String,
      let latitude = raw["latitude"] as? NSNumber,
      let longitude = raw["longitude"] as? NSNumber
    else {
      return nil
    }

    self.id = id
    self.latitude = latitude.doubleValue
    self.longitude = longitude.doubleValue
    self.iconBase64 = raw["iconBase64"] as? String
    self.iconWidth = (raw["iconWidth"] as? NSNumber)?.floatValue ?? 32
    self.anchorX = (raw["anchorX"] as? NSNumber)?.floatValue ?? 0.5
    self.anchorY = (raw["anchorY"] as? NSNumber)?.floatValue ?? 1
    self.zIndex = (raw["zIndex"] as? NSNumber)?.int32Value ?? 0
  }
}

private struct PolylineSpec: Equatable {
  let id: String
  let points: [[String: Double]]
  let color: UInt32
  let width: Float
  let dashLength: Float
  let dashSpace: Float
  let zIndex: Int32

  init?(_ raw: NSDictionary) {
    guard let id = raw["id"] as? String, let rawPoints = raw["points"] as? [NSDictionary] else {
      return nil
    }

    self.id = id
    self.points = rawPoints.compactMap { item in
      guard let lat = item["latitude"] as? NSNumber, let lng = item["longitude"] as? NSNumber else {
        return nil
      }
      return ["latitude": lat.doubleValue, "longitude": lng.doubleValue]
    }
    self.color = UInt32(bitPattern: (raw["color"] as? NSNumber)?.int32Value ?? Int32(bitPattern: 0xff007aff))
    self.width = (raw["width"] as? NSNumber)?.floatValue ?? 4
    self.dashLength = (raw["dashLength"] as? NSNumber)?.floatValue ?? 0
    self.dashSpace = (raw["dashSpace"] as? NSNumber)?.floatValue ?? 0
    self.zIndex = (raw["zIndex"] as? NSNumber)?.int32Value ?? 0
  }
}

private struct PolygonSpec: Equatable {
  let id: String
  let points: [[String: Double]]
  let fillColor: UInt32
  let strokeColor: UInt32
  let strokeWidth: Float
  let zIndex: Int32

  init?(_ raw: NSDictionary) {
    guard let id = raw["id"] as? String, let rawPoints = raw["points"] as? [NSDictionary] else {
      return nil
    }

    self.id = id
    self.points = rawPoints.compactMap { item in
      guard let lat = item["latitude"] as? NSNumber, let lng = item["longitude"] as? NSNumber else {
        return nil
      }
      return ["latitude": lat.doubleValue, "longitude": lng.doubleValue]
    }
    self.fillColor = UInt32(bitPattern: (raw["fillColor"] as? NSNumber)?.int32Value ?? Int32(bitPattern: 0x33007aff))
    self.strokeColor = UInt32(bitPattern: (raw["strokeColor"] as? NSNumber)?.int32Value ?? Int32(bitPattern: 0xff007aff))
    self.strokeWidth = (raw["strokeWidth"] as? NSNumber)?.floatValue ?? 2
    self.zIndex = (raw["zIndex"] as? NSNumber)?.int32Value ?? 0
  }
}

private struct CircleSpec: Equatable {
  let id: String
  let latitude: Double
  let longitude: Double
  let radiusMeters: Float
  let fillColor: UInt32
  let strokeColor: UInt32
  let strokeWidth: Float
  let zIndex: Int32

  init?(_ raw: NSDictionary) {
    guard
      let id = raw["id"] as? String,
      let latitude = raw["latitude"] as? NSNumber,
      let longitude = raw["longitude"] as? NSNumber,
      let radiusMeters = raw["radiusMeters"] as? NSNumber
    else {
      return nil
    }

    self.id = id
    self.latitude = latitude.doubleValue
    self.longitude = longitude.doubleValue
    self.radiusMeters = radiusMeters.floatValue
    self.fillColor = UInt32(bitPattern: (raw["fillColor"] as? NSNumber)?.int32Value ?? Int32(bitPattern: 0x33007aff))
    self.strokeColor = UInt32(bitPattern: (raw["strokeColor"] as? NSNumber)?.int32Value ?? Int32(bitPattern: 0xff007aff))
    self.strokeWidth = (raw["strokeWidth"] as? NSNumber)?.floatValue ?? 2
    self.zIndex = (raw["zIndex"] as? NSNumber)?.int32Value ?? 0
  }
}

private final class DgisClusterRenderer: SimpleClusterRenderer {
  private let sdk: DGis.Container
  private let fillColor: UInt
  private let textColor: UInt
  private var cache: [UInt: Image] = [:]

  init(sdk: DGis.Container, fillColor: UInt32, textColor: UInt32) {
    self.sdk = sdk
    self.fillColor = UInt(fillColor)
    self.textColor = UInt(textColor)
  }

  func renderCluster(cluster: SimpleClusterObject) -> SimpleClusterOptions {
    let count = UInt(cluster.objectCount)
    let image = cache[count] ?? makeImage(count: count)
    if let image {
      cache[count] = image
    }

    return SimpleClusterOptions(
      icon: image,
      iconMapDirection: nil,
      text: String(count),
      textStyle: nil,
      iconWidth: dgisLogicalPixel(44),
      userData: Int(count),
      zIndex: dgisZIndex(10),
      animatedAppearance: false
    )
  }

  private func makeImage(count: UInt) -> Image? {
    let size = CGSize(width: 44, height: 44)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    defer { UIGraphicsEndImageContext() }

    UIColor(argb: UInt32(fillColor)).setFill()
    UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
      .font: UIFont.boldSystemFont(ofSize: 15),
      .foregroundColor: UIColor(argb: UInt32(textColor)),
      .paragraphStyle: paragraph
    ]
    String(count).draw(in: CGRect(x: 0, y: 12, width: size.width, height: 20), withAttributes: attrs)

    guard let uiImage = UIGraphicsGetImageFromCurrentImageContext() else {
      return nil
    }

    return try? sdk.imageFactory.make(image: uiImage)
  }
}

private extension UIColor {
  convenience init(argb: UInt32) {
    let a = CGFloat((argb >> 24) & 0xff) / 255
    let r = CGFloat((argb >> 16) & 0xff) / 255
    let g = CGFloat((argb >> 8) & 0xff) / 255
    let b = CGFloat(argb & 0xff) / 255
    self.init(red: r, green: g, blue: b, alpha: a)
  }
}

@objc(DgisMapsViewImpl)
public final class DgisMapsViewImpl: UIView {
  @objc public var eventCallback: DgisMapsViewEventCallback?

  private var sdk: DGis.Container?
  private var mapFactory: IMapFactory?
  private var map: DGis.Map?
  private var mapUIView: (UIView & IMapUIView)?
  private var objectManager: MapObjectManager?
  private var locationSource: MyLocationMapObjectSource?
  private var locationModel: MyLocationControlModel?
  private var objectTapCallback: MapObjectTappedCallback?
  private var dataLoadingCancellable: ICancellable = NoopCancellable()
  private var followCancellable: ICancellable = NoopCancellable()

  private var markerSpecs: [String: MarkerSpec] = [:]
  private var polylineSpecs: [String: PolylineSpec] = [:]
  private var polygonSpecs: [String: PolygonSpec] = [:]
  private var circleSpecs: [String: CircleSpec] = [:]
  private var markers: [String: Marker] = [:]
  private var polylines: [String: Polyline] = [:]
  private var polygons: [String: Polygon] = [:]
  private var circles: [String: Circle] = [:]

  private var clusteringEnabled = false
  private var clusteringRadius: Float = 80
  private var clusterColor: UInt32 = 0xff007aff
  private var clusterTextColor: UInt32 = 0xffffffff
  private var didApplyInitialCamera = false
  private let locationManager = CLLocationManager()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor(white: 0.94, alpha: 1)
    createMapIfPossible()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = UIColor(white: 0.94, alpha: 1)
    createMapIfPossible()
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    mapUIView?.frame = bounds
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      createMapIfPossible()
    }
  }

  deinit {
    cleanup()
  }

  @objc public func refreshInitializationState() {
    createMapIfPossible()
  }

  private func createMapIfPossible() {
    guard mapFactory == nil else {
      return
    }

    guard let sdk = DGisSdkHolder.shared.sdkOrNil() else {
      showOverlay("2GIS SDK is not initialized")
      return
    }

    do {
      clearOverlay()
      var options = try MapOptions.default
      options.devicePPI = .autodetected

      let factory = try sdk.makeMapFactory(options: options)
      let view = factory.mapUIView
      view.frame = bounds
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      addSubview(view)

      self.sdk = sdk
      self.mapFactory = factory
      self.mapUIView = view
      self.map = factory.map

      recreateObjectManager()
      bindEvents()
      eventCallback?("onMapReady", [:])
    } catch {
      showOverlay(error.localizedDescription)
    }
  }

  private func bindEvents() {
    guard let map, let mapUIView else {
      return
    }

    dataLoadingCancellable = map.dataLoadingStateChannel.sinkOnMainThread { [weak self] state in
      if String(describing: state).lowercased().contains("loaded") {
        self?.eventCallback?("onMapReady", [:])
      }
    }

    objectTapCallback = MapObjectTappedCallback { [weak self] info in
      guard let marker = info.item.item as? Marker, let id = marker.userData as? String else {
        return
      }

      self?.eventCallback?("onMarkerPress", [
        "id": id,
        "latitude": marker.position.latitude.value,
        "longitude": marker.position.longitude.value
      ])
    }

    if let objectTapCallback {
      mapUIView.addObjectTappedCallback(callback: objectTapCallback)
    }

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    mapUIView.addGestureRecognizer(tap)
  }

  @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard recognizer.state == .ended, let map else {
      return
    }

    let point = recognizer.location(in: self)
    guard let geo = map.camera.projection.screenToMap(point: ScreenPoint(x: Float(point.x), y: Float(point.y))) else {
      return
    }

    eventCallback?("onMapTap", [
      "latitude": geo.latitude.value,
      "longitude": geo.longitude.value,
      "x": point.x,
      "y": point.y
    ])
  }

  private func recreateObjectManager() {
    guard let map, let sdk else {
      return
    }

    objectManager?.removeAll()

    if clusteringEnabled {
      objectManager = MapObjectManager.withClustering(
        map: map,
        logicalPixel: dgisLogicalPixel(clusteringRadius),
        maxZoom: dgisZoom(18),
        clusterRenderer: DgisClusterRenderer(sdk: sdk, fillColor: clusterColor, textColor: clusterTextColor),
        minZoom: dgisZoom(1)
      )
    } else {
      objectManager = MapObjectManager(map: map)
    }

    let currentMarkers = markerSpecs.values
    let currentPolylines = polylineSpecs.values
    let currentPolygons = polygonSpecs.values
    let currentCircles = circleSpecs.values

    markers.removeAll()
    polylines.removeAll()
    polygons.removeAll()
    circles.removeAll()

    currentMarkers.forEach { addMarker($0) }
    currentPolylines.forEach { addPolyline($0) }
    currentPolygons.forEach { addPolygon($0) }
    currentCircles.forEach { addCircle($0) }
  }

  @objc public func setClusteringEnabled(_ enabled: Bool, radius: NSNumber?, clusterColor: NSNumber?, clusterTextColor: NSNumber?) {
    let nextRadius = radius?.floatValue ?? clusteringRadius
    let nextClusterColor = UInt32(bitPattern: clusterColor?.int32Value ?? Int32(bitPattern: self.clusterColor))
    let nextTextColor = UInt32(bitPattern: clusterTextColor?.int32Value ?? Int32(bitPattern: self.clusterTextColor))

    guard enabled != clusteringEnabled || nextRadius != clusteringRadius || nextClusterColor != self.clusterColor || nextTextColor != self.clusterTextColor else {
      return
    }

    clusteringEnabled = enabled
    clusteringRadius = nextRadius
    self.clusterColor = nextClusterColor
    self.clusterTextColor = nextTextColor
    recreateObjectManager()
  }

  @objc public func applyInitialCamera(_ camera: NSDictionary?) {
    guard !didApplyInitialCamera, let camera else {
      return
    }

    guard
      let latitude = camera["latitude"] as? NSNumber,
      let longitude = camera["longitude"] as? NSNumber
    else {
      return
    }

    didApplyInitialCamera = true
    flyTo(
      latitude,
      lng: longitude,
      zoom: camera["zoom"] as? NSNumber ?? 16,
      tilt: camera["tilt"] as? NSNumber ?? 0,
      bearing: camera["bearing"] as? NSNumber ?? 0,
      duration: 0
    )
  }

  @objc public func setMarkers(_ rawMarkers: NSArray?) {
    let next = Dictionary(uniqueKeysWithValues: (rawMarkers as? [NSDictionary] ?? []).compactMap(MarkerSpec.init).map { ($0.id, $0) })
    diff(currentSpecs: &markerSpecs, currentObjects: &markers, nextSpecs: next, add: addMarker)
  }

  @objc public func setPolylines(_ rawPolylines: NSArray?) {
    let next = Dictionary(uniqueKeysWithValues: (rawPolylines as? [NSDictionary] ?? []).compactMap(PolylineSpec.init).map { ($0.id, $0) })
    diff(currentSpecs: &polylineSpecs, currentObjects: &polylines, nextSpecs: next, add: addPolyline)
  }

  @objc public func setPolygons(_ rawPolygons: NSArray?) {
    let next = Dictionary(uniqueKeysWithValues: (rawPolygons as? [NSDictionary] ?? []).compactMap(PolygonSpec.init).map { ($0.id, $0) })
    diff(currentSpecs: &polygonSpecs, currentObjects: &polygons, nextSpecs: next, add: addPolygon)
  }

  @objc public func setCircles(_ rawCircles: NSArray?) {
    let next = Dictionary(uniqueKeysWithValues: (rawCircles as? [NSDictionary] ?? []).compactMap(CircleSpec.init).map { ($0.id, $0) })
    diff(currentSpecs: &circleSpecs, currentObjects: &circles, nextSpecs: next, add: addCircle)
  }

  private func diff<Spec: Equatable, Object: SimpleMapObject>(
    currentSpecs: inout [String: Spec],
    currentObjects: inout [String: Object],
    nextSpecs: [String: Spec],
    add: (Spec) -> Void
  ) {
    guard let objectManager else {
      currentSpecs = nextSpecs
      return
    }

    for id in currentSpecs.keys where nextSpecs[id] == nil {
      if let object = currentObjects[id] {
        objectManager.removeObject(item: object)
      }
      currentObjects.removeValue(forKey: id)
    }

    for (id, spec) in nextSpecs where currentSpecs[id] != spec {
      if let object = currentObjects[id] {
        objectManager.removeObject(item: object)
        currentObjects.removeValue(forKey: id)
      }
      add(spec)
    }

    currentSpecs = nextSpecs
  }

  private func addMarker(_ spec: MarkerSpec) {
    guard let objectManager, let sdk else {
      return
    }

    do {
      let icon: Image? = try spec.iconBase64.flatMap { base64 in
        guard let data = Data(base64Encoded: base64), let image = UIImage(data: data) else {
          return nil
        }
        return try sdk.imageFactory.make(image: image)
      }

      let marker = try Marker(options: MarkerOptions(
        position: dgisGeoPointWithElevation(latitude: spec.latitude, longitude: spec.longitude),
        icon: icon,
        anchor: Anchor(x: spec.anchorX, y: spec.anchorY),
        iconWidth: dgisLogicalPixel(spec.iconWidth),
        userData: spec.id,
        zIndex: dgisZIndex(spec.zIndex)
      ))
      objectManager.addObject(item: marker)
      markers[spec.id] = marker
    } catch {
      eventCallback?("onMapError", ["message": error.localizedDescription])
    }
  }

  private func addPolyline(_ spec: PolylineSpec) {
    guard let objectManager else {
      return
    }

    do {
      let points = spec.points.map { dgisGeoPoint(latitude: $0["latitude"] ?? 0, longitude: $0["longitude"] ?? 0) }
      let dashed = spec.dashLength > 0 && spec.dashSpace > 0
        ? DashedPolylineOptions(dashLength: dgisLogicalPixel(spec.dashLength), dashSpaceLength: dgisLogicalPixel(spec.dashSpace))
        : nil
      let polyline = try Polyline(options: PolylineOptions(
        points: points,
        width: dgisLogicalPixel(spec.width),
        color: Color(argb: spec.color),
        dashedPolylineOptions: dashed,
        userData: spec.id,
        zIndex: dgisZIndex(spec.zIndex)
      ))
      objectManager.addObject(item: polyline)
      polylines[spec.id] = polyline
    } catch {
      eventCallback?("onMapError", ["message": error.localizedDescription])
    }
  }

  private func addPolygon(_ spec: PolygonSpec) {
    guard let objectManager else {
      return
    }

    do {
      let points = spec.points.map { dgisGeoPoint(latitude: $0["latitude"] ?? 0, longitude: $0["longitude"] ?? 0) }
      let polygon = try Polygon(options: PolygonOptions(
        contours: [points],
        color: Color(argb: spec.fillColor),
        strokeWidth: dgisLogicalPixel(spec.strokeWidth),
        strokeColor: Color(argb: spec.strokeColor),
        userData: spec.id,
        zIndex: dgisZIndex(spec.zIndex)
      ))
      objectManager.addObject(item: polygon)
      polygons[spec.id] = polygon
    } catch {
      eventCallback?("onMapError", ["message": error.localizedDescription])
    }
  }

  private func addCircle(_ spec: CircleSpec) {
    guard let objectManager else {
      return
    }

    do {
      let circle = try Circle(options: CircleOptions(
        position: dgisGeoPoint(latitude: spec.latitude, longitude: spec.longitude),
        radius: Meter(value: spec.radiusMeters),
        color: Color(argb: spec.fillColor),
        strokeWidth: dgisLogicalPixel(spec.strokeWidth),
        strokeColor: Color(argb: spec.strokeColor),
        userData: spec.id,
        zIndex: dgisZIndex(spec.zIndex)
      ))
      objectManager.addObject(item: circle)
      circles[spec.id] = circle
    } catch {
      eventCallback?("onMapError", ["message": error.localizedDescription])
    }
  }

  @objc public func setShowsUserLocation(_ enabled: Bool) {
    guard let map, let sdk else {
      return
    }

    do {
      if enabled {
        guard locationSource == nil else {
          return
        }

        let source = MyLocationMapObjectSource(
          context: try sdk.context,
          controllerSettings: MyLocationControllerSettings(),
          markerType: .model
        )
        map.addSource(source: source)
        locationSource = source
        locationModel = MyLocationControlModel(map: map)

        if let locationModel {
          followCancellable = locationModel.followStateChannel.sinkOnMainThread { _ in }
        }
      } else if let source = locationSource {
        map.removeSource(source: source)
        locationSource = nil
        locationModel = nil
        followCancellable = NoopCancellable()
      }
    } catch {
      eventCallback?("onMapError", ["message": error.localizedDescription])
    }
  }

  @objc public func setGestures(scrollEnabled: Bool, zoomEnabled: Bool, rotateEnabled: Bool, tiltEnabled: Bool) {
    // TODO: 13.2 API missing: wire gesture toggles through IMapFactory.mapGestureManager after validating exact mutable settings names.
  }

  @objc public func flyTo(_ lat: NSNumber, lng: NSNumber, zoom: NSNumber, tilt: NSNumber, bearing: NSNumber, duration: NSNumber) {
    guard let map else {
      return
    }

    let position = CameraPosition(
      point: dgisGeoPoint(latitude: lat.doubleValue, longitude: lng.doubleValue),
      zoom: Zoom(value: zoom.floatValue),
      tilt: Tilt(value: tilt.floatValue),
      bearing: Bearing(value: bearing.doubleValue)
    )

    _ = map.camera.move(
      position: position,
      time: TimeInterval(max(0, duration.doubleValue / 1000.0)),
      animationType: .default
    )
  }

  @objc public func centerOnUserLocation(_ duration: NSNumber) {
    if locationModel == nil {
      setShowsUserLocation(true)
    }

    locationModel?.onClicked()
  }

  private func cleanup() {
    dataLoadingCancellable = NoopCancellable()
    followCancellable = NoopCancellable()

    if let callback = objectTapCallback {
      mapUIView?.removeObjectTappedCallback(callback: callback)
    }

    objectTapCallback = nil
    objectManager?.removeAll()
    mapUIView?.removeFromSuperview()
    mapUIView = nil
    map = nil
    mapFactory = nil
  }

  private func showOverlay(_ message: String) {
    clearOverlay()
    let label = UILabel()
    label.tag = 0xD615
    label.text = message
    label.textAlignment = .center
    label.numberOfLines = 0
    label.textColor = .darkGray
    label.font = .systemFont(ofSize: 13)
    label.frame = bounds
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(label)
  }

  private func clearOverlay() {
    viewWithTag(0xD615)?.removeFromSuperview()
  }
}
