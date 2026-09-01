import 'package:code_zero/network/convert_interface.dart';
import 'package:code_zero/network/l_request.dart';

class CookieManagerUtils {
  static const int DY_COOKIE = 1;
  static const int KS_COOKIE = 2;

  static Future<bool> clearAllCookies() async {
    var result = await LRequest.instance.request<CookieResponse>(
      path: "/cookie",
      requestType: RequestType.POST,
      data: {"platformType": DY_COOKIE, "cookie": ''},
      isShowLoading: true,
      isShowLog: true,
    );

    var ksResult = await LRequest.instance.request<CookieResponse>(
      path: "/cookie",
      requestType: RequestType.POST,
      data: {"platformType": KS_COOKIE, "cookie": ''},
      isShowLoading: true,
      isShowLog: false,
    );
    return result != null && ksResult != null;
  }

  /// 保存或更新用户 Cookie
  /// platformType: 平台类型，1-抖音，2-快手
  /// cookie: Cookie 内容
  static Future<bool> saveOrUpdateCookie(
      int platformType, String cookie) async {
    var result = await LRequest.instance.request<CookieResponse>(
      path: "/cookie",
      requestType: RequestType.POST,
      data: {"platformType": platformType, "cookie": cookie},
      isShowLoading: true,
      isShowLog: false,
    );
    return result != null;
  }

  /// 根据平台类型查询用户 Cookie
  /// platformType: 平台类型，1-抖音，2-快手
  static Future<CookieResponse?> getCookie(int platformType) async {
    var result = await LRequest.instance.request<CookieResponse>(
      path: "/cookie",
      t: CookieResponse(),
      requestType: RequestType.GET,
      queryParameters: {"platformType": platformType},
      isShowLoading: false,
      isShowLog: true,
    );
    return result?.value;
  }
}

/// Cookie 响应模型
class CookieResponse implements ConvertInterface<CookieResponse> {
  int? id;
  int? userId;
  int? platformType;
  String? cookie;
  String? createTime;
  String? updateTime;

  CookieResponse({
    this.id,
    this.userId,
    this.platformType,
    this.cookie,
    this.createTime,
    this.updateTime,
  });

  @override
  CookieResponse fromJson(Map<String, dynamic> json) {
    return CookieResponse(
      id: json['id'],
      userId: json['userId'],
      platformType: json['platformType'],
      cookie: json['cookie'],
      createTime: json['createTime'],
      updateTime: json['updateTime'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'platformType': platformType,
      'cookie': cookie,
      'createTime': createTime,
      'updateTime': updateTime,
    };
  }
}
