import 'package:code_zero/common/components/confirm_dialog.dart';
import 'package:code_zero/common/user_apis.dart';
import 'package:code_zero/utils/cookie_manager_utils.dart';
import 'package:code_zero/utils/log_utils.dart';
import 'package:code_zero/utils/sp_helper.dart';
import 'package:code_zero/utils/webview2_env_manager.dart';
import 'package:get/get.dart';
import 'package:code_zero/common/components/status_page/status_page.dart';
import 'package:code_zero/network/l_request.dart';
import 'package:code_zero/network/convert_interface.dart';
import 'package:code_zero/utils/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;

class DouyinLoginController extends GetxController {
  final pageName = 'DouyinLogin'.obs;
  final errorMsg = "".obs;
  final pageStatus = FTStatusPageType.loading.obs;

  //ScrollController scrollController = ScrollController();
  //RxList<InviteRecordDto?> inviteProductList = RxList<InviteRecordDto?>();
  final RefreshController refreshController = new RefreshController();

  int currentPage = 0;

  var dyCookie = ''.obs;
  var dyUrl = ''.obs;
  final loginUrls = <DouyinLoginUrl>[].obs;

  webview.InAppWebViewController? webViewController;

  @override
  void onInit() {
    super.onInit();
    initData();
  }

  initData() {
    pageStatus.value = FTStatusPageType.success;

    dyUrl.value = 'https://doujia.douyin.com/login';
    _initHardcodedLoginUrls();
  }

  void _initHardcodedLoginUrls() {
    final hardcodedList = [
      DouyinLoginUrl(title: '登录方式1', url: 'https://www.douyin.com/user/self'),
      DouyinLoginUrl(title: '登录方式2', url: 'https://anchor.douyin.com/login'),
      DouyinLoginUrl(title: '登录方式3', url: 'https://creator.douyin.com'),
      DouyinLoginUrl(title: '登录方式4', url: 'https://doujia.douyin.com/login'),
    ];
    loginUrls.assignAll(hardcodedList.where((e) => e.url.isNotEmpty));
    if (loginUrls.isNotEmpty) {
      final savedUrl = SpHelper.getDouyinLoginUrl();
      final savedItem = loginUrls
          .firstWhereOrNull((item) => item.url == savedUrl);
      loadLoginUrl((savedItem ?? loginUrls.first).url);
    }
  }

  void setPageName(String newName) {
    pageName.value = newName;
  }

  @override
  void onClose() {}

  Future<void> clearCookie() async {
    var cookieManager = WebView2EnvManager.instance.cookieManager;
    await cookieManager.deleteAllCookies();

    dyCookie.value = '';
    dyCookie.refresh();
  }

  Future<bool> saveCookie() async {
    var cookieManager = WebView2EnvManager.instance.cookieManager;
    var cookies = await cookieManager.getCookies(
        url: webview.WebUri.uri(Uri.parse("https://www.douyin.com")));

    if (cookies.isEmpty) {
      return false;
    }

    String cookie = '';
    for (var co in cookies) {
      cookie += '${co.name}=${co.value}; ';
    }
    if (cookie.isNotEmpty) {
      cookie = cookie.substring(0, cookie.length - 2);
    }

    if (cookie.contains('passport_assist_user')) {
      dyCookie.value = cookie;
      await SpHelper.setDyCookie(cookie);
      lLog('DouyinLoginController.saveCookie 已保存抖音 Cookie 到本地存储 $cookie');
      return true;
    }
    return false;
  }

  void selectLoginUrl(DouyinLoginUrl item) {
    SpHelper.setDouyinLoginUrl(item.url);
    loadLoginUrl(item.url);
  }

  void loadLoginUrl(String url) {
    if (url.isEmpty || dyUrl.value == url) return;
    dyUrl.value = url;
    webViewController?.loadUrl(
        urlRequest: webview.URLRequest(url: webview.WebUri.uri(Uri.parse(url))));
  }
}

class DouyinLoginConfig extends ConvertInterface {
  List<DouyinLoginUrl> loginOptions = [];

  @override
  DouyinLoginConfig fromJson(Map<String, dynamic> json) {
    return DouyinLoginConfig()
      ..loginOptions = ((json['loginOptions'] ?? []) as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => DouyinLoginUrl().fromJson(item))
          .toList();
  }

  @override
  Map<String, dynamic> toJson() => {
        'loginOptions': loginOptions.map((item) => item.toJson()).toList(),
      };
}

class DouyinLoginUrl extends ConvertInterface {
  String title = '';
  String url = '';

  DouyinLoginUrl({this.title = '', this.url = ''});

  @override
  DouyinLoginUrl fromJson(Map<String, dynamic> json) {
    final value = json['url'] ?? json['link'] ?? json['href'] ?? '';
    return DouyinLoginUrl(
      title: (json['title'] ?? json['name'] ?? value).toString(),
      url: value.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {'title': title, 'url': url};
}
