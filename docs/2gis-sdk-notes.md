# 2GIS Mobile SDK Native Binding Notes

Research date: 2026-05-25. Sources: official Android/iOS docs, API reference, and demo repos.

## Sources

- Android overview, requirements, and install: https://docs.2gis.com/en/android/sdk/overview
- Android getting started / key / init: https://docs.2gis.com/en/android/sdk/start
- Android map examples: https://docs.2gis.com/en/android/sdk/examples/map
- iOS overview, requirements: https://docs.2gis.com/en/ios/sdk/overview
- iOS getting started / key / init: https://docs.2gis.com/en/ios/sdk/start
- iOS map examples: https://docs.2gis.com/en/ios/sdk/examples/map
- Android demo repo: https://github.com/2gis/mobile-sdk-android-demo
- iOS demo repo: https://github.com/2gis/mobile-sdk-ios-demo

Notes from docs:
- Android SDK packages: `sdk-map` and `sdk-full`; do not include both.
- iOS SDK packages: Map and Full; do not include both.
- Current Android docs require Android 6.0+, supported ABIs `x86_64`, `x86`, `armeabi-v7a`, `arm64-v8a`, OpenGL ES 3.1.
- Current iOS overview says Xcode 14 and iOS/iPadOS 16+, but the public 13.4.0 Map podspec declares `spec.platform = :ios, "12.0"`. The demo README is older and says iOS 13+. For a new RN Fabric library, set the podspec minimum to `16.0` unless you intentionally pin/test an older 2GIS SDK version.

## 1. SDK Initialization

### Android

Packages:
```kotlin
import ru.dgis.sdk.DGis
import ru.dgis.sdk.Context as DGisContext
import ru.dgis.sdk.LogOptions
import ru.dgis.sdk.LogLevel
import ru.dgis.sdk.HttpOptions
import ru.dgis.sdk.PersonalDataCollectionConsent
```

Key file:
- Put `dgissdk.key` in Android app assets: `android/app/src/main/assets/dgissdk.key`.
- Demo repo also requires app `applicationId` to match `app_id` inside the key for older/key-bound SDKs.

Initialization:
```kotlin
class MainApplication : Application() {
    lateinit var sdkContext: DGisContext

    override fun onCreate() {
        super.onCreate()

        sdkContext = DGis.initialize(
            appContext = this,
            dataCollectConsent = PersonalDataCollectionConsent.GRANTED,
            logOptions = LogOptions(LogLevel.VERBOSE),
            httpOptions = HttpOptions(useCache = true)
        )
    }
}
```

Important:
- `DGis.initialize(...)` creates SDK `Context`.
- The SDK context must be created as a single instance.
- Changing `dgissdk.key` while app is running is unsupported.
- Repository:
```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://artifactory.2gis.dev/sdk-maven-release")
        }
    }
}
```

Dependency:
```kotlin
dependencies {
    implementation("ru.dgis.sdk:sdk-map:latest.release")
    // or:
    implementation("ru.dgis.sdk:sdk-full:latest.release")
}
```

The docs show the Artifactory URL without credentials, so treat it as public unless 2GIS changes access policy.

### iOS

Module:
```swift
import DGis
```

Key file:
- Add `dgissdk.key` to the app bundle root.
- Demo repo says to add `dgissdk.key` to the application root and set Bundle Identifier to `app_id` from the key for key-bound SDKs.

Initialization:
```swift
final class DGisSdkHolder {
    static let shared = DGisSdkHolder()

    let sdk: DGis.Container

    private init() {
        let key = KeySource.fromAsset(KeyFromAsset(path: "dgissdk.key"))

        sdk = DGis.Container(
            keySource: key,
            logOptions: LogOptions(systemLevel: .info),
            httpOptions: HTTPOptions(),
            personalDataCollectionOptions: PersonalDataCollectionOptions(
                personalDataCollectionConsent: .granted
            )
        )
    }
}
```

Alternative key sources:
```swift
let keyFromBundlePath = Bundle.main.path(forResource: "dgissdk", ofType: "key").map {
    KeySource.fromFile(KeyFromFile(path: $0))
}

let keyFromString = KeySource.fromString(KeyFromString(contents: keyFileContents))
```

Important:
- iOS equivalent of `DGis.initialize` is `DGis.Container(...)`.
- `DGis.Container` should be single-instance and retained.
- `sdk.context` is the `Context` passed into map object sources.

