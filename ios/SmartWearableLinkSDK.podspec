Pod::Spec.new do |s|
  s.name           = 'SmartWearableLinkSDK'
  s.version        = '1.2.9'
  s.summary        = 'Expo module for Smart Wearable Link SDK Bluetooth connectivity'
  s.description    = 'Expo module that provides Bluetooth LE functionality for wearable devices'
  s.author         = 'Expo'
  s.homepage       = 'https://github.com/expo/expo'
  s.platforms      = { :ios => '15.1' }
  s.source         = { git: 'https://github.com/expo/expo.git' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.dependency 'FMDB'
  s.dependency 'MJExtension'
  s.swift_versions = '5.4'

  frameworks_dir = File.expand_path('SmartWearableLinkSDK/Frameworks', __dir__)
  xcframeworks = %w[
    VeepooBleSDK
    JL_BLEKit
    JLDialUnit
    GRDFUSDK
    ABParTool
    ZipZap
  ]
  s.preserve_paths = 'SmartWearableLinkSDK/Frameworks/**/*'
  s.vendored_frameworks = xcframeworks.map do |name|
    "SmartWearableLinkSDK/Frameworks/#{name}.xcframework"
  end
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited)',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited)',
    'EXCLUDED_SOURCE_FILE_NAMES[sdk=iphonesimulator*]' => 'SmartWearableLinkSDK.swift SmartWearableLinkSDKModule+*.swift',
    'EXCLUDED_SOURCE_FILE_NAMES[sdk=iphoneos*]' => 'SmartWearableLinkSDKSimulator.swift'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited)',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited)'
  }
  s.frameworks = 'CoreBluetooth', 'CoreLocation', 'CoreMotion', 'CoreAudio', 'AVFoundation'

  s.subspec 'SmartWearableLinkSDK' do |ss|
    ss.source_files = 'SmartWearableLinkSDK/*.{swift,m,h}'
  end
end
