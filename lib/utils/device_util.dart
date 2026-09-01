// import 'dart:io';
//
// import 'package:code_zero/utils/log_utils.dart';
// import 'package:code_zero/utils/platform_utils.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/services.dart';
// import 'package:package_info_plus/package_info_plus.dart';

// class DeviceUtil {
// DeviceUtil._();
//
// PackageInfo? packageInfo;
// String? appName;
// String? packageName;
// String? version;
// String? buildNumber;
// String? _deviceId = "";
//
// final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
// IosDeviceInfo? _iosDeviceInfo;
// AndroidDeviceInfo? _androidDeviceInfo;
//
// // 静态实例，通过私有构造函数初始化
// static final DeviceUtil _instance = DeviceUtil._();
//
// // 工厂构造函数返回单例
// factory DeviceUtil() => _instance;
//
// init() async {
//   packageInfo = await PackageInfo.fromPlatform();
//   appName = packageInfo?.appName;
//   packageName = packageInfo?.packageName;
//   version = packageInfo?.version;
//   buildNumber = packageInfo?.buildNumber;
//
//   if (PlatformUtils.isAndroid) {
//     _androidDeviceInfo = await _deviceInfo.androidInfo;
//   } else if (PlatformUtils.isIOS) {
//     _iosDeviceInfo = await _deviceInfo.iosInfo;
//   }
//
//   if (PlatformUtils.isWeb) {
//     try {
//       // todo platform_device_id 没有合适版本
//       // _deviceId = await PlatformDeviceId.getDeviceId;
//       _deviceId = 'Failed to get deviceId.';
//     } on PlatformException {
//       _deviceId = 'Failed to get deviceId.';
//     }
//   }
// }
//
// bool isMobileWeb() {
//   if (!PlatformUtils.isWeb) {
//     return false;
//   }
//   String deviceId = _deviceId!;
//   if (deviceId.contains('iPhone') ||
//       deviceId.contains('Android') ||
//       deviceId.contains('android')) {
//     return true;
//   } else {
//     return false;
//   }
// }
//
// bool isPCWeb() {
//   if (!PlatformUtils.isWeb) {
//     return false;
//   }
//   String deviceId = _deviceId!;
//   if (deviceId.contains('iPhone') ||
//       deviceId.contains('Android') ||
//       deviceId.contains('android')) {
//     return false;
//   } else {
//     return true;
//   }
// }

// String getUniqueID() {
//   if (Platform.isAndroid) {
//     // todo
//     return _androidDeviceInfo?.fingerprint ?? "-1";
//   } else if (Platform.isIOS) {
//     return _iosDeviceInfo?.identifierForVendor ?? "-1";
//   }
//   return "-1";
// }

// String getVersionCode() {
//   if (Platform.isAndroid) {
//     return _androidDeviceInfo?.version.codename ?? "-1";
//   } else if (Platform.isIOS) {
//     return _iosDeviceInfo?.systemVersion ?? "-1";
//   }
//   return "-1";
// }
// }
