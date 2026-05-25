#import "DgisMapsModule.h"

#import <CoreLocation/CoreLocation.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>
#import "DgisMaps-Swift.h"

@implementation DgisMapsModule

RCT_EXPORT_MODULE(DgisMapsModule)

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
  (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeDgisMapsModuleSpecJSI>(params);
}

- (void)initialize:(NSDictionary *)options
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject
{
  [[DgisMapsModuleImpl shared] initialize:options resolve:resolve reject:reject];
}

- (NSNumber *)isInitialized
{
  return @([[DgisMapsModuleImpl shared] isInitialized]);
}

- (void)flyTo:(double)viewTag
     latitude:(double)latitude
    longitude:(double)longitude
         zoom:(double)zoom
         tilt:(double)tilt
      bearing:(double)bearing
   durationMs:(double)durationMs
      resolve:(RCTPromiseResolveBlock)resolve
       reject:(RCTPromiseRejectBlock)reject
{
  [[DgisMapsModuleImpl shared] flyToViewTag:@(viewTag)
                                   latitude:@(latitude)
                                  longitude:@(longitude)
                                       zoom:@(zoom)
                                       tilt:@(tilt)
                                    bearing:@(bearing)
                                 durationMs:@(durationMs)
                                    resolve:resolve
                                     reject:reject];
}

- (void)centerOnUserLocation:(double)viewTag
                  durationMs:(double)durationMs
                     resolve:(RCTPromiseResolveBlock)resolve
                      reject:(RCTPromiseRejectBlock)reject
{
  [[DgisMapsModuleImpl shared] centerOnUserLocationWithViewTag:@(viewTag)
                                                    durationMs:@(durationMs)
                                                       resolve:resolve
                                                        reject:reject];
}

- (void)requestLocationPermission:(RCTPromiseResolveBlock)resolve
                           reject:(RCTPromiseRejectBlock)reject
{
  [[DgisMapsModuleImpl shared] requestLocationPermissionWithResolve:resolve reject:reject];
}

- (NSNumber *)hasLocationPermission
{
  return @([[DgisMapsModuleImpl shared] hasLocationPermission]);
}

@end