## 2. Programmatic MapView and Lifecycle

### Android

Packages:
```kotlin
import ru.dgis.sdk.map.MapView
import ru.dgis.sdk.map.MapOptions
import ru.dgis.sdk.map.CameraPosition
import ru.dgis.sdk.map.Zoom
import ru.dgis.sdk.geometry.GeoPoint
```

Programmatic creation:
```kotlin
val options = MapOptions(
    position = CameraPosition(
        point = GeoPoint(latitude = 55.752425, longitude = 37.613983),
        zoom = Zoom(16.0)
    )
)

val mapView = MapView(context, options)
parentViewGroup.addView(
    mapView,
    ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
    )
)

mapView.getMapAsync { map ->
    // Store map for commands from JS.
}
```

Lifecycle:
```kotlin
// If you have a LifecycleOwner:
lifecycleOwner.lifecycle.addObserver(mapView)
```

`MapView` API includes:
```kotlin
MapView(context: android.content.Context)
MapView(context: android.content.Context, attrs: AttributeSet)
MapView(context: android.content.Context, options: MapOptions)
MapView(context: android.content.Context, map: Map)

fun getMapAsync(callback: OnMapReadyCallback): Unit
fun onStart(owner: LifecycleOwner): Unit
fun onStop(owner: LifecycleOwner): Unit
fun onConfigurationChanged(newConfig: Configuration): Unit
fun onSaveInstanceState(): Parcelable?
fun onRestoreInstanceState(state: Parcelable?): Unit
fun setTouchEventsObserver(observer: TouchEventsObserver?): Unit
```

RN/Fabric guidance:
- On attach: create `MapView`, add to native view, call `getMapAsync`.
- If current `Activity` is a `LifecycleOwner`, register `mapView`.
- On detach/drop: remove lifecycle observer, close all SDK channel connections, set touch observer to `null`, remove child view.
- Public `MapView` lifecycle is `onStart/onStop` via lifecycle observer; docs do not expose `onResume/onPause/onDestroy` methods.

### iOS

Programmatic UIKit:
```swift
import UIKit
import DGis

final class RN2GisMapNativeView: UIView {
    private let sdk = DGisSdkHolder.shared.sdk
    private var mapFactory: IMapFactory?
    private var map: DGis.Map?
    private var mapUIView: (UIView & IMapUIView)?
    private var loadingCancellable: ICancellable = NoopCancellable()

    override init(frame: CGRect) {
        super.init(frame: frame)
        createMap()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createMap()
    }

    private func createMap() {
        do {
            var options = MapOptions.default
            options.devicePPI = .autodetected

            let factory = try sdk.makeMapFactory(options: options)
            let view = factory.mapUIView

            view.frame = bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            addSubview(view)

            self.mapFactory = factory
            self.mapUIView = view
            self.map = factory.map

            self.loadingCancellable = factory.map.dataLoadingStateChannel.sinkOnMainThread { state in
                if state == .loaded {
                    // Map is ready.
                }
            }
        } catch {
            // Forward native init error to JS.
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapUIView?.frame = bounds
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            loadingCancellable = NoopCancellable()
            mapUIView?.removeFromSuperview()
            mapUIView = nil
            map = nil
            mapFactory = nil
        }
    }
}
```

Important:
- `DGis.Container` must be retained.
- `IMapFactory` and `mapUIView` must be retained for as long as the RN view is alive.
- iOS docs do not require explicit `viewWillAppear/viewWillDisappear` calls into the SDK. The RN side should clean up cancellables/callbacks and release map view references in `willMove(toWindow: nil)` / `deinit`.

## 3. Markers, Custom Icons, Anchor

### Android

Packages:
```kotlin
import ru.dgis.sdk.map.MapObjectManager
import ru.dgis.sdk.map.Marker
import ru.dgis.sdk.map.MarkerOptions
import ru.dgis.sdk.map.Anchor
import ru.dgis.sdk.map.LogicalPixel
import ru.dgis.sdk.map.Opacity
import ru.dgis.sdk.map.imageFromBitmap
import ru.dgis.sdk.map.imageFromResource
import ru.dgis.sdk.geometry.GeoPointWithElevation
```

Create manager:
```kotlin
private lateinit var objectManager: MapObjectManager

mapView.getMapAsync { map ->
    objectManager = MapObjectManager(map)
}
```

