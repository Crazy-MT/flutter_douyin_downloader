import 'dart:io';
import 'dart:async';

import 'package:code_zero/common/colors.dart';
import 'package:code_zero/utils/platform_utils.dart';
import 'package:code_zero/utils/webview2_env_manager.dart';
import 'package:code_zero/utils/scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:window_manager/window_manager.dart';
import 'package:code_zero/common/components/floating_progress_widget.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';

Future<void> main() async {
  if (PlatformUtils.isAndroid) {
    SystemUiOverlayStyle style = const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,

        ///这是设置状态栏的图标和字体的颜色
        ///Brightness.light  一般都是显示为白色
        ///Brightness.dark 一般都是显示为黑色
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light);
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Windows WebView2 环境（使用系统 Evergreen 或打包的 Fixed Version）
  await WebView2EnvManager.instance.initialize();

  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(375, 812),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
      alwaysOnTop: true,
    );
    windowManager.setTitle("抖抖资源");
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  MediaKit.ensureInitialized();
  initFloatingProgress();

  runApp(App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: MouseDragBehavior(),
      child: ScreenUtilInit(
        // scaleByHeight: PlatformUtils.isWeb,
        designSize: const Size(375, 812),
        builder: (context, widget) {
          return OKToast(
            dismissOtherOnShow: true,
            child: GetMaterialApp(
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                RefreshLocalizations.delegate
              ],
              supportedLocales: [
                Locale('zh', ''),
                Locale('en', ''),
              ],
              theme: ThemeData(
                splashColor: Colors.transparent,
                // 点击时的高亮效果设置为透明
                highlightColor: Colors.transparent,
                // 长按时的扩散效果设置为透明
                scaffoldBackgroundColor: ColorsApp.bg_gray,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: ColorsApp.cyan_dark,
                  brightness: Brightness.light,
                ).copyWith(
                  primary: ColorsApp.cyan_dark,
                  onPrimary: ColorsApp.white,
                  primaryContainer: ColorsApp.teal_200,
                  onPrimaryContainer: ColorsApp.text_color,
                  secondary: ColorsApp.cyan,
                  onSecondary: ColorsApp.white,
                  secondaryContainer: ColorsApp.bg_gray,
                  onSecondaryContainer: ColorsApp.text_color,
                  tertiary: ColorsApp.cyan_dark,
                  onTertiary: Colors.white,
                  surface: ColorsApp.bg_gray,
                  surfaceTint: ColorsApp.cyan_dark,
                ),
                primaryColor: ColorsApp.cyan_dark,
                appBarTheme: const AppBarTheme(
                  backgroundColor: ColorsApp.bg_gray,
                  foregroundColor: Colors.black,
                  elevation: 0.2,
                  shadowColor: Colors.black12,
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                  ),
                ),
                buttonTheme: ButtonThemeData(buttonColor: ColorsApp.cyan_dark),
                textSelectionTheme: TextSelectionThemeData(
                    cursorColor: ColorsApp.cyan_dark,
                    selectionColor:
                        ColorsApp.cyan_light.withValues(alpha: 0.35),
                    selectionHandleColor: ColorsApp.cyan_dark),
                sliderTheme: SliderThemeData(
                  thumbColor: ColorsApp.cyan_dark,
                  // 滑块颜色
                  activeTrackColor: ColorsApp.cyan_dark,
                  // 激活部分的轨道颜色
                  inactiveTrackColor:
                      ColorsApp.cyan_light.withValues(alpha: 0.35),
                  // 未激活部分的轨道颜色
                  overlayColor: ColorsApp.cyan_dark.withValues(alpha: 0.2),
                  // 滑块按下时的涟漪效果颜色
                  valueIndicatorColor: ColorsApp.cyan_dark, // 显示数值提示框的颜色
                ),
                inputDecorationTheme: InputDecorationTheme(
                  // 未选中时的下划线颜色
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorsApp.cyan_dark),
                  ),
                  // 选中时的下划线颜色
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorsApp.cyan_dark),
                  ),
                  // 禁用时的下划线颜色
                  disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: ColorsApp.cyan_dark.withValues(alpha: 0.5)),
                  ),
                  // 有错误时的下划线颜色
                  errorBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorsApp.cyan_dark),
                  ),
                  // 选中且有错误时的下划线颜色
                  focusedErrorBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ColorsApp.cyan_dark),
                  ),
                ),
                progressIndicatorTheme: ProgressIndicatorThemeData(
                  color: ColorsApp.cyan_dark, // 主要颜色（圆形或线性加载的前景色）
                  linearTrackColor: Colors.grey.shade300, // 线性加载背景轨道颜色
                  circularTrackColor:
                      Colors.grey.withValues(alpha: 0.2), // 圆形加载背景轨道颜色
                ),
              ),
              debugShowCheckedModeBanner: false,
              routingCallback: (_) {},
              builder: EasyLoading.init(
                builder: (BuildContext context, Widget? child) {
                  Widget widget = MediaQuery(
                    child: GestureDetector(
                      onTap: () {
                        hideKeyboard(context);
                      },
                      child: child,
                    ),
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.noScaling),
                  );

                  return widget;
                },
              ),
              defaultTransition: Transition.rightToLeft,
              title: "抖抖资源",
              initialRoute: RoutesID.SPLASH_PAGE,
              getPages: AppPages.routes,
            ),
          );
        },
      ),
    );
  }
}

void hideKeyboard(BuildContext context) {
  FocusScopeNode currentFocus = FocusScope.of(context);
  if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
    FocusManager.instance.primaryFocus!.unfocus();
  }
}
