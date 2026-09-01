import 'package:code_zero/common/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum InputTheme {
  cerulean,
  orange,
}

class CommonInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? errorText;
  final String? labelText;
  final String? hintText;
  final double? hintTextSize;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final Color? cursorColor;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool enable;
  final TextAlign textAlign;
  final int? maxLines;
  final Color? hintTextColor;
  final double? horizontal;
  final FocusNode? focusNode;
  final int? maxLength;
  final bool autofocus;

  const CommonInput({
    Key? key,
    this.controller,
    this.hintTextSize,
    this.hintText,
    this.errorText,
    this.onSubmitted,
    this.labelText,
    this.onChanged,
    this.suffixIcon,
    this.style,
    this.hintStyle,
    this.fillColor,
    this.obscureText = false,
    this.inputFormatters,
    this.keyboardType,
    this.cursorColor,
    this.enable = true,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.horizontal,
    this.hintTextColor,
    this.focusNode,
    this.maxLength,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autofocus,
      focusNode: focusNode,
      controller: controller,
      enabled: true,
      readOnly: !enable,
      // 不可编辑（只读）时禁止选中/复制
      enableInteractiveSelection: enable,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      maxLines: maxLines,
      style: style ??
          TextStyle(
            color: const Color(0xFF0E0D1F),
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      cursorColor: cursorColor ?? ColorsApp.teal_200,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle ??
            TextStyle(
              color: hintTextColor ?? Color(0xFFD9D9D9),
              fontSize: hintTextSize ?? 20.w,
              fontWeight: FontWeight.w600,
            ),
        fillColor: fillColor ?? Colors.white,
        //背景颜色，必须结合filled: true,才有效
        filled: true,
        //重点，必须设置为true，fillColor才有效
        isCollapsed: true,
        //重点，相当于高度包裹的意思，必须设置为true，不然有默认奇妙的最小高度
        contentPadding:
            EdgeInsets.symmetric(horizontal: horizontal ?? 5, vertical: 7),
        //内容内边距，影响高度
        border: _outlineInputBorder,
        //边框，一般下面的几个边框一起设置
        focusedBorder: _outlineInputBorder,
        enabledBorder: _outlineInputBorder,
        disabledBorder: _outlineInputBorder,
        focusedErrorBorder: _outlineInputBorder,
        errorBorder: _outlineInputBorder,
      ),
      maxLength: maxLength,
    );
  }
}

//无边框样式
OutlineInputBorder _outlineInputBorder = OutlineInputBorder(
  gapPadding: 0,
  borderSide: BorderSide.none,
);

Widget buildInputWithTitle(Widget titleWidget,
    {EdgeInsetsGeometry? padding,
    TextEditingController? inputController,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    Color? hintColor,
    Widget? suffixWidget,
    Widget? prefixWidget,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enable = true,
    ValueChanged<String>? onSubmitted,
    double? height,
    double? borderRadius,
    double? paddingInner,
    double? left,
    double? hintTextOpacity,
    CrossAxisAlignment? crossAxisAlignment,
    ValueChanged<String>? onChanged}) {
  return Padding(
    padding: padding ?? EdgeInsets.zero,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //     padding: EdgeInsets.only(left: 5.w, bottom: 8), child: titleWidget),
        Container(
          height: height ?? 44.w,
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(borderRadius ?? 22.w),
          ),
          alignment: Alignment.center,
          padding:
              EdgeInsets.all(paddingInner ?? 7.w).copyWith(left: left ?? 16.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.center,
            children: [
              prefixWidget != null ? prefixWidget : SizedBox.shrink(),
              Expanded(
                child: CommonInput(
                  enable: enable,
                  inputFormatters: inputFormatters,
                  obscureText: obscureText,
                  controller: inputController,
                  keyboardType: keyboardType,
                  fillColor: Colors.transparent,
                  onSubmitted: onSubmitted,
                  maxLines: null,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: ColorsApp.text_dark,
                    height: 1,
                  ),
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color:
                        ColorsApp.text_dark.withOpacity(hintTextOpacity ?? 0.3),
                  ),
                  onChanged: onChanged,
                ),
              ),
              suffixWidget != null ? suffixWidget : Container(),
            ],
          ),
        ),
      ],
    ),
  );
}

buildInput(Widget titleWidget,
    {EdgeInsetsGeometry? padding,
    TextEditingController? inputController,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    Color? hintColor,
    Color? textColor,
    Color? bgColor,
    EdgeInsetsGeometry? innerPadding,
    Widget? suffixWidget,
    Widget? prefixWidget,
    int? maxLines,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enable = true,
    ValueChanged<String>? onSubmitted,
    double? height,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    bool autofocus = false}) {
  return Padding(
    padding: padding ?? EdgeInsets.zero,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //     padding: EdgeInsets.only(left: 5.w, bottom: 8), child: titleWidget),
        Container(
          height: height ?? 40.w,
          decoration: BoxDecoration(
            color: bgColor ?? Color(0x33ffffff),
            borderRadius: BorderRadius.circular(10.w),
          ),
          alignment: Alignment.center,
          padding: innerPadding ??
              EdgeInsets.all(7.w).copyWith(left: 6.w, bottom: 4.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              prefixWidget != null ? prefixWidget : SizedBox.shrink(),
              Expanded(
                child: CommonInput(
                enable: enable,
                inputFormatters: inputFormatters,
                obscureText: obscureText,
                controller: inputController,
                keyboardType: keyboardType,
                fillColor: Colors.transparent,
                focusNode: focusNode,
                onSubmitted: onSubmitted,
                maxLines: maxLines,
                autofocus: autofocus,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: textColor ?? ColorsApp.text_dark,
                  height: 1,
                ),
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: hintColor ?? ColorsApp.white.withOpacity(0.3),
                  height: 1,
                ),
                onChanged: onChanged,
              ),
              ),
              suffixWidget != null ? suffixWidget : Container(),
            ],
          ),
        ),
      ],
    ),
  );
}
