// ignore_for_file: annotate_overrides, overridden_fields
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../colors.dart';

class CommonAppBar extends AppBar {
  final String? titleText;
  final Widget? child;
  final PreferredSizeWidget? bottomWidget;
  final bool centerTitle;
  final Color? iconThemeColor;
  final double? fontSize;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? flexibleSpace;
  final Color? titleColor;
  final double? titleSpacing;
  final double? leadingWidth;
  CommonAppBar({
    Key? key,
    this.fontSize,
    this.iconThemeColor,
    this.centerTitle = false,
    this.titleText,
    this.child,
    this.bottomWidget,
    this.leading,
    this.actions,
    this.flexibleSpace,
    this.titleColor,
    this.titleSpacing,
    this.leadingWidth,
  }) : super(
          key: key,
          elevation: 0.2,
          shadowColor: ColorsApp.gray_light,
          title: child ??
              Text(titleText ?? "",
                  style: TextStyle(
                    fontSize: fontSize ?? 18.sp,
                    color: titleColor ?? Colors.black,
                    fontWeight: FontWeight.w500,
                  )),
          iconTheme: IconThemeData(color: iconThemeColor ?? ColorsApp.white),
          actionsIconTheme: const IconThemeData(color: ColorsApp.white),
          leading: leading,
          backgroundColor: Color(0xffF6F7FC),
          centerTitle: centerTitle,
          actions: actions,
          flexibleSpace: flexibleSpace,
          bottom: bottomWidget,
          titleSpacing: titleSpacing,
          leadingWidth: leadingWidth,
        );
}
