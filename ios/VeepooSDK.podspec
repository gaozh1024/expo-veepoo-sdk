Pod::Spec.new do |s|
  s.name           = 'VeepooSDK'
  s.version        = '1.0.1'
  s.summary        = 'Expo module for Veepoo SDK Bluetooth connectivity'
  s.description    = 'Expo module that provides Bluetooth LE functionality for Veepoo devices'
  s.author         = 'Expo'
  s.homepage       = 'https://github.com/expo/expo'
  s.platforms      = { :ios => '13.4' }
  s.source         = { git: 'https://github.com/expo/expo.git' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.swift_versions = '5.4'

  # Local frameworks from VeepooSDK/Frameworks
  s.vendored_frameworks = [
    'VeepooSDK/Frameworks/VeepooBleSDK.framework',
    'VeepooSDK/Frameworks/JL_BLEKit.framework',
    'VeepooSDK/Frameworks/JLDialUnit.framework',
    'VeepooSDK/Frameworks/GRDFUSDK.framework',
    'VeepooSDK/Frameworks/DFUnits.framework',
    'VeepooSDK/Frameworks/ABParTool.framework',
    'VeepooSDK/Frameworks/ZipZap.framework'
  ]

  # Framework dependencies
  s.frameworks = 'CoreBluetooth', 'CoreLocation', 'CoreMotion'

  s.subspec 'VeepooSDK' do |ss|
    ss.source_files = 'VeepooSDK/*.{swift,m,h}'
  end
end
