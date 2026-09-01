import 'package:flutter/material.dart';

class RoundedContainer extends StatelessWidget {
  final Widget child; // 子组件
  final double? borderRadius; // 圆角半径
  final EdgeInsets? padding; // 内边距
  final EdgeInsets? margin; // 外边距
  final double? width; // 宽度
  final double? height; // 高度
  final Color? color;
  final Decoration? decoration;
  // final GestureTapCallback? onTap;

  // 构造函数，设置默认值
  const RoundedContainer({
    super.key,
    required this.child,
    this.borderRadius, // 默认圆角12
    this.padding, // 默认内边距16
    this.margin, // 默认无外边距
    this.width,
    this.height,
    this.color,
    this.decoration,
    // this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // onTap: onTap ?? () {},
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(16.0),
        margin: margin ?? EdgeInsets.zero,
        decoration: decoration ??
            BoxDecoration(
              color: color ?? Colors.white, // 白色背景
              borderRadius: BorderRadius.circular(borderRadius ?? 12), // 圆角
            ),
        child: child,
      ),
    );
  }
}
