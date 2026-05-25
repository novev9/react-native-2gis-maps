#import "DgisMapsView.h"

#import <CoreLocation/CoreLocation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTConversions.h>
#import <React/RCTUtils.h>

#import <react/renderer/components/DgisMapsViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/DgisMapsViewSpec/EventEmitters.h>
#import <react/renderer/components/DgisMapsViewSpec/Props.h>
#import <react/renderer/components/DgisMapsViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"
#import "DgisMaps-Swift.h"

using namespace facebook::react;

static NSDictionary *DgisCameraToDictionary(const DgisMapsViewInitialCameraStruct &camera)
{
  NSMutableDictionary *dict = [NSMutableDictionary new];
  dict[@"latitude"] = @(camera.latitude);
  dict[@"longitude"] = @(camera.longitude);
  dict[@"zoom"] = @(camera.zoom);
  dict[@"tilt"] = @(camera.tilt);
  dict[@"bearing"] = @(camera.bearing);
  return dict;
}

static NSArray *DgisMarkersToArray(const std::vector<DgisMapsViewMarkersStruct> &items)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:items.size()];
  for (const auto &item : items) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"id"] = [NSString stringWithUTF8String:item.id.c_str()];
    dict[@"latitude"] = @(item.latitude);
    dict[@"longitude"] = @(item.longitude);
    dict[@"iconBase64"] = item.iconBase64.empty() ? nil : [NSString stringWithUTF8String:item.iconBase64.c_str()];
    dict[@"iconWidth"] = @(item.iconWidth);
    dict[@"anchorX"] = @(item.anchorX);
    dict[@"anchorY"] = @(item.anchorY);
    dict[@"zIndex"] = @(item.zIndex);
    [array addObject:dict];
  }
  return array;
}

static NSArray *DgisPolylinesToArray(const std::vector<DgisMapsViewPolylinesStruct> &items)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:items.size()];
  for (const auto &item : items) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *points = [NSMutableArray arrayWithCapacity:item.points.size()];
    for (const auto &point : item.points) {
      [points addObject:@{@"latitude": @(point.latitude), @"longitude": @(point.longitude)}];
    }
    dict[@"id"] = [NSString stringWithUTF8String:item.id.c_str()];
    dict[@"points"] = points;
    dict[@"color"] = @(item.color);
    dict[@"width"] = @(item.width);
    dict[@"dashLength"] = @(item.dashLength);
    dict[@"dashSpace"] = @(item.dashSpace);
    dict[@"zIndex"] = @(item.zIndex);
    [array addObject:dict];
  }
  return array;
}

static NSArray *DgisPolygonsToArray(const std::vector<DgisMapsViewPolygonsStruct> &items)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:items.size()];
  for (const auto &item : items) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *points = [NSMutableArray arrayWithCapacity:item.points.size()];
    for (const auto &point : item.points) {
      [points addObject:@{@"latitude": @(point.latitude), @"longitude": @(point.longitude)}];
    }
    dict[@"id"] = [NSString stringWithUTF8String:item.id.c_str()];
    dict[@"points"] = points;
    dict[@"fillColor"] = @(item.fillColor);
    dict[@"strokeColor"] = @(item.strokeColor);
    dict[@"strokeWidth"] = @(item.strokeWidth);
    dict[@"zIndex"] = @(item.zIndex);
    [array addObject:dict];
  }
  return array;
}

static NSArray *DgisCirclesToArray(const std::vector<DgisMapsViewCirclesStruct> &items)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:items.size()];
  for (const auto &item : items) {
    [array addObject:@{
      @"id": [NSString stringWithUTF8String:item.id.c_str()],
      @"latitude": @(item.latitude),
      @"longitude": @(item.longitude),
      @"radiusMeters": @(item.radiusMeters),
      @"fillColor": @(item.fillColor),
      @"strokeColor": @(item.strokeColor),
      @"strokeWidth": @(item.strokeWidth),
      @"zIndex": @(item.zIndex)
    }];
  }
  return array;
}

