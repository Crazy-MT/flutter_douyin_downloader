import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

class TextCustom extends Text {
  TextCustom(
    String data, {
    Key? key,
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    double? textScaleFactor,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    Color? backgroundColor, // 自定义属性
    Color? color, // 自定义属性
    double? size, // 自定义属性
    FontWeight? fontWeight,
  }) : super(
          data,
          key: key,
          style: (style ?? const TextStyle()).copyWith(
            backgroundColor: backgroundColor,
            color: color,
            fontSize: size,
            fontWeight: fontWeight,
          ),
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
        );
}
