// 自定义滚动行为，支持鼠标横向滚动
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MouseDragBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse, // 支持鼠标拖动
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(); // 让滚动更丝滑
  }
}
