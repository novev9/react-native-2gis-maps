import {
  forwardRef,
  useImperativeHandle,
  useRef,
  type ForwardedRef,
} from 'react';
import {
  findNodeHandle,
  type NativeSyntheticEvent,
  PermissionsAndroid,
  Platform,
  processColor,
  type ViewProps,
} from 'react-native';
import NativeDgisMapsModule from './NativeDgisMapsModule';
import DgisMapsViewNativeComponent, {
  type Camera,
  type Circle,
  type Marker,
  type OnCameraChangedEvent,
  type OnMapReadyEvent,
  type OnMapTapEvent,
  type OnMarkerPressEvent,
  type OnUserLocationChangedEvent,
  type Polygon,
  type Polyline,
} from './DgisMapsViewNativeComponent';

export type ColorLike = string | number;

export type DGisMarkerInput = {
  id: string;
  latitude: number;
  longitude: number;
  iconBase64?: string;
  iconWidth?: number;
  anchorX?: number;
  anchorY?: number;
  zIndex?: number;
};

export type DGisPolylineInput = {
  id: string;
  points: Array<{ latitude: number; longitude: number }>;
  color?: ColorLike;
  width?: number;
  dashLength?: number;
  dashSpace?: number;
  zIndex?: number;
};

export type DGisPolygonInput = {
  id: string;
  points: Array<{ latitude: number; longitude: number }>;
  fillColor?: ColorLike;
  strokeColor?: ColorLike;
  strokeWidth?: number;
  zIndex?: number;
};

export type DGisCircleInput = {
  id: string;
  latitude: number;
  longitude: number;
  radiusMeters: number;
  fillColor?: ColorLike;
  strokeColor?: ColorLike;
  strokeWidth?: number;
  zIndex?: number;
};

export type DGisFlyToOptions = {
  latitude: number;
  longitude: number;
  zoom?: number;
  tilt?: number;
  bearing?: number;
  durationMs?: number;
};

export type DGisMapHandle = {
  flyTo(options: DGisFlyToOptions): Promise<boolean>;
  centerOnUserLocation(durationMs?: number): Promise<boolean>;
};

export type DGisMapProps = ViewProps & {
  apiKey?: string;
  initialCamera?: Camera;
  markers?: ReadonlyArray<DGisMarkerInput>;
  polylines?: ReadonlyArray<DGisPolylineInput>;
  polygons?: ReadonlyArray<DGisPolygonInput>;
  circles?: ReadonlyArray<DGisCircleInput>;
  showsUserLocation?: boolean;
  clusteringEnabled?: boolean;
  clusteringRadius?: number;
  clusterColor?: ColorLike;
  clusterTextColor?: ColorLike;
  scrollEnabled?: boolean;
  zoomEnabled?: boolean;
  rotateEnabled?: boolean;
  tiltEnabled?: boolean;
  onMapReady?: (event: NativeSyntheticEvent<OnMapReadyEvent>) => void;
  onMapTap?: (event: NativeSyntheticEvent<OnMapTapEvent>) => void;
  onMarkerPress?: (event: NativeSyntheticEvent<OnMarkerPressEvent>) => void;
  onCameraChanged?: (event: NativeSyntheticEvent<OnCameraChangedEvent>) => void;
  onUserLocationChanged?: (
    event: NativeSyntheticEvent<OnUserLocationChangedEvent>
  ) => void;
};

function toArgb(color: ColorLike | undefined): number | undefined {
  if (color === undefined || color === null) {
    return undefined;
  }
  if (typeof color === 'number') {
    return color;
  }
  const processed = processColor(color);
  if (typeof processed === 'number') {
    return processed;
  }
  return undefined;
}

function mapMarkers(
  markers: ReadonlyArray<DGisMarkerInput> | undefined
): ReadonlyArray<Marker> | undefined {
  if (!markers) return undefined;
  return markers.map((m) => ({
    id: m.id,
    latitude: m.latitude,
    longitude: m.longitude,
    iconBase64: m.iconBase64,
    iconWidth: m.iconWidth,
    anchorX: m.anchorX,
    anchorY: m.anchorY,
    zIndex: m.zIndex,
  }));
}

