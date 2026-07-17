import {
  ConfigPlugin,
  withInfoPlist,
  withAndroidManifest,
  AndroidConfig,
} from '@expo/config-plugins';

type SmartWearableLinkSDKPluginProps = {
  bluetoothAlwaysPermission?: string;
  bluetoothPeripheralPermission?: string;
};

const DEFAULT_OPTIONS: SmartWearableLinkSDKPluginProps = {
  bluetoothAlwaysPermission:
    'This app needs Bluetooth permission to connect to your wearable device.',
  bluetoothPeripheralPermission:
    'This app needs Bluetooth permission to scan and connect to devices',
};

const withSmartWearableLinkSDK: ConfigPlugin<SmartWearableLinkSDKPluginProps | void> = (
  config,
  props
) => {
  const options: SmartWearableLinkSDKPluginProps = {
    bluetoothAlwaysPermission:
      props?.bluetoothAlwaysPermission ?? DEFAULT_OPTIONS.bluetoothAlwaysPermission!,
    bluetoothPeripheralPermission:
      props?.bluetoothPeripheralPermission ?? DEFAULT_OPTIONS.bluetoothPeripheralPermission!,
  };

  config = withIOSBluetoothPermissions(config, options);
  config = withAndroidBluetoothPermissions(config);
  
  return config;
};

const withIOSBluetoothPermissions: ConfigPlugin<SmartWearableLinkSDKPluginProps> = (
  config,
  options
) => {
  return withInfoPlist(config, (config) => {
    if (options.bluetoothAlwaysPermission) {
      config.modResults.NSBluetoothAlwaysUsageDescription =
        options.bluetoothAlwaysPermission;
    }
    if (options.bluetoothPeripheralPermission) {
      config.modResults.NSBluetoothPeripheralUsageDescription =
        options.bluetoothPeripheralPermission;
    }
    return config;
  });
};

const withAndroidBluetoothPermissions: ConfigPlugin = (config) => {
  return withAndroidManifest(config, (config) => {
    const mainApplication = AndroidConfig.Manifest.getMainApplicationOrThrow(
      config.modResults
    );

    AndroidConfig.Manifest.addMetaDataItemToMainApplication(
      mainApplication,
      'expo.modules.smartwearablelink.enabled',
      'true'
    );

    const permissions = [
      'android.permission.BLUETOOTH',
      'android.permission.BLUETOOTH_ADMIN',
      'android.permission.BLUETOOTH_CONNECT',
      'android.permission.BLUETOOTH_SCAN',
    ];

    permissions.forEach((permission) => {
      if (
        !Array.isArray(config.modResults.manifest['uses-permission']) ||
        !config.modResults.manifest['uses-permission'].some(
          (p: { $: { 'android:name': string } }) => p.$['android:name'] === permission
        )
      ) {
        if (!config.modResults.manifest['uses-permission']) {
          config.modResults.manifest['uses-permission'] = [];
        }
        (config.modResults.manifest['uses-permission'] as { $: { 'android:name': string } }[]).push({
          $: { 'android:name': permission },
        });
      }
    });

    return config;
  });
};

export default withSmartWearableLinkSDK;
