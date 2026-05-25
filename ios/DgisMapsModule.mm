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

- (void)initialize:(JS::NativeDgisMapsModule::InitializeOptions &)options
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  // Codegen generates a typed wrapper that boxes the JS object; unbox it back into a
  // plain NSDictionary so the existing Swift impl keeps reading apiKey / logLevel.
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
  if (NSString *apiKey = options.apiKey()) {
    dict[@"apiKey"] = apiKey;
  }
  if (NSString *logLevel = options.logLevel()) {
    dict[@"logLevel"] = logLevel;
  }
  [[DgisMapsModuleImpl shared] initialize:dict resolve:resolve reject:reject];
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