Add marker:
```kotlin
val marker = Marker(
    MarkerOptions(
        position = GeoPointWithElevation(
            latitude = 55.752425,
            longitude = 37.613983
        ),
        icon = imageFromResource(sdkContext, R.drawable.ic_marker),
        anchor = Anchor(x = 0.5f, y = 1.0f),
        iconWidth = LogicalPixel(32.0f),
        iconOpacity = Opacity(1.0f),
        draggable = false,
        userData = jsMarkerId
    )
)

objectManager.addObject(marker)
```

Custom icon from `Bitmap`:
```kotlin
val bitmap: Bitmap = makeMarkerBitmap(...)
val icon = imageFromBitmap(sdkContext, bitmap)

marker.icon = icon
marker.anchor = Anchor(0.5f, 1.0f)
```

Useful mutable properties:
```kotlin
marker.position = GeoPointWithElevation(latitude, longitude)
marker.icon = icon
marker.anchor = Anchor(0.5f, 1.0f)
marker.iconOpacity = Opacity(0.75f)
marker.text = "Label"
marker.draggable = true
marker.iconWidth = LogicalPixel(32.0f)
```

Approximate public constructor shape:
```kotlin
MarkerOptions(
    position: GeoPointWithElevation,
    icon: Image? = null,
    iconMapDirection: MapDirection? = null,
    anchor: Anchor = Anchor(0.5f, 0.5f),
    text: String = "",
    textStyle: TextStyle = TextStyle(),
    iconOpacity: Opacity = Opacity(1.0f),
    visible: Boolean = true,
    draggable: Boolean = false,
    iconWidth: LogicalPixel = LogicalPixel(0.0f),
    userData: Any? = null,
    zIndex: ZIndex = ZIndex(0),
    animatedAppearance: Boolean = true,
    levelId: LevelId? = null,
    iconAnimationMode: AnimationMode = AnimationMode.NORMAL
)
```

### iOS

Packages:
```swift
import DGis
import UIKit
```

Manager:
```swift
private var objectManager: MapObjectManager?

objectManager = MapObjectManager(map: map)
```

Add marker:
```swift
let uiImage = UIImage(named: "pin")!
let icon = sdk.imageFactory.make(image: uiImage)

let options = MarkerOptions(
    position: GeoPointWithElevation(
        latitude: 55.752425,
        longitude: 37.613983
    ),
    icon: icon,
    anchor: Anchor(x: 0.5, y: 1.0),
    iconWidth: LogicalPixel(value: 32),
    userData: jsMarkerId
)

let marker = try Marker(options: options)
objectManager?.addObject(object: marker)
```

Faster icon from PNG data:
```swift
let icon = sdk.imageFactory.make(pngData: pngData, size: CGSize(width: 32, height: 32))
```

Marker options signature:
```swift
public init(
    position: GeoPointWithElevation,
    icon: Image?,
    iconMapDirection: MapDirection? = nil,
    anchor: Anchor = Anchor(x: 0.5, y: 0.5),
    text: String? = nil,
    textStyle: TextStyle? = nil,
    iconOpacity: Opacity = Opacity(value: 1),
    visible: Bool = true,
    draggable: Bool = false,
    iconWidth: LogicalPixel = LogicalPixel(value: 0),
    userData: Any = (),
    zIndex: ZIndex = ZIndex(value: 0),
    animatedAppearance: Bool = true,
    levelId: LevelId? = nil,
    iconAnimationMode: AnimationMode = AnimationMode.normal
)
```

Mutable properties:
```swift
marker.position = GeoPointWithElevation(latitude: 59.93428, longitude: 30.33510)
marker.icon = newIcon
marker.anchor = Anchor(x: 0.5, y: 1.0)
marker.iconOpacity = Opacity(value: 1.0)
marker.text = "New text"
marker.isDraggable = true
marker.iconWidth = LogicalPixel(value: 32)
marker.iconMapDirection = MapDirection(value: 10)
marker.animatedAppearance = true
```

## 4. Clustering

The public docs expose clustering through `MapObjectManager.withClustering(...)` on both platforms. If you see older/internal references to `GenericMapObjectManager`, prefer the public `MapObjectManager.withClustering` API for this binding.

### Android

