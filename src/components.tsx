/**
 * JSX-child placeholders for <DGisMap />.
 *
 * Each component returns null — the parent `<DGisMap />` collects them via
 * `React.Children.toArray`, peeks at `displayName`, and builds the props
 * arrays for the underlying Fabric component. Mirrors the yandex-map API so
 * consumers can swap providers without rewriting JSX trees.
 *
 * ```tsx
 * <DGisMap>
 *   <Marker id="m1" point={{ latitude, longitude }} iconSource={require('./pin.png')} />
 *   <Polyline id="route" points={[…]} color="#FF3B30" width={5} />
 *   <Polygon id="zone" points={[…]} fillColor="#33007aff" />
 *   <Circle id="r" center={{ latitude, longitude }} radiusMeters={500} />
 * </DGisMap>
 * ```
 */

import type { ImageSourcePropType } from 'react-native';
import type {
  ColorLike,
  DGisCircleInput,
  DGisMarkerInput,
  DGisPolygonInput,
  DGisPolylineInput,
} from './DgisMap';

type Point = { latitude: number; longitude: number };

export type DGisMarkerChildProps = {
  id: string;
  point: Point;
  iconBase64?: string;
  iconSource?: ImageSourcePropType;
  iconWidth?: number;
  anchorX?: number;
  anchorY?: number;
  zIndex?: number;
};

export type DGisPolylineChildProps = {
  id: string;
  points: ReadonlyArray<Point>;
  color?: ColorLike;
  width?: number;
  dashLength?: number;
  dashSpace?: number;
  zIndex?: number;
};

export type DGisPolygonChildProps = {
  id: string;
  points: ReadonlyArray<Point>;
  fillColor?: ColorLike;
  strokeColor?: ColorLike;
  strokeWidth?: number;
  zIndex?: number;
};

export type DGisCircleChildProps = {
  id: string;
  center: Point;
  radiusMeters: number;
  fillColor?: ColorLike;
  strokeColor?: ColorLike;
  strokeWidth?: number;
  zIndex?: number;
};

export function Marker(_props: DGisMarkerChildProps): null {
  return null;
}
Marker.displayName = 'DGisMap.Marker';

export function Polyline(_props: DGisPolylineChildProps): null {
  return null;
}
Polyline.displayName = 'DGisMap.Polyline';

export function Polygon(_props: DGisPolygonChildProps): null {
  return null;
}
Polygon.displayName = 'DGisMap.Polygon';

export function Circle(_props: DGisCircleChildProps): null {
  return null;
}
Circle.displayName = 'DGisMap.Circle';

/**
 * Internal: takes whatever was nested under <DGisMap> and sorts JSX children
 * into the four spec buckets the native side understands. Unknown children
 * (host components, fragments, plain strings) are silently dropped so the
 * consumer can interleave dev overlays without us choking.
 */
export function collectMapChildren(children: React.ReactNode): {
  markers: DGisMarkerInput[];
  polylines: DGisPolylineInput[];
  polygons: DGisPolygonInput[];
  circles: DGisCircleInput[];
} {
  const markers: DGisMarkerInput[] = [];
  const polylines: DGisPolylineInput[] = [];
  const polygons: DGisPolygonInput[] = [];
  const circles: DGisCircleInput[] = [];

  const walk = (node: React.ReactNode): void => {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (node == null || typeof node === 'boolean') return;
    if (typeof node !== 'object') return;

    const element = node as React.ReactElement<unknown>;
    const type = element.type as { displayName?: string } | undefined;
    const name = typeof type === 'object' ? type?.displayName : undefined;

    switch (name) {
      case 'DGisMap.Marker': {
        const p = element.props as DGisMarkerChildProps;
        markers.push({
          id: p.id,
          latitude: p.point.latitude,
          longitude: p.point.longitude,
          iconBase64: p.iconBase64,
          iconSource: p.iconSource,
          iconWidth: p.iconWidth,
          anchorX: p.anchorX,
          anchorY: p.anchorY,
          zIndex: p.zIndex,
        });
        return;
      }
      case 'DGisMap.Polyline': {
        const p = element.props as DGisPolylineChildProps;
        polylines.push({
          id: p.id,
          points: [...p.points],
          color: p.color,
          width: p.width,
          dashLength: p.dashLength,
          dashSpace: p.dashSpace,
          zIndex: p.zIndex,
        });
        return;
      }
      case 'DGisMap.Polygon': {
        const p = element.props as DGisPolygonChildProps;
        polygons.push({
          id: p.id,
          points: [...p.points],
          fillColor: p.fillColor,
          strokeColor: p.strokeColor,
          strokeWidth: p.strokeWidth,
          zIndex: p.zIndex,
        });
        return;
      }
      case 'DGisMap.Circle': {
        const p = element.props as DGisCircleChildProps;
        circles.push({
          id: p.id,
          latitude: p.center.latitude,
          longitude: p.center.longitude,
          radiusMeters: p.radiusMeters,
          fillColor: p.fillColor,
          strokeColor: p.strokeColor,
          strokeWidth: p.strokeWidth,
          zIndex: p.zIndex,
        });
        return;
      }
      default: {
        // React.Fragment — walk children. Unknown nodes are skipped.
        const maybeChildren = (element.props as { children?: React.ReactNode })
          ?.children;
        if (maybeChildren !== undefined) walk(maybeChildren);
      }
    }
  };

  walk(children);

  return { markers, polylines, polygons, circles };
}
