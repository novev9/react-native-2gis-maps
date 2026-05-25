import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

export type Camera = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  zoom?: CodegenTypes.Float;
  tilt?: CodegenTypes.Float;
  bearing?: CodegenTypes.Float;
}>;

export type Marker = Readonly<{
  id: string;
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  iconBase64?: string;
  // Resolved by the JS facade via Image.resolveAssetSource — http(s) for the
  // packager / CDN, file:// for prod-packaged assets. Native side loads the
  // bytes when iconBase64 is missing.
  iconUri?: string;
  iconWidth?: CodegenTypes.Float;
  anchorX?: CodegenTypes.Float;
  anchorY?: CodegenTypes.Float;
  zIndex?: CodegenTypes.Int32;
}>;

export type Polyline = Readonly<{
  id: string;
  points: ReadonlyArray<
    Readonly<{ latitude: CodegenTypes.Double; longitude: CodegenTypes.Double }>
  >;
  color?: CodegenTypes.Int32;
  width?: CodegenTypes.Float;
  dashLength?: CodegenTypes.Float;
  dashSpace?: CodegenTypes.Float;
  zIndex?: CodegenTypes.Int32;
}>;

export type Polygon = Readonly<{
  id: string;
  points: ReadonlyArray<
    Readonly<{ latitude: CodegenTypes.Double; longitude: CodegenTypes.Double }>
  >;
  fillColor?: CodegenTypes.Int32;
  strokeColor?: CodegenTypes.Int32;
  strokeWidth?: CodegenTypes.Float;
  zIndex?: CodegenTypes.Int32;
}>;

export type Circle = Readonly<{
  id: string;
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  radiusMeters: CodegenTypes.Float;
  fillColor?: CodegenTypes.Int32;
  strokeColor?: CodegenTypes.Int32;
  strokeWidth?: CodegenTypes.Float;
  zIndex?: CodegenTypes.Int32;
}>;

export type OnMapReadyEvent = Readonly<{}>;

export type OnMapTapEvent = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  x: CodegenTypes.Float;
  y: CodegenTypes.Float;
}>;

export type OnMarkerPressEvent = Readonly<{
  id: string;
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
}>;

export type OnCameraChangedEvent = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  zoom: CodegenTypes.Float;
  tilt: CodegenTypes.Float;
  bearing: CodegenTypes.Float;
  state: string;
}>;

export type OnUserLocationChangedEvent = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  accuracy: CodegenTypes.Float;
}>;

interface NativeProps extends ViewProps {
  apiKey?: string;
  initialCamera?: Camera;
  markers?: ReadonlyArray<Marker>;
  polylines?: ReadonlyArray<Polyline>;
  polygons?: ReadonlyArray<Polygon>;
  circles?: ReadonlyArray<Circle>;
  showsUserLocation?: CodegenTypes.WithDefault<boolean, false>;
  clusteringEnabled?: CodegenTypes.WithDefault<boolean, false>;
  clusteringRadius?: CodegenTypes.WithDefault<CodegenTypes.Float, 80>;
  clusterColor?: CodegenTypes.Int32;
  clusterTextColor?: CodegenTypes.Int32;
  scrollEnabled?: CodegenTypes.WithDefault<boolean, true>;
  zoomEnabled?: CodegenTypes.WithDefault<boolean, true>;
  rotateEnabled?: CodegenTypes.WithDefault<boolean, true>;
  tiltEnabled?: CodegenTypes.WithDefault<boolean, true>;

  onMapReady?: CodegenTypes.DirectEventHandler<OnMapReadyEvent>;
  onMapTap?: CodegenTypes.DirectEventHandler<OnMapTapEvent>;
  onMarkerPress?: CodegenTypes.DirectEventHandler<OnMarkerPressEvent>;
  onCameraChanged?: CodegenTypes.DirectEventHandler<OnCameraChangedEvent>;
  onUserLocationChanged?: CodegenTypes.DirectEventHandler<OnUserLocationChangedEvent>;
}

export default codegenNativeComponent<NativeProps>(
  'DgisMapsView'
) as HostComponent<NativeProps>;
