import 'package:code_zero/common/components/confirm_dialog.dart';
import 'package:code_zero/utils/log_utils.dart';
import 'package:code_zero/utils/webview2_env_manager.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter/services.dart';

import 'douyin_login_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:code_zero/app/routes/app_routes.dart';
import 'package:code_zero/common/colors.dart';
import 'package:code_zero/common/components/common_app_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;

class DouyinLoginPage extends GetView<DouyinLoginController> {
  const DouyinLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await controller.saveCookie();
        Get.back(result: 1);
        return true;
      },
      child: Scaffold(
        backgroundColor: ColorsApp.bg_gray,
        appBar: CommonAppBar(
          titleText: '抖音登录',
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Colors.black,
            onPressed: () async {
              bool isSucc = await controller.saveCookie();
              lLog('DouyinLoginPage.build ${isSucc} ');
              Get.back(result: 1);
            },
          ),
          actions: [
            // 无法登录时，点击弹出说明并切换登录网址
            GestureDetector(
              onTap: () {
                // 与项目内其他弹窗保持统一样式
                showConfirmDialog(
                  title: '无法登录点我',
                  contentWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '如果当前登录方式无法正常登录，请选择其他登录网址：',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: ColorsApp.text_dark,
                        ),
                      ),
                      SizedBox(height: 12.w),
                      if (controller.loginUrls.isEmpty)
                        Text(
                          '暂无可选链接',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: ColorsApp.text_dark,
                          ),
                        )
                      else
                        ...controller.loginUrls.map((item) => InkWell(
                              onTap: () {
                                Get.back();
                                controller.selectLoginUrl(item);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.w),
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: ColorsApp.teal_200,
                                  ),
                                ),
                              ),
                            )),
                    ],
                  ),
                  singleText: '知道了',
                );
              },
              child: Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Center(
                  child: Text(
                    '无法登录点我',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            _buildDyWebView(),
            Obx(() => Visibility(
                  visible: controller.dyUrl.value.isNotEmpty,
                  child: Align(
                    alignment: Alignment.bottomCenter, // 确保 Container 贴底
                    child: Container(
                      width: 300.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                      padding: EdgeInsets.all(20.w),
                      margin: EdgeInsets.only(bottom: 20.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w400,
                                  color: ColorsApp.text_dark,
                                ),
                                children: [
                                  TextSpan(
                                    text: "扫码登陆开播的抖音账号，完成登录后点击“我已登录”按钮\n",
                                  ),
                                  TextSpan(
                                    text: "（双指捏合可放大缩小页面，方便登录）",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 10.w,
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 126.w,
                                height: 36.w,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    lLog(
                                        'DouyinLoginPage.build ${Get.arguments} ');
                                    if (Get.arguments != null &&
                                        Get.arguments['from'] ==
                                            RoutesID.SCRIPT_PAGE_PAGE) {
                                      Get.back(result: 2);
                                      return;
                                    }
                                    // 清空 cookie
                                    await controller.clearCookie();
                                    Get.back(result: 2);
                                  },
                                  child: Text(
                                    "我要退出",
                                    style: TextStyle(
                                      color: ColorsApp.text_dark,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    shape: StadiumBorder(),
                                  ).copyWith(
                                    padding: MaterialStateProperty.all(
                                        const EdgeInsets.all(0)),
                                    backgroundColor:
                                    MaterialStateProperty.all(
                                        Color(0xFFF0F0F0)),
                                    elevation:
                                    MaterialStateProperty.all(0),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 8.w,
                              ),
                              SizedBox(
                                width: 126.w,
                                height: 36.w,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    // 尝试收起系统键盘（包括 WebView 内部输入框）
                                    SystemChannels.textInput
                                        .invokeMethod('TextInput.hide');
                                    // 让 H5 当前激活的输入框失去焦点
                                    controller.webViewController
                                        ?.evaluateJavascript(
                                      source:
                                          'document.activeElement && document.activeElement.blur();',
                                    );
                                    bool isSave = await controller.saveCookie();
                                    if (isSave) {
                                      Get.back(result: 3);
                                    } else {
                                      showToast("您尚未登录抖音，请先在该页面登录抖音");
                                    }
                                  },
                                  onLongPress: () async {
                                    // 长按获取并复制Cookie
                                    var cookieManager =
                                        WebView2EnvManager.instance.cookieManager;
                                    var cookies =
                                        await cookieManager.getCookies(
                                            url: webview.WebUri.uri(Uri.parse(
                                                "https://www.douyin.com")));
                                    String cookie = '';
                                    for (var co in cookies) {
                                      cookie += '${co.name}=${co.value}; ';
                                    }
                                    if (cookie.isNotEmpty) {
                                      cookie = cookie.substring(
                                          0, cookie.length - 2);
                                    }

                                    if (cookie
                                        .contains('passport_assist_user')) {
                                      // 复制到剪贴板
                                      Clipboard.setData(
                                          ClipboardData(text: cookie));
                                      showToast("已把登录信息已复制，请前往粘贴");
                                    } else {
                                      showToast("您尚未登录抖音，请先在该页面登录抖音");
                                    }
                                  },
                                  child: Text(
                                    "我已登录",
                                    style: TextStyle(
                                      color: ColorsApp.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    shape: StadiumBorder(),
                                  ).copyWith(
                                    padding: MaterialStateProperty.all(
                                        const EdgeInsets.all(0)),
                                    backgroundColor: MaterialStateProperty.all(
                                        ColorsApp.teal_200),
                                    elevation: MaterialStateProperty.all(0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
          ],
        ),
      ),
    );
  }

  _buildDyWebView() {
    // lLog('ScriptPage._buildDyWebView } ${controller.dyUrl.value}');
    return SafeArea(
      child: Obx(() => controller.dyUrl.value.isEmpty
          ? Container()
          : webview.InAppWebView(
              // windowId: Random().nextInt(100),
              webViewEnvironment: WebView2EnvManager.instance.environment,
              onWebViewCreated: (webview.InAppWebViewController c) {
                controller.webViewController = c;
              },
              initialUrlRequest: webview.URLRequest(
                  url: webview.WebUri.uri(Uri.parse(controller.dyUrl.value))),
              initialSettings: webview.InAppWebViewSettings(
                cacheEnabled: false,
                // useWideViewPort: true,
                // loadWithOverviewMode: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,                          // 登录弹窗 JS 依赖 localStorage
                useWideViewPort: true,                            // 桌面版页面正确缩放
                loadWithOverviewMode: true,                       // 页面适配小屏
                textZoom: 100,                                    // 禁止文字缩放，保证弹窗精确
                useHybridComposition: true,                       // ★★★ 关键：旧设备 WebView 硬件渲染修复
                supportZoom: true,
                builtInZoomControls: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: true,
                // textZoom: 100,
                //
                // useShouldOverrideUrlLoading: true,
                // supportZoom: true,
                // builtInZoomControls: false,
                // displayZoomControls: false,

                // useWideViewPort: false, // 禁用宽视口模式
                // initialScale: 300,      // 设置初始缩放比例
                // builtInZoomControls: true,
                // displayZoomControls: true,
                userAgent:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',

                // userAgent:
                // 'Mozilla/5.0 (Linux; Android 14; 23113RN4C Build/UKQ1.230923.003) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36',
              ),
              // onLoadStop: (webview.InAppWebViewController controller, webview.WebUri? url) async {
              //   await controller.evaluateJavascript(
              //     source: '''
              //       (function() {
              //         try {
              //           var style = document.createElement('style');
              //           style.innerHTML = 'html, body { -webkit-text-size-adjust: 100% !important; text-size-adjust: 100% !important; }';
              //           document.head.appendChild(style);
              //           var hasViewport = !!document.querySelector('meta[name="viewport"]');
              //           if (!hasViewport) {
              //             var meta = document.createElement('meta');
              //             meta.name = 'viewport';
              //             meta.content = 'initial-scale=1, maximum-scale=1, user-scalable=no';
              //             document.head.appendChild(meta);
              //           }
              //         } catch (e) {}
              //       })();
              //     ''',
              //   );
              // },
            )),
    );
  }
}
