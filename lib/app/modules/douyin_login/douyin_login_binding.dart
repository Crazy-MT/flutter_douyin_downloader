import 'package:get/get.dart';

import 'douyin_login_controller.dart';

class DouyinLoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DouyinLoginController>(
      () => DouyinLoginController(),
    );
  }
}
