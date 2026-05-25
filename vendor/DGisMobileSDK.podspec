# Local override for DGisMobileSDK.
#
# The trunk podspec is stuck at 13.2.0-map and that build SIGBUSes inside
# dyld_sim_prepare on iOS 26.4 simulator + Xcode 26. The vendor's SPM package
# (mobile-sdk-map-swift-package) ships 13.5.0 which works there — we point
# this podspec at the same artifactory zip used by the SPM binaryTarget so
# CocoaPods can use the newer xcframework directly.
Pod::Spec.new do |s|
  s.name         = "DGisMobileSDK"
  s.version      = "13.5.0-map"
  s.summary      = "2GIS Mobile SDK for iOS (map flavour) — local 13.5.0 override"
  s.homepage     = "https://dev.2gis.com"
  s.license      = { :type => "Proprietary", :text => "(c) 2GIS" }
  s.authors      = "2GIS"

  s.platforms    = { :ios => "13.0" }

  s.source       = {
    :http => "https://artifactory.2gis.dev/sdk-ios-release/13.5.0/Release/DGisMapSDK.zip"
  }

  s.vendored_frameworks = "DGis.xcframework"
end