Packages:
```kotlin
import ru.dgis.sdk.map.MapObjectManager
import ru.dgis.sdk.map.SimpleClusterRenderer
import ru.dgis.sdk.map.SimpleClusterObject
import ru.dgis.sdk.map.SimpleClusterOptions
import ru.dgis.sdk.map.TextStyle
import ru.dgis.sdk.map.TextPlacement
import ru.dgis.sdk.map.LogicalPixel
import ru.dgis.sdk.map.Zoom
```

Cluster renderer:
```kotlin
val clusterRenderer = object : SimpleClusterRenderer {
    override fun renderCluster(cluster: SimpleClusterObject): SimpleClusterOptions {
        val count = cluster.objectCount
        val bitmap = makeClusterBitmap(count) // draw circle + count text
        val icon = imageFromBitmap(sdkContext, bitmap)

        return SimpleClusterOptions(
            icon = icon,
            iconWidth = LogicalPixel(44.0f),
            text = count.toString(),
            textStyle = TextStyle(
                fontSize = LogicalPixel(15.0f),
                textPlacement = TextPlacement.CENTER
            ),
            userData = count.toString()
        )
    }
}

objectManager = MapObjectManager.withClustering(
    map = map,
    logicalPixel = LogicalPixel(80.0f),
    maxZoom = Zoom(18.0f),
    minZoom = Zoom(8.0f),
    clusterRenderer = clusterRenderer
)
```

Add markers normally:
```kotlin
objectManager.addObject(marker)
objectManager.addObjects(markers)
```

Where to plug count icon logic:
- Inside `SimpleClusterRenderer.renderCluster(cluster)`.
- Generate/cache `Bitmap` by `cluster.objectCount`; convert with `imageFromBitmap`.

### iOS

Renderer:
```swift
final class ClusterRenderer: SimpleClusterRenderer {
    private let sdk: DGis.Container

    init(sdk: DGis.Container) {
        self.sdk = sdk
    }

    func renderCluster(cluster: SimpleClusterObject) -> SimpleClusterOptions {
        let count = cluster.objectCount
        let image = makeClusterUIImage(count: Int(count))
        let icon = sdk.imageFactory.make(image: image)

        return SimpleClusterOptions(
            icon: icon,
            iconMapDirection: nil,
            text: String(count),
            textStyle: TextStyle(
                fontSize: LogicalPixel(value: 15),
                textPlacement: .center
            ),
            iconWidth: LogicalPixel(value: 44),
            userData: Int(count),
            zIndex: ZIndex(value: 6),
            animatedAppearance: false
        )
    }
}

objectManager = MapObjectManager.withClustering(
    map: map,
    logicalPixel: LogicalPixel(value: 80),
    maxZoom: Zoom(value: 18),
    minZoom: Zoom(value: 8),
    clusterRenderer: ClusterRenderer(sdk: sdk)
)
```

Where to plug count icon logic:
- Inside `SimpleClusterRenderer.renderCluster(cluster:)`.
- Generate/cache `UIImage` by `cluster.objectCount`; convert with `sdk.imageFactory.make(image:)`.

## 5. Polyline, Polygon, Circle

### Android

Packages:
```kotlin
import ru.dgis.sdk.map.Polyline
import ru.dgis.sdk.map.PolylineOptions
import ru.dgis.sdk.map.Polygon
import ru.dgis.sdk.map.PolygonOptions
import ru.dgis.sdk.map.Circle
import ru.dgis.sdk.map.CircleOptions
import ru.dgis.sdk.map.DashedPolylineOptions
import ru.dgis.sdk.map.DashedStrokeCircleOptions
import ru.dgis.sdk.map.LogicalPixel
import ru.dgis.sdk.map.Color
import ru.dgis.sdk.geometry.GeoPoint
import ru.dgis.sdk.geometry.Meter
```

Color:
```kotlin
val red = Color(argb = 0xFFFF0000.toInt())
val fill = Color(argb = 0x3300AAFF)
```

Polyline:
```kotlin
val polyline = Polyline(
    PolylineOptions(
        points = listOf(
            GeoPoint(latitude = 55.7513, longitude = 37.6236),
            GeoPoint(latitude = 55.7405, longitude = 37.6235)
        ),
        width = LogicalPixel(4.0f),
        color = Color(argb = 0xFF007AFF.toInt()),
        dashedPolylineOptions = DashedPolylineOptions(
            dashLength = LogicalPixel(8.0f),
            dashSpaceLength = LogicalPixel(4.0f)
        ),
        userData = "route-1"
    )
)
objectManager.addObject(polyline)
```

