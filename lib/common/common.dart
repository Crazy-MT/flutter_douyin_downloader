import 'package:code_zero/network/l_request.dart';
import 'package:code_zero/network/net_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'colors.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Common {
  _Common();
  PackageInfo? packageInfo;

  // 渠道包修改: 域名默认值
  String host = NetConstant.HOST;

  Future initCommon() async {
    packageInfo = await PackageInfo.fromPlatform();
    LRequest.instance.init();
    _initEasyLoading();
  }

  _initEasyLoading() {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 2000)
      ..indicatorType = EasyLoadingIndicatorType.ring
      ..loadingStyle = EasyLoadingStyle.dark
      ..indicatorSize = 45.0
      ..radius = 10.0
      ..progressColor = ColorsApp.teal_200
      ..backgroundColor = Colors.white.withOpacity(0.9)
      ..indicatorColor = ColorsApp.teal_200
      ..textColor = Colors.black
      ..maskColor = Colors.blue.withOpacity(0.5)
      ..userInteractions = false
      ..dismissOnTap = false;
  }
}

final common = _Common();
