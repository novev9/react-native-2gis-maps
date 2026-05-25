import { TurboModuleRegistry, type TurboModule } from 'react-native';

export type InitializeOptions = {
  apiKey: string;
  logLevel?: 'verbose' | 'info' | 'warning' | 'error' | 'off';
};

export interface Spec extends TurboModule {
  initialize(options: InitializeOptions): Promise<boolean>;
  isInitialized(): boolean;
  flyTo(
    viewTag: number,
    latitude: number,
    longitude: number,
    zoom: number,
    tilt: number,
    bearing: number,
    durationMs: number
  ): Promise<boolean>;
  centerOnUserLocation(viewTag: number, durationMs: number): Promise<boolean>;
  requestLocationPermission(): Promise<boolean>;
  hasLocationPermission(): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('DgisMapsModule');
