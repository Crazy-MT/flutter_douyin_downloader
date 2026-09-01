import 'package:code_zero/app/modules/douyin_login/douyin_login_binding.dart';
import 'package:code_zero/app/modules/douyin_login/douyin_login_page.dart';
import 'package:code_zero/app/modules/douyin_debugger/douyin_debugger_binding.dart';
import 'package:code_zero/app/modules/douyin_debugger/douyin_debugger_page.dart';
import 'package:code_zero/app/modules/douyin_video_downloader/douyin_video_downloader_binding.dart';
import 'package:code_zero/app/modules/douyin_video_downloader/douyin_video_downloader_page.dart';
import 'package:get/get.dart';

import '../modules/others/splash/splash_binding.dart';
import '../modules/others/splash/splash_page.dart';
import 'app_routes.dart';
import '../modules/others/local_html/local_html_binding.dart';
import '../modules/others/local_html/local_html_page.dart';

class AppPages {
  AppPages._();

  static final routes = _routes;

  static final List<GetPage> _routes = [
    // douyin_login
    GetPage(
      name: RoutesID.DOUYIN_LOGIN_PAGE,
      page: () => const DouyinLoginPage(),
      binding: DouyinLoginBinding(),
    ),


    // douyin_debugger
    GetPage(
      name: RoutesID.DOUYIN_DEBUGGER_PAGE,
      page: () => const DouyinDebuggerPage(),
      binding: DouyinDebuggerBinding(),
    ),

    // douyin_video_downloader
    GetPage(
      name: RoutesID.DOUYIN_VIDEO_DOWNLOADER_PAGE,
      page: () => const DouyinVideoDownloaderPage(),
      binding: DouyinVideoDownloaderBinding(),
    ),


    // local_html
    GetPage(
      name: RoutesID.LOCAL_HTML_PAGE,
      page: () => const LocalHtmlPage(),
      binding: LocalHtmlBinding(),
    ),

    // splash
    GetPage(
      name: RoutesID.SPLASH_PAGE,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
  ];
}
