import 'dart:ui';
import 'package:flutter/material.dart';

class DipPx {
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static double dip2px(BuildContext context, double dp) {
    return dp * MediaQuery.of(context).devicePixelRatio;
  }

  static double px2dip(BuildContext context, double px) {
    return px / MediaQuery.of(context).devicePixelRatio;
  }
}
