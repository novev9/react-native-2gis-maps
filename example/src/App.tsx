import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  DGisMap,
  type DGisMapHandle,
  type DGisMarkerInput,
  type DGisPolylineInput,
  initialize,
  requestLocationPermission,
} from 'react-native-2gis-maps';

const DGIS_API_KEY = '<REDACTED_2GIS_API_KEY>';

const MOSCOW = { latitude: 55.752425, longitude: 37.613983 };
const RED_SQUARE = { latitude: 55.7539, longitude: 37.6208 };
const OKHOTNY_RYAD = { latitude: 55.7575, longitude: 37.6147 };

function randomMarkers(count: number): DGisMarkerInput[] {
  const list: DGisMarkerInput[] = [];
  for (let i = 0; i < count; i++) {
    const dLat = (Math.random() - 0.5) * 0.08;
    const dLng = (Math.random() - 0.5) * 0.12;
    list.push({
      id: `m${i}`,
      latitude: MOSCOW.latitude + dLat,
      longitude: MOSCOW.longitude + dLng,
    });
  }
  return list;
}

const ROUTE: DGisPolylineInput = {
  id: 'route-1',
  color: '#FF3B30',
  width: 5,
  points: [OKHOTNY_RYAD, { latitude: 55.7551, longitude: 37.6174 }, RED_SQUARE],
};

export default function App() {
  const mapRef = useRef<DGisMapHandle>(null);
  const [ready, setReady] = useState(false);
  const [initError, setInitError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    initialize({ apiKey: DGIS_API_KEY, logLevel: 'info' })
      .then((ok) => {
        if (!cancelled) setReady(ok);
      })
      .catch((e: unknown) => {
        if (!cancelled) {
          setInitError(e instanceof Error ? e.message : String(e));
        }
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const markers = useMemo(() => randomMarkers(50), []);

  const flyToRed = () => {
    mapRef.current?.flyTo({ ...RED_SQUARE, zoom: 16, durationMs: 800 });
  };

  const centerOnMe = async () => {
    const granted = await requestLocationPermission();
    if (!granted) {
      Alert.alert('Нет разрешения на геолокацию');
      return;
    }
    mapRef.current?.centerOnUserLocation(800);
  };

  if (initError) {
    return (
      <View style={[styles.container, styles.center]}>
        <Text style={styles.error}>SDK init error: {initError}</Text>
      </View>
    );
  }

  if (!ready) {
    return (
      <View style={[styles.container, styles.center]}>
        <ActivityIndicator />
        <Text style={styles.muted}>Initializing 2GIS SDK…</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <DGisMap
        ref={mapRef}
        style={StyleSheet.absoluteFill}
        initialCamera={{ ...MOSCOW, zoom: 13 }}
        markers={markers}
        polylines={[ROUTE]}
        showsUserLocation
        clusteringEnabled
        clusteringRadius={80}
        clusterColor="#1E88E5"
        clusterTextColor="#FFFFFF"
        onMapReady={() => {
          console.log('[DGisMap] ready');
        }}
        onMapTap={(e) => {
          console.log('[DGisMap] tap', e.nativeEvent);
        }}
        onMarkerPress={(e) => {
          Alert.alert('Marker', `id=${e.nativeEvent.id}`);
        }}
      />
      <View style={styles.fabColumn} pointerEvents="box-none">
        <Pressable style={styles.fab} onPress={flyToRed}>
          <Text style={styles.fabText}>Fly to Red Square</Text>
        </Pressable>
        <Pressable style={styles.fab} onPress={centerOnMe}>
          <Text style={styles.fabText}>Where am I</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0e0e0e' },
  center: { alignItems: 'center', justifyContent: 'center' },
  muted: { marginTop: 12, color: '#aaa' },
  error: { color: '#ff5252', padding: 24, textAlign: 'center' },
  fabColumn: {
    position: 'absolute',
    right: 16,
    bottom: Platform.OS === 'ios' ? 48 : 24,
    gap: 12,
  },
  fab: {
    backgroundColor: 'rgba(0,0,0,0.7)',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 22,
  },
  fabText: { color: '#fff', fontWeight: '600' },
});
