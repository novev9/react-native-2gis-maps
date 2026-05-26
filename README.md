# react-native-2gis-maps

[![npm version](https://img.shields.io/npm/v/react-native-2gis-maps.svg)](https://www.npmjs.com/package/react-native-2gis-maps)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![React Native New Architecture](https://img.shields.io/badge/React%20Native-New%20Architecture%20only-61dafb)

React Native Fabric/TurboModule binding for 2GIS Mobile SDK 13.5 on iOS and Android. This package is New Architecture only and is intended for React Native 0.85+.

> 🇷🇺 Русская версия — [README.ru.md](README.ru.md).

<p align="center">
  <video src="https://github.com/user-attachments/assets/a871787e-4a40-449f-8e30-cf966bd4a4c6" width="320" controls muted playsinline loop>Android demo</video>
  &nbsp;&nbsp;
  <video src="https://github.com/user-attachments/assets/3d4cee9b-f6bf-4b3a-8e7e-cc00b01da854" width="320" controls muted playsinline loop>iOS demo</video>
</p>

## Quick Start

### 1. Install

```sh
npm install react-native-2gis-maps
# or
yarn add react-native-2gis-maps
```

### 2. Get a 2GIS SDK key

2GIS Mobile SDK requires a signed binary key file, `dgissdk.key`, bound to your app bundle ID / application ID.

Register your app at [dev.2gis.ru](https://dev.2gis.ru), pass your iOS bundle ID and/or Android application ID, then place the issued key file here:

```text
ios/<App>/dgissdk.key
android/app/src/main/assets/dgissdk.key
```

On iOS, also add `dgissdk.key` to the app target resources in Xcode.

### 3. Render a map

```tsx
import React, { useEffect, useRef } from 'react';
import { StyleSheet } from 'react-native';
import {
  DGisMap,
  Marker,
  Polyline,
  Circle,
  initialize,
  type DGisMapHandle,
} from 'react-native-2gis-maps';

export function MapScreen() {
  const mapRef = useRef<DGisMapHandle>(null);

  useEffect(() => {
    initialize({
      apiKey: '<DIRECTORY_API_UUID_OR_DEMO_KEY>',
      logLevel: 'info',
    });
  }, []);

  return (
    <DGisMap
      ref={mapRef}
      style={StyleSheet.absoluteFill}
      initialCamera={{ latitude: 55.75, longitude: 37.61, zoom: 13 }}
      showsUserLocation
      clusteringEnabled
      clusterColor="#1E88E5"
      onMarkerPress={(event) => {
        console.log(event.nativeEvent.id);
      }}
    >
      <Marker
        id="m1"
        point={{ latitude: 55.75, longitude: 37.61 }}
        iconSource={require('./pin.png')}
      />

      <Polyline
        id="route"
        color="#FF3B30"
        width={5}
        points={[
          { latitude: 55.75, longitude: 37.61 },
          { latitude: 55.76, longitude: 37.64 },
        ]}
      />

      <Circle
        id="zone"
        center={{ latitude: 55.75, longitude: 37.61 }}
        radiusMeters={500}
        fillColor="rgba(37,99,235,0.12)"
      />
    </DGisMap>
  );
}
```

## Installation

### iOS

2GIS stopped publishing the Mobile SDK through CocoaPods after 13.2.0. For SDK 13.5, the SDK is distributed through Swift Package Manager only.

Add the 2GIS SDK package to your React Native app in Xcode:

1. Open your app workspace in Xcode.
2. Select **File → Add Packages**.
3. Use this package URL:

   ```text
   https://github.com/2gis/mobile-sdk-map-swift-package
   ```

4. Select branch `master` or version `13.5.0+`.
5. Add **Product → MapSDK** to **Frameworks, Libraries, and Embedded Content**.
6. Set it to **Embed & Sign**.
7. Run CocoaPods install for the React Native app:

   ```sh
   cd ios
   pod install
   ```

The package podspec declares an SPM dependency using the React Native 0.75+ `spm_dependency` podspec feature, but the SDK package still needs to be available to the app target.

For development on a physical device, a Personal Team is enough for signing.

### Android

Add the 2GIS Maven repository to your app project:

```gradle
// android/build.gradle

allprojects {
  repositories {
    maven { url 'https://artifactory.2gis.dev/sdk-maven-release' }

    google()
    mavenCentral()
  }
}
```

Make sure `applicationId` in `android/app/build.gradle` matches the application ID used when generating `dgissdk.key`.

```gradle
android {
  defaultConfig {
    applicationId "com.example.app"
  }
}
```

Place the key file here:

```text
android/app/src/main/assets/dgissdk.key
```

### SDK Keys

`initialize({ apiKey })` accepts a Directory API UUID as a fallback value, but Mobile SDK authorization is performed through the signed `dgissdk.key` file.

The app ID used for key generation must match:

```text
iOS:     bundleId
Android: applicationId
```

The bundle/application ID used in this repository for the author's own development setup is not reusable. Applications using this package must generate their own 2GIS SDK key.

## Usage

### Initialize Once

Call `initialize` once before rendering the first `<DGisMap />`.

```ts
import { initialize } from 'react-native-2gis-maps';

await initialize({
  apiKey: '<DIRECTORY_API_UUID_OR_DEMO_KEY>',
  logLevel: 'info',
});
```

### JSX Children

The recommended API is to declare map objects as React children.

```tsx
<DGisMap
  style={StyleSheet.absoluteFill}
  initialCamera={{ latitude: 55.75, longitude: 37.61, zoom: 13 }}
  showsUserLocation
  clusteringEnabled
>
  <Marker
    id="marker-1"
    point={{ latitude: 55.75, longitude: 37.61 }}
    iconSource={require('./pin.png')}
  />

  <Polygon
    id="polygon-1"
    fillColor="rgba(30,136,229,0.16)"
    strokeColor="#1E88E5"
    strokeWidth={2}
    points={[
      { latitude: 55.75, longitude: 37.61 },
      { latitude: 55.76, longitude: 37.62 },
      { latitude: 55.75, longitude: 37.63 },
    ]}
  />
</DGisMap>
```

Available child components:

```ts
Marker;
Polyline;
Polygon;
Circle;
```

For the full prop surface, see the TypeScript types exported by the package:

```ts
import type { DGisMapProps, DGisMapHandle } from 'react-native-2gis-maps';
```

### Imperative Handle

```tsx
import { useRef } from 'react';
import { DGisMap, type DGisMapHandle } from 'react-native-2gis-maps';

const mapRef = useRef<DGisMapHandle>(null);

<DGisMap ref={mapRef} style={StyleSheet.absoluteFill} />;

mapRef.current?.flyTo({
  latitude: 55.75,
  longitude: 37.61,
  zoom: 16,
  durationMs: 800,
});

mapRef.current?.centerOnUserLocation(800);
```

### Location Permission

```ts
import { requestLocationPermission } from 'react-native-2gis-maps';

const granted = await requestLocationPermission();
```

The app is still responsible for platform permission descriptions and runtime permission flow appropriate for its product.

## Migration from Prop Arrays

The old prop-array API is deprecated and kept for migration.

Before:

```tsx
<DGisMap
  markers={[{ id: 'm1', latitude: 55.75, longitude: 37.61 }]}
  polylines={[
    {
      id: 'route',
      color: '#FF3B30',
      width: 5,
      points: [
        { latitude: 55.75, longitude: 37.61 },
        { latitude: 55.76, longitude: 37.64 },
      ],
    },
  ]}
/>
```

After:

```tsx
<DGisMap>
  <Marker id="m1" point={{ latitude: 55.75, longitude: 37.61 }} />

  <Polyline
    id="route"
    color="#FF3B30"
    width={5}
    points={[
      { latitude: 55.75, longitude: 37.61 },
      { latitude: 55.76, longitude: 37.64 },
    ]}
  />
</DGisMap>
```

Deprecated props currently include:

```ts
markers;
polylines;
polygons;
circles;
```

## Project Structure

```text
src/      TypeScript source and public entry point
ios/      Swift and Objective-C++ wrapper, podspec
android/  Kotlin source and Gradle config
example/  Example app
```

The example app may lag behind the library API while the package is being stabilized.

## Known Limitations

- Only one `<DGisMap />` should be mounted per screen. Imperative ref commands currently resolve the native view through a global registry; with multiple maps, the first registered view may be used. A native warning is logged for this case.
- iOS Simulator on Apple Silicon may crash on cold start with `SIGBUS` in `dyld_sim_prepare`. This appears to be an interaction between 2GIS Mobile SDK 13.5 and React Native. Use a physical device for development. Erasing the simulator contents sometimes helps.
- The default marker icon is a built-in 64x64 white-and-blue circle. Use `iconSource={require('./pin.png')}` or `iconBase64` for custom icons.
- 2GIS no longer distributes Mobile SDK 13.5 through CocoaPods. Use Swift Package Manager. CocoaPods trunk is also scheduled to become read-only on 2026-12-02.

## Requirements

```text
React Native: 0.85+
Architecture: New Architecture only
2GIS Mobile SDK: 13.5
iOS: app target with MapSDK added through Swift Package Manager
Android: 2GIS Maven repository configured
```

## License

MIT
