import 'package:code_zero/common/colors.dart';
import 'package:code_zero/common/extend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PresetColorOption {
  final String hex;
  final String name;

  static const List<PresetColorOption> presetColorOptions = [
    PresetColorOption(hex: '#00000000', name: '透明色'),
    PresetColorOption(hex: '#E6EE9C', name: '淡黄绿'),
    PresetColorOption(hex: '#FFF9C4', name: '奶油黄'),
    PresetColorOption(hex: '#F8BBD0', name: '雪粉色'),
    PresetColorOption(hex: '#E1BEE7', name: '浅粉紫'),
    PresetColorOption(hex: '#FFCCBC', name: '浅橙棕'),
    PresetColorOption(hex: '#CE93D8', name: '粉紫色'),
    PresetColorOption(hex: '#F06292', name: '红粉色'),
    PresetColorOption(hex: '#FF7043', name: '橙红色'),
    PresetColorOption(hex: '#FFD54F', name: '金黄色'),
    PresetColorOption(hex: '#FF9800', name: '深橙色'),
    PresetColorOption(hex: '#E91E63', name: '玫红色'),
    PresetColorOption(hex: '#FF4081', name: '艳粉色'),
    PresetColorOption(hex: '#C2185B', name: '紫红色'),
    PresetColorOption(hex: '#BBDEFB', name: '粉蓝色'),
    PresetColorOption(hex: '#8C88EC', name: '淡紫蓝'),
    PresetColorOption(hex: '#4682B4', name: '钢蓝色'),
    PresetColorOption(hex: '#6495ED', name: '矢车篮'),
    PresetColorOption(hex: '#1E90FF', name: '道奇蓝'),
    PresetColorOption(hex: '#4169E1', name: '皇家蓝'),
    PresetColorOption(hex: '#C8E6C9', name: '淡草绿'),
    PresetColorOption(hex: '#808000', name: '橄榄绿'),
    PresetColorOption(hex: '#6A1B9A', name: '深紫色'),
    PresetColorOption(hex: '#CFD8DC', name: '浅灰色'),
    PresetColorOption(hex: '#D1C4E9', name: '淡紫色'),
    PresetColorOption(hex: '#B2EBF2', name: '浅蓝绿'),
    PresetColorOption(hex: '#FF1493', name: '深粉红'),
    PresetColorOption(hex: '#FFEB3B', name: '亮黄色'),
    PresetColorOption(hex: '#0000FF', name: '纯蓝色'),
    PresetColorOption(hex: '#40E0D0', name: '绿松石'),
    PresetColorOption(hex: '#FF0000', name: '纯红色'),
    PresetColorOption(hex: '#FFFFFF', name: '纯白色'),
    PresetColorOption(hex: '#000000', name: '纯黑色'),
    PresetColorOption(hex: '#800080', name: '纯紫色'),
    PresetColorOption(hex: '#00FF00', name: '纯绿色'),
    PresetColorOption(hex: '#D32F2F', name: '正红色'),
  ];

  const PresetColorOption({
    required this.hex,
    required this.name,
  });
}

Future<void> showPresetColorBottomSheet({
  required BuildContext context,
  required String title,
  required List<PresetColorOption> colors,
  required String selectedHex,
  required ValueChanged<String> onSelected,
  bool showTransparent = false,
}) async {
  final displayColors = showTransparent
      ? colors
      : colors.where((c) => c.hex.toUpperCase() != '#00000000').toList();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.w)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.of(context).size.height * 0.7;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.w, 16.w, 16.w),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.w,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.w),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: ColorsApp.text_dark,
                    ),
                  ),
                  SizedBox(height: 12.w),
                  Wrap(
                    spacing: 12.w,
                    runSpacing: 12.w,
                    children: displayColors.map((option) {
                      final hex = option.hex;
                      final isSelected =
                          hex.toUpperCase() == selectedHex.toUpperCase();
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(hex);
                        },
                        child: SizedBox(
                          width: 56.w,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HexColor.fromHex(hexString: hex),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2.w : 1.w,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 20.w,
                                        color: hex.toUpperCase() == '#FFFFFF'
                                            ? Colors.black87
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                              SizedBox(height: 6.w),
                              Text(
                                option.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: ColorsApp.text_dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
