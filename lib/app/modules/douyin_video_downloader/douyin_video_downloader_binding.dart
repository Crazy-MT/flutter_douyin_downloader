import 'package:get/get.dart';

import 'douyin_video_downloader_controller.dart';

class DouyinVideoDownloaderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DouyinVideoDownloaderController>(
      () => DouyinVideoDownloaderController(),
    );
  }
}