`PolylineOptions` shape:
```kotlin
PolylineOptions(
    points: List<GeoPoint>,
    width: LogicalPixel = LogicalPixel(1.0f),
    color: Color = Color(),
    erasedPart: Double = 0.0,
    dashedPolylineOptions: DashedPolylineOptions? = null,
    gradientPolylineOptions: GradientPolylineOptions? = null,
    visible: Boolean = true,
    userData: Any? = null,
    zIndex: ZIndex = ZIndex(0),
    levelId: LevelId? = null
)
```

Polygon:
```kotlin
val polygon = Polygon(
    PolygonOptions(
        contours = listOf(
            listOf(
                GeoPoint(55.75, 37.61),
                GeoPoint(55.76, 37.62),
                GeoPoint(55.75, 37.63)
            )
        ),
        color = Color(argb = 0x3300AAFF),
        strokeWidth = LogicalPixel(2.0f),
        strokeColor = Color(argb = 0xFF007AFF.toInt()),
        userData = "polygon-1"
    )
)
objectManager.addObject(polygon)
```

`PolygonOptions` shape:
```kotlin
PolygonOptions(
    contours: List<List<GeoPoint>>,
    color: Color = Color(),
    strokeWidth: LogicalPixel = LogicalPixel(0.0f),
    strokeColor: Color = Color(),
    visible: Boolean = true,
    userData: Any? = null,
    zIndex: ZIndex = ZIndex(0),
    levelId: LevelId? = null
)
```

Circle:
```kotlin
val circle = Circle(
    CircleOptions(
        position = GeoPoint(latitude = 55.754167897761, longitude = 37.62422561645508),
        radius = Meter(100.0f),
        color = Color(argb = 0x3300AAFF),
        strokeWidth = LogicalPixel(2.0f),
        strokeColor = Color(argb = 0xFF007AFF.toInt()),
        dashedStrokeOptions = DashedStrokeCircleOptions(
            dashLength = LogicalPixel(8.0f),
            dashSpaceLength = LogicalPixel(4.0f)
        )
    )
)
objectManager.addObject(circle)
```

`CircleOptions` shape:
```kotlin
CircleOptions(
    position: GeoPoint,
    radius: Meter,
    color: Color = Color(),
    strokeWidth: LogicalPixel = LogicalPixel(0.0f),
    strokeColor: Color = Color(),
    dashedStrokeOptions: DashedStrokeCircleOptions? = null,
    visible: Boolean = true,
    userData: Any? = null,
    zIndex: ZIndex = ZIndex(0),
    levelId: LevelId? = null
)
```

### iOS

Polyline:
```swift
let polyline = try Polyline(
    options: PolylineOptions(
        points: [
            GeoPoint(latitude: 55.7513, longitude: 37.6236),
            GeoPoint(latitude: 55.7405, longitude: 37.6235)
        ],
        width: LogicalPixel(value: 4),
        color: Color(argb: 0xFF007AFF),
        dashedPolylineOptions: DashedPolylineOptions(
            dashLength: LogicalPixel(value: 8),
            dashSpaceLength: LogicalPixel(value: 4)
        ),
        userData: "route-1"
    )
)
objectManager?.addObject(object: polyline)
```

Polygon:
```swift
let polygon = try Polygon(
    options: PolygonOptions(
        contours: [[
            GeoPoint(latitude: 55.75, longitude: 37.61),
            GeoPoint(latitude: 55.76, longitude: 37.62),
            GeoPoint(latitude: 55.75, longitude: 37.63)
        ]],
        color: Color(argb: 0x3300AAFF),
        strokeWidth: LogicalPixel(value: 2),
        strokeColor: Color(argb: 0xFF007AFF),
        userData: "polygon-1"
    )
)
objectManager?.addObject(object: polygon)
```

Circle:
```swift
let circle = try Circle(
    options: CircleOptions(
        position: GeoPoint(latitude: 55.754, longitude: 37.624),
        radius: Meter(value: 100),
        color: Color(argb: 0x3300AAFF),
        strokeWidth: LogicalPixel(value: 2),
        strokeColor: Color(argb: 0xFF007AFF),
        dashedStrokeOptions: DashedStrokeCircleOptions(
            dashLength: LogicalPixel(value: 8),
            dashSpaceLength: LogicalPixel(value: 4)
        )
    )
)
objectManager?.addObject(object: circle)
```