function mapPolylines(
  polylines: ReadonlyArray<DGisPolylineInput> | undefined
): ReadonlyArray<Polyline> | undefined {
  if (!polylines) return undefined;
  return polylines.map((p) => ({
    id: p.id,
    points: p.points,
    color: toArgb(p.color),
    width: p.width,
    dashLength: p.dashLength,
    dashSpace: p.dashSpace,
    zIndex: p.zIndex,
  }));
}

function mapPolygons(
  polygons: ReadonlyArray<DGisPolygonInput> | undefined
): ReadonlyArray<Polygon> | undefined {
  if (!polygons) return undefined;
  return polygons.map((p) => ({
    id: p.id,
    points: p.points,
    fillColor: toArgb(p.fillColor),
    strokeColor: toArgb(p.strokeColor),
    strokeWidth: p.strokeWidth,
    zIndex: p.zIndex,
  }));
}

function mapCircles(
  circles: ReadonlyArray<DGisCircleInput> | undefined
): ReadonlyArray<Circle> | undefined {
  if (!circles) return undefined;
  return circles.map((c) => ({
    id: c.id,
    latitude: c.latitude,
    longitude: c.longitude,
    radiusMeters: c.radiusMeters,
    fillColor: toArgb(c.fillColor),
    strokeColor: toArgb(c.strokeColor),
    strokeWidth: c.strokeWidth,
    zIndex: c.zIndex,
  }));
}

function DGisMapImpl(
  props: DGisMapProps,
  ref: ForwardedRef<DGisMapHandle>
): React.ReactElement {
  const {
    markers,
    polylines,
    polygons,
    circles,
    clusterColor,
    clusterTextColor,
    ...rest
  } = props;
  const viewRef = useRef<React.ComponentRef<
    typeof DgisMapsViewNativeComponent
  > | null>(null);

  useImperativeHandle(
    ref,
    () => ({
      async flyTo(options: DGisFlyToOptions) {
        const tag = findNodeHandle(viewRef.current);
        if (tag == null) return false;
        return NativeDgisMapsModule.flyTo(
          tag,
          options.latitude,
          options.longitude,
          options.zoom ?? -1,
          options.tilt ?? -1,
          options.bearing ?? -1,
          options.durationMs ?? 500
        );
      },
      async centerOnUserLocation(durationMs?: number) {
        const tag = findNodeHandle(viewRef.current);
        if (tag == null) return false;
        return NativeDgisMapsModule.centerOnUserLocation(
          tag,
          durationMs ?? 500
        );
      },
    }),
    []
  );

  return (
    <DgisMapsViewNativeComponent
      ref={viewRef}
      markers={mapMarkers(markers)}
      polylines={mapPolylines(polylines)}
      polygons={mapPolygons(polygons)}
      circles={mapCircles(circles)}
      clusterColor={toArgb(clusterColor)}
      clusterTextColor={toArgb(clusterTextColor)}
      {...rest}
    />
  );
}

export const DGisMap = forwardRef<DGisMapHandle, DGisMapProps>(DGisMapImpl);

DGisMap.displayName = 'DGisMap';

export async function initialize(options: {
  apiKey: string;
  logLevel?: 'verbose' | 'info' | 'warning' | 'error' | 'off';
}): Promise<boolean> {
  return NativeDgisMapsModule.initialize(options);
}

export function isInitialized(): boolean {
  return NativeDgisMapsModule.isInitialized();
}

export async function requestLocationPermission(): Promise<boolean> {
  if (Platform.OS === 'ios') {
    return NativeDgisMapsModule.requestLocationPermission();
  }
  if (Platform.OS === 'android') {
    const result = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
    );
    return result === PermissionsAndroid.RESULTS.GRANTED;
  }
  return false;
}

export async function hasLocationPermission(): Promise<boolean> {
  if (Platform.OS === 'ios') {
    return NativeDgisMapsModule.hasLocationPermission();
  }
  if (Platform.OS === 'android') {
    return PermissionsAndroid.check(
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
    );
  }
  return false;
}
