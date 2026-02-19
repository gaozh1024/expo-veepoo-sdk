import {
  ConfigPlugin,
  withInfoPlist,
  withAndroidManifest,
  AndroidConfig,
} from '@expo/config-plugins';

type VeepooSDKPluginProps = {
  bluetoothAlwaysPermission?: string;
  bluetoothPeripheralPermission?: string;
};

const DEFAULT_OPTIONS: VeepooSDKPluginProps = {
  bluetoothAlwaysPermission:
    'This app needs Bluetooth permission to connect to Veepoo devices',
  bluetoothPeripheralPermission:
    'This app needs Bluetooth permission to scan and connect to devices',
};

const withVeepooSDK: ConfigPlugin<VeepooSDKPluginProps | void> = (
  config,
  props
) => {
  const options: VeepooSDKPluginProps = {
    bluetoothAlwaysPermission:
      props?.bluetoothAlwaysPermission ?? DEFAULT_OPTIONS.bluetoothAlwaysPermission!,
    bluetoothPeripheralPermission:
      props?.bluetoothPeripheralPermission ?? DEFAULT_OPTIONS.bluetoothPeripheralPermission!,
  };

  config = withIOSBluetoothPermissions(config, options);
  config = withAndroidBluetoothPermissions(config);
  
  return config;
};

const withIOSBluetoothPermissions: ConfigPlugin<VeepooSDKPluginProps> = (
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
      'expo.modules.veepoo.enabled',
      'true'
    );

    const permissions = [
      'android.permission.BLUETOOTH',
      'android.permission.BLUETOOTH_ADMIN',
      'android.permission.BLUETOOTH_CONNECT',
      'android.permission.BLUETOOTH_SCAN',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
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

export default withVeepooSDK;
