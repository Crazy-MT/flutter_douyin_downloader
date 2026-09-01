import 'package:code_zero/common/components/rounded_container.dart';
import 'package:code_zero/common/extend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PageErrorWidget extends StatelessWidget {
  const PageErrorWidget({Key? key, this.error, this.retryMethod})
      : super(key: key);
  final GestureTapCallback? retryMethod;
  final dynamic error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset(
            'assets/icons/error.png',
            width: 100.w,
            height: 100.w,
          ),
          const SizedBox(
            height: 20,
          ),
          Text(
            error ?? '糟糕！好像出错了……',
            style: TextStyle(
              color: Color(0xffABAAB9),
              fontSize: 14.sp,
            ),
          ),
          SizedBox(
            height: 20,
          ),
          InkWell(
            onTap: retryMethod,
            child: Container(
              padding: const EdgeInsets.all(6.0).copyWith(left: 20, right: 20),
              decoration: BoxDecoration(
                // color: Colors.white, // 白色背景
                border: Border.all(
                  color: HexColor.fromHex(hexString: '#cccccc'), // 边框颜色
                  width: 1, // 边框宽度
                ),
                borderRadius: BorderRadius.circular(24), // 圆角
              ),
              child: Text(
                '重新加载',
                style: TextStyle(color: HexColor.fromHex(hexString: '#cccccc')),
              ),
            ),
          )
        ],
      ),
    );
  }
}
