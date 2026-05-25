require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "DgisMaps"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/novev9/react-native-2gis-maps.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"

  s.static_framework = true
  s.swift_version = "5.0"

  s.dependency "DGisMobileSDK", "13.2.0-map"

  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "OTHER_LDFLAGS" => "$(inherited) -ObjC",
    "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"
  }

  install_modules_dependencies(s)
end
