Pod::Spec.new do |s|
  s.name           = 'SmartWearableLinkSDK'
  s.version        = '1.2.7'
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
  linked_frameworks = %w[
    VeepooBleSDK
    JL_BLEKit
    JLDialUnit
    GRDFUSDK
    ABParTool
    ZipZap
  ]
  dynamic_frameworks = %w[
    ABParTool
    GRDFUSDK
    JLDialUnit
    ZipZap
  ]
  linker_flags = linked_frameworks.map { |name| %(-framework "#{name}") }.join(' ')
  embed_frameworks_script = <<-'SCRIPT'
set -eu

case "${PLATFORM_NAME:-}" in
  iphonesimulator*)
    exit 0
    ;;
esac

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ] || [ -z "${PODS_TARGET_SRCROOT:-}" ]; then
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
SOURCE_DIR="${PODS_TARGET_SRCROOT}/SmartWearableLinkSDK/Frameworks"

mkdir -p "${FRAMEWORKS_DIR}"

embed_framework() {
  name="$1"
  source="${SOURCE_DIR}/${name}.framework"
  destination="${FRAMEWORKS_DIR}/${name}.framework"

  if [ ! -d "${source}" ]; then
    echo "warning: SmartWearableLinkSDK missing framework ${source}"
    return
  fi

  rm -rf "${destination}"
  cp -R "${source}" "${destination}"

  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements "${destination}"
  fi
}

embed_framework ABParTool
embed_framework GRDFUSDK
embed_framework JLDialUnit
embed_framework ZipZap
SCRIPT

  s.preserve_paths = 'SmartWearableLinkSDK/Frameworks/**/*'
  s.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' => %($(inherited) "#{frameworks_dir}"),
    'OTHER_LDFLAGS[sdk=iphoneos*]' => %($(inherited) #{linker_flags}),
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(inherited)',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited)',
    'EXCLUDED_SOURCE_FILE_NAMES[sdk=iphonesimulator*]' => 'SmartWearableLinkSDK.swift SmartWearableLinkSDKModule+*.swift',
    'EXCLUDED_SOURCE_FILE_NAMES[sdk=iphoneos*]' => 'SmartWearableLinkSDKSimulator.swift'
  }
  s.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' => %($(inherited) "#{frameworks_dir}"),
    'OTHER_LDFLAGS[sdk=iphoneos*]' => %($(inherited) #{linker_flags}),
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(inherited)',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited)'
  }
  s.script_phase = {
    :name => 'Embed SmartWearableLinkSDK Dynamic Frameworks',
    :script => embed_frameworks_script,
    :execution_position => :after_compile
  }

  s.frameworks = 'CoreBluetooth', 'CoreLocation', 'CoreMotion', 'CoreAudio', 'AVFoundation'

  s.subspec 'SmartWearableLinkSDK' do |ss|
    ss.source_files = 'SmartWearableLinkSDK/*.{swift,m,h}'
  end
end