@implementation DgisMapsView {
  DgisMapsViewImpl *_impl;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<DgisMapsViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const DgisMapsViewProps>();
    _props = defaultProps;

    _impl = [[DgisMapsViewImpl alloc] initWithFrame:CGRectZero];
    __weak DgisMapsView *weakSelf = self;
    _impl.eventCallback = ^(NSString *eventName, NSDictionary *body) {
      [weakSelf emitEvent:eventName body:body];
    };

    self.contentView = _impl;
  }

  return self;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  // Fabric's ComponentView base class doesn't expose `reactTag` the way Paper
  // did, so we can't propagate the JS-side tag from here. Instead the impl
  // (DgisMapsViewImpl) registers itself globally on init and the module
  // resolves "the current map" by picking the only live entry. Good enough
  // while there's one map on screen; revisit when multi-map is needed.
}

- (void)emitEvent:(NSString *)eventName body:(NSDictionary *)body
{
  const auto eventEmitter = std::static_pointer_cast<const DgisMapsViewEventEmitter>(_eventEmitter);
  if (!eventEmitter) {
    return;
  }

  if ([eventName isEqualToString:@"onMapReady"]) {
    eventEmitter->onMapReady({});
  } else if ([eventName isEqualToString:@"onMapTap"]) {
    eventEmitter->onMapTap({
      .latitude = [body[@"latitude"] doubleValue],
      .longitude = [body[@"longitude"] doubleValue],
      .x = [body[@"x"] floatValue],
      .y = [body[@"y"] floatValue]
    });
  } else if ([eventName isEqualToString:@"onMarkerPress"]) {
    eventEmitter->onMarkerPress({
      .id = std::string([body[@"id"] UTF8String]),
      .latitude = [body[@"latitude"] doubleValue],
      .longitude = [body[@"longitude"] doubleValue]
    });
  } else if ([eventName isEqualToString:@"onCameraChanged"]) {
    eventEmitter->onCameraChanged({
      .latitude = [body[@"latitude"] doubleValue],
      .longitude = [body[@"longitude"] doubleValue],
      .zoom = [body[@"zoom"] floatValue],
      .tilt = [body[@"tilt"] floatValue],
      .bearing = [body[@"bearing"] floatValue],
      .state = std::string([body[@"state"] UTF8String])
    });
  } else if ([eventName isEqualToString:@"onUserLocationChanged"]) {
    eventEmitter->onUserLocationChanged({
      .latitude = [body[@"latitude"] doubleValue],
      .longitude = [body[@"longitude"] doubleValue],
      .accuracy = [body[@"accuracy"] floatValue]
    });
  }
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newPropsTyped = *std::static_pointer_cast<DgisMapsViewProps const>(props);

  // codegen structs lack public operator== outside RN_SERIALIZABLE_STATE builds,
  // so we always push values down. Swift impl diffs markers/lines/polygons/circles by id
  // and ignores repeat applyInitialCamera/setClusteringEnabled calls when nothing changed.
  [_impl applyInitialCamera:DgisCameraToDictionary(newPropsTyped.initialCamera)];
  [_impl setMarkers:DgisMarkersToArray(newPropsTyped.markers)];
  [_impl setPolylines:DgisPolylinesToArray(newPropsTyped.polylines)];
  [_impl setPolygons:DgisPolygonsToArray(newPropsTyped.polygons)];
  [_impl setCircles:DgisCirclesToArray(newPropsTyped.circles)];
  [_impl setShowsUserLocation:newPropsTyped.showsUserLocation];
  [_impl setClusteringEnabled:newPropsTyped.clusteringEnabled
                       radius:@(newPropsTyped.clusteringRadius)
                 clusterColor:@(newPropsTyped.clusterColor)
             clusterTextColor:@(newPropsTyped.clusterTextColor)];
  [_impl setGesturesWithScrollEnabled:newPropsTyped.scrollEnabled
                          zoomEnabled:newPropsTyped.zoomEnabled
                        rotateEnabled:newPropsTyped.rotateEnabled
                          tiltEnabled:newPropsTyped.tiltEnabled];

  [_impl refreshInitializationState];
  [super updateProps:props oldProps:oldProps];
}

@end

Class<RCTComponentViewProtocol> DgisMapsViewCls(void)
{
  return DgisMapsView.class;
}
