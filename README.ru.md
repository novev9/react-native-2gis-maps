# react-native-2gis-maps

[![npm version](https://img.shields.io/npm/v/react-native-2gis-maps.svg)](https://www.npmjs.com/package/react-native-2gis-maps)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![React Native New Architecture](https://img.shields.io/badge/React%20Native-New%20Architecture%20only-61dafb)

React Native Fabric/TurboModule обёртка над 2GIS Mobile SDK 13.5 для iOS и Android. Пакет поддерживает только New Architecture и рассчитан на React Native 0.85+.

> 🇬🇧 English version — [README.md](README.md).

<p align="center">
  <video src="https://github.com/user-attachments/assets/a871787e-4a40-449f-8e30-cf966bd4a4c6" width="320" controls muted playsinline loop>Демо Android</video>
  &nbsp;&nbsp;
  <video src="https://github.com/user-attachments/assets/3d4cee9b-f6bf-4b3a-8e7e-cc00b01da854" width="320" controls muted playsinline loop>Демо iOS</video>
</p>

## Быстрый старт

### 1. Установка

```sh
npm install react-native-2gis-maps
# или
yarn add react-native-2gis-maps
```

### 2. Получить ключ 2GIS Mobile SDK

Mobile SDK требует подписанный бинарный ключ `dgissdk.key`, привязанный к bundle ID / application ID вашего приложения.

Зарегистрируйте приложение на [dev.2gis.ru](https://dev.2gis.ru), укажите свой iOS bundle ID и/или Android application ID, и положите полученный файл сюда:

```text
ios/<App>/dgissdk.key
android/app/src/main/assets/dgissdk.key
```

На iOS также добавьте `dgissdk.key` в Resources вашего таргета в Xcode.

### 3. Отрендерить карту

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

## Установка

### iOS

После 13.2.0 2GIS перестал публиковать Mobile SDK через CocoaPods. SDK 13.5 распространяется только через Swift Package Manager.

Подключение пакета 2GIS в RN-приложении из Xcode:

1. Откройте workspace вашего приложения в Xcode.
2. **File → Add Packages**.
3. Введите URL пакета:

   ```text
   https://github.com/2gis/mobile-sdk-map-swift-package
   ```

4. Выберите ветку `master` или версию `13.5.0+`.
5. Добавьте **Product → MapSDK** в **Frameworks, Libraries, and Embedded Content**.
6. Поставьте режим **Embed & Sign**.
7. Запустите установку Pod-ов:

   ```sh
   cd ios
   pod install
   ```

Podspec этого пакета объявляет SPM-зависимость через `spm_dependency` (фича podspec в React Native 0.75+), но SDK всё равно должен быть подключён к app-таргету как пакет.

Для разработки на физическом устройстве достаточно Personal Team в Apple ID.

### Android

Добавьте Maven-репозиторий 2GIS в проект приложения:

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

`applicationId` в `android/app/build.gradle` должен совпадать с тем, для которого выпущен `dgissdk.key`.

```gradle
android {
  defaultConfig {
    applicationId "com.example.app"
  }
}
```

Положите файл ключа сюда:

```text
android/app/src/main/assets/dgissdk.key
```

### Ключи SDK

`initialize({ apiKey })` принимает Directory API UUID как fallback, но реальная авторизация Mobile SDK идёт через подписанный файл `dgissdk.key`.

Идентификатор приложения, под который выпущен ключ, должен совпадать со следующим:

```text
iOS:     bundleId
Android: applicationId
```

Bundle / application ID, который используется в этом репозитории для разработки автора, не подходит для повторного использования. Приложениям, использующим этот пакет, нужно получать собственный ключ 2GIS.

## Использование

### Инициализация один раз

Вызовите `initialize` один раз до того, как будет смонтирован первый `<DGisMap />`.

```ts
import { initialize } from 'react-native-2gis-maps';

await initialize({
  apiKey: '<DIRECTORY_API_UUID_OR_DEMO_KEY>',
  logLevel: 'info',
});
```

### JSX-children

Рекомендуемый API — объявлять объекты карты как React-children.

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

Доступные child-компоненты:

```ts
Marker;
Polyline;
Polygon;
Circle;
```

Полный набор props см. в TypeScript-типах пакета:

```ts
import type { DGisMapProps, DGisMapHandle } from 'react-native-2gis-maps';
```

### Imperative-команды

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

### Разрешение на геолокацию

```ts
import { requestLocationPermission } from 'react-native-2gis-maps';

const granted = await requestLocationPermission();
```

Описания permission-ов в plist/manifest и платформенный runtime-flow остаются на стороне приложения.

## Миграция с массивов в props

Старый API через prop-массивы помечен deprecated и сохранён для миграции.

Было:

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

Стало:

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

Сейчас в числе deprecated props:

```ts
markers;
polylines;
polygons;
circles;
```

## Структура проекта

```text
src/      TypeScript-источник и публичная точка входа
ios/      Swift и Objective-C++ обёртка, podspec
android/  Kotlin-источник и Gradle-конфиг
cpp/      C++ Fabric component descriptors
example/  Пример приложения
```

Пример приложения может отставать от текущего API библиотеки, пока пакет стабилизируется.

## Известные ограничения

- На одном экране должна быть только одна `<DGisMap />`. Imperative-команды ищут native view через глобальный реестр; при двух картах будет выбрана первая зарегистрированная. В native-логах выводится предупреждение.
- iOS Simulator на Apple Silicon иногда падает на холодном старте с `SIGBUS` в `dyld_sim_prepare`. Похоже на взаимодействие 2GIS Mobile SDK 13.5 и React Native. Для разработки используйте физическое устройство. Иногда помогает `Erase All Content and Settings` для симулятора.
- Дефолтная иконка маркера — встроенный бело-синий кружок 64x64. Для своей иконки передайте `iconSource={require('./pin.png')}` или `iconBase64`.
- 2GIS больше не публикует Mobile SDK 13.5 через CocoaPods. Используйте Swift Package Manager. Сам CocoaPods trunk перейдёт в read-only режим 2026-12-02.

## Требования

```text
React Native: 0.85+
Архитектура: только New Architecture
2GIS Mobile SDK: 13.5
iOS: app-таргет с MapSDK, подключённым через Swift Package Manager
Android: настроенный Maven-репозиторий 2GIS
```

## Лицензия

MIT
