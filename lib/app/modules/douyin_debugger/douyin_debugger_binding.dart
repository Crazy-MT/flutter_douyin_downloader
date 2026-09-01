import 'package:get/get.dart';

import 'douyin_debugger_controller.dart';

class DouyinDebuggerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DouyinDebuggerController>(
      () => DouyinDebuggerController(),
    );
  }
}
