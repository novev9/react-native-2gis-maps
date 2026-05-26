/**
 * JSX-child placeholders for <DGisMap />.
 *
 * Each component returns null — the parent `<DGisMap />` collects them via
 * `React.Children.forEach`, peeks at a static brand on `element.type`, and
 * builds the props arrays for the underlying Fabric component.
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

import { Children, isValidElement } from 'react';
import type { ImageSourcePropType } from 'react-native';
import type {
  ColorLike,
  DGisCircleInput,
  DGisMarkerInput,
  DGisPolygonInput,
  DGisPolylineInput,
} from './DgisMap';

// Static brand on each child component. We tag types by attaching a stable
// string field rather than relying on `displayName` (which can be stripped /
// renamed by Fast Refresh or bundlers) or on `element.type === Marker`
// identity (which breaks if two copies of the package end up in the graph
// through symlinks / workspaces). Children must be the exported placeholder
// components directly — wrapping with `React.memo`/`forwardRef` would change
// `element.type` and bypass the brand lookup.
const DGIS_CHILD_KIND = '__dgisMapChildKind' as const;
type DgisChildKind = 'Marker' | 'Polyline' | 'Polygon' | 'Circle';

type DgisChildComponent<P> = ((props: P) => null) & {
  displayName?: string;
  [DGIS_CHILD_KIND]?: DgisChildKind;
};

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

export const Marker: DgisChildComponent<DGisMarkerChildProps> = (_props) =>
  null;
Marker.displayName = 'DGisMap.Marker';
Marker[DGIS_CHILD_KIND] = 'Marker';

export const Polyline: DgisChildComponent<DGisPolylineChildProps> = (_props) =>
  null;
Polyline.displayName = 'DGisMap.Polyline';
Polyline[DGIS_CHILD_KIND] = 'Polyline';

export const Polygon: DgisChildComponent<DGisPolygonChildProps> = (_props) =>
  null;
Polygon.displayName = 'DGisMap.Polygon';
Polygon[DGIS_CHILD_KIND] = 'Polygon';

export const Circle: DgisChildComponent<DGisCircleChildProps> = (_props) =>
  null;
Circle.displayName = 'DGisMap.Circle';
Circle[DGIS_CHILD_KIND] = 'Circle';

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
    if (node == null || typeof node === 'boolean') return;
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (!isValidElement(node)) return;

    const element = node as React.ReactElement<unknown>;
    const type = element.type as DgisChildComponent<unknown> | undefined;
    const kind = type?.[DGIS_CHILD_KIND];

    switch (kind) {
      case 'Marker': {
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
      case 'Polyline': {
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
      case 'Polygon': {
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
      case 'Circle': {
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
        // React.Fragment / unknown wrapper — descend into children if any.
        const maybeChildren = (element.props as { children?: React.ReactNode })
          ?.children;
        if (maybeChildren !== undefined) walk(maybeChildren);
      }
    }
  };

  Children.forEach(children, walk);

  return { markers, polylines, polygons, circles };
}
