import 'package:code_zero/app/routes/app_routes.dart';
import 'package:code_zero/common/components/confirm_dialog.dart';
import 'package:code_zero/common/extend.dart';
import 'package:code_zero/common/widget.dart';
import 'package:code_zero/generated/assets/assets.dart';
import 'package:code_zero/utils/log_utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:restart_app/restart_app.dart';

import 'splash_controller.dart';
import 'package:code_zero/common/components/status_page/status_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => FTStatusPage(
          type: controller.pageStatus.value,
          errorMsg: controller.errorMsg.value,
          builder: (BuildContext context) {
            return Stack(
              children: [
                Container(
                    width: double.infinity,
                    child: Image.asset(
                      Assets.imagesBgSplash,
                      fit: BoxFit.fill,
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}