## 6. User Location

### Android

Manifest:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Runtime permission must be requested by the host app or RN module before location is expected to work.

Source:
```kotlin
import ru.dgis.sdk.map.MyLocationMapObjectSource
import ru.dgis.sdk.map.MyLocationControllerSettings
import ru.dgis.sdk.map.MyLocationMapObjectMarkerType
import ru.dgis.sdk.map.MyLocationControlModel

val source = MyLocationMapObjectSource(
    context = sdkContext,
    controllerSettings = MyLocationControllerSettings(),
    markerType = MyLocationMapObjectMarkerType.MODEL
)

map.addSource(source)
```

Self-location / tracking button model:
```kotlin
val myLocationModel = MyLocationControlModel(map)

// Invoke from JS command, e.g. `centerOnUserLocation()`.
myLocationModel.onClicked()

val followConnection = myLocationModel.followStateChannel.connect { state ->
    // Forward follow state to JS if needed.
}
```

### iOS

Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Allow location to show your position on the map.</string>
```

Permission:
```swift
import CoreLocation

private let locationManager = CLLocationManager()

func requestLocationPermission() {
    locationManager.requestWhenInUseAuthorization()
}
```

Source:
```swift
let source = MyLocationMapObjectSource(
    context: sdk.context,
    controllerSettings: MyLocationControllerSettings(),
    markerType: .model
)

map.addSource(source: source)
```

Self-location:
```swift
let model = MyLocationControlModel(map: map)

// Invoke from JS command.
model.onClicked()

let cancellable = model.followStateChannel.sinkOnMainThread { state in
    // Forward follow state to JS if needed.
}
```

## 7. Camera Move / FlyTo

### Android

Packages:
```kotlin
import ru.dgis.sdk.map.CameraPosition
import ru.dgis.sdk.map.CameraAnimationType
import ru.dgis.sdk.map.Zoom
import ru.dgis.sdk.map.Tilt
import ru.dgis.sdk.geometry.GeoPoint
import ru.dgis.sdk.geometry.Arcdegree
import ru.dgis.sdk.Duration
```

Move:
```kotlin
val position = CameraPosition(
    point = GeoPoint(latitude = 55.752425, longitude = 37.613983),
    zoom = Zoom(16.0),
    tilt = Tilt(25.0),
    bearing = Arcdegree(85.0)
)

map.camera
    .move(position, Duration.ofSeconds(2), CameraAnimationType.DEFAULT)
    .onResult {
        // Forward onCameraMoveFinished if needed.
    }
```

Use:
- Instant/no animation: duration `0` or direct position API.
- Smooth fly-to: `Duration.ofMilliseconds(300..1000)` for small moves, `1.5s..2s` for larger moves.
- `CameraAnimationType.DEFAULT` chooses based on distance.
- `CameraAnimationType.LINEAR` changes camera parameters linearly.
- `CameraAnimationType.SHOW_BOTH_POSITIONS` can zoom out to show start/end during flight.

### iOS

Signatures:
```swift
public func move(
    position: CameraPosition,
    time: TimeInterval = 0.3,
    animationType: CameraAnimationType = .default
) -> Future<CameraAnimatedMoveResult>
```

Move:
```swift
let position = CameraPosition(
    point: GeoPoint(latitude: 55.752425, longitude: 37.613983),
    zoom: Zoom(value: 16),
    tilt: Tilt(value: 25),
    bearing: Bearing(value: 85)
)

map.camera.move(
    position: position,
    time: 1.0,
    animationType: .default
)
```

Animation types:
```swift
CameraAnimationType.default
CameraAnimationType.linear
CameraAnimationType.showBothPositions
```

## 8. Map Tap Event Subscription

### Android

For raw map taps:
```kotlin
import ru.dgis.sdk.map.TouchEventsObserver
import ru.dgis.sdk.map.ScreenPoint

mapView.setTouchEventsObserver(object : TouchEventsObserver {
    override fun onTap(point: ScreenPoint) {
        map.getRenderedObjects(point).onResult { rendered ->
            // rendered: List<RenderedObjectInfo>
        }
        // Forward onMapTap to JS with screen x/y.
    }
    override fun onLongTouch(point: ScreenPoint) {}
    override fun onDragBegin(data: DragBeginData) {}
    override fun onDragMove(point: ScreenPoint) {}
    override fun onDragEnd() {}
})
```

For object taps:
```kotlin
fun onObjectTapped(info: RenderedObjectInfo) {
    val userData = info.item.item.userData
    // Forward onMarkerPress/onObjectPress to JS.
}

