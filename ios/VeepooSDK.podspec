Pod::Spec.new do |s|
  s.name           = 'VeepooSDK'
  s.version        = '1.0.1'
  s.summary        = 'Expo module for Veepoo SDK Bluetooth connectivity'
  s.description    = 'Expo module that provides Bluetooth LE functionality for Veepoo devices'
  s.author         = 'Expo'
  s.homepage       = 'https://github.com/expo/expo'
  s.platforms      = { :ios => '15.1' }
  s.source         = { git: 'https://github.com/expo/expo.git' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.dependency 'FMDB'
  s.dependency 'MJExtension'
  s.swift_versions = '5.4'

  s.vendored_frameworks = [
    'VeepooSDK/Frameworks/VeepooBleSDK.framework',
    'VeepooSDK/Frameworks/JL_BLEKit.framework',
    'VeepooSDK/Frameworks/JLDialUnit.framework',
    'VeepooSDK/Frameworks/GRDFUSDK.framework',
    'VeepooSDK/Frameworks/DFUnits.framework',
    'VeepooSDK/Frameworks/ABParTool.framework',
    'VeepooSDK/Frameworks/ZipZap.framework'
  ]

  s.frameworks = 'CoreBluetooth', 'CoreLocation', 'CoreMotion', 'CoreAudio', 'AVFoundation'

  s.subspec 'VeepooSDK' do |ss|
    ss.source_files = 'VeepooSDK/*.{swift,m,h}'
  end
end