mapView.addObjectTappedCallback(::onObjectTapped)
mapView.addObjectLongTouchCallback(::onObjectTapped)
```

### iOS

For object taps:
```swift
private var objectTapCallback: MapObjectTappedCallback?

objectTapCallback = MapObjectTappedCallback { [weak self] objectInfo in
    let userData = objectInfo.item.item.userData
    // Forward onMarkerPress/onObjectPress to JS.
}

if let callback = objectTapCallback {
    mapUIView.addObjectTappedCallback(callback: callback)
    mapUIView.addObjectLongPressCallback(callback: callback)
}
```

Remove on cleanup:
```swift
if let callback = objectTapCallback {
    mapUIView?.removeObjectTappedCallback(callback: callback)
    mapUIView?.removeLongPressCallback(callback: callback)
}
objectTapCallback = nil
```

For plain background map taps:
- Add a UIKit gesture recognizer to an overlay/gesture view and forward touch point. If needed, query `map.getRenderedObjects(...)` using the touch point to distinguish empty map vs object.

## 9. iOS Package / Podspec

SwiftPM URLs:
```ruby
# Full SDK
https://github.com/2gis/mobile-sdk-full-swift-package

# Map SDK
https://github.com/2gis/mobile-sdk-map-swift-package
```

CocoaPods:
```ruby
Pod::Spec.new do |s|
  s.name = "YourRN2GisMaps"
  s.platform = :ios, "16.0"
  s.dependency "DGisMobileSDK", "13.4.0-map"
end
```

Version suffix convention:
- `13.4.0-map` for Map SDK.
- `13.4.0-full` for Full SDK.

## 10. Android Gradle / Requirements

Minimum:
```kotlin
android {
    defaultConfig {
        minSdk = 23 // Android 6.0
    }
}
```

Repository:
```kotlin
maven {
    url = uri("https://artifactory.2gis.dev/sdk-maven-release")
}
```

Dependencies:
```kotlin
implementation("ru.dgis.sdk:sdk-map:latest.release")
// or
implementation("ru.dgis.sdk:sdk-full:latest.release")
```

Key:
```text
android/app/src/main/assets/dgissdk.key
```

Auth:
- Official docs and demo README use `https://artifactory.2gis.dev/sdk-maven-release` without credentials.
- Treat it as public Maven access.

## Fabric/TurboModule Binding Shape

Suggested native view state:
```kotlin
// Android
class RN2GisMapView(context: Context) : FrameLayout(context) {
    private val mapView: MapView
    private var map: ru.dgis.sdk.map.Map? = null
    private var objectManager: MapObjectManager? = null
    private val markers = mutableMapOf<String, Marker>()
    private val polylines = mutableMapOf<String, Polyline>()
    private val polygons = mutableMapOf<String, Polygon>()
    private val circles = mutableMapOf<String, Circle>()
    private var myLocationSource: MyLocationMapObjectSource? = null
}
```

```swift
// iOS
final class RN2GisMapNativeView: UIView {
    private let sdk = DGisSdkHolder.shared.sdk
    private var mapFactory: IMapFactory?
    private var mapUIView: (UIView & IMapUIView)?
    private var map: DGis.Map?
    private var objectManager: MapObjectManager?
    private var markers: [String: Marker] = [:]
    private var polylines: [String: Polyline] = [:]
    private var polygons: [String: Polygon] = [:]
    private var circles: [String: Circle] = [:]
    private var myLocationSource: MyLocationMapObjectSource?
    private var cancellables: [ICancellable] = []
}
```

Commands to expose:
- `moveCamera({ latitude, longitude, zoom, tilt, bearing, durationMs, animation })`
- `setMarkers(markers)`
- `addMarker(marker)`
- `removeMarker(id)`
- `setPolylines(polylines)`
- `setPolygons(polygons)`
- `setCircles(circles)`
- `setClusteringEnabled(enabled, radius, minZoom, maxZoom)`
- `setShowsUserLocation(enabled)`
- `requestLocationPermission()` or document host responsibility
- `centerOnUserLocation()`
- Events: `onMapReady`, `onMapTap`, `onObjectTap`, `onCameraIdle`, `onUserLocationFollowStateChange`
