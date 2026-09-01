// ignore_for_file: constant_identifier_names

class Apis {
  static const String PREFIX = "/user";

  // static const String GET_INFO =  PREFIX + "/get_info";
  static const String HAS_PASSWORD = PREFIX + "/hasPassword/v2";
  static const String BIND = PREFIX + "/bind-from-user";
  static const String PHONE_LOGIN = PREFIX + "/phone-login";
  static const String SMS = "/user/forget/sendSms"; // api 用 v2，api2 用这个
  static const String IDENTITIY_CHECK = "/open-api/identity-check";
  static const String LOG_OUT = "/user/logout";
  static const String REGISTER_SMS = "/user/register/sendSms";

  static const String UPLOAD = "/file/uploads";
  static const String UPDATE_INFO = PREFIX + "/update-info";

  static const String UPDATE_PASSWORD = PREFIX + "/update-password";

  static const String UPDATE_SIGNATURE = PREFIX + "/update-signature";

  static const String SYSTEM_SETTING = "/system-setting/get";

  static const String APP_VERSION = "/app-version/get-latest-version";
  static const String RED_ENVELOPE = "/red-envelope/info";
  static const String RED_ENVELOPE_TASK = "/red-envelope/task-info";
  static const String RED_ENVELOPE_REWARD = "/red-envelope/record-list";

  static const String COMMODITY_CATEGORY = "/commodity-category/list";

  static const String ROOM_ALL = "/bind/live/room/v2/all";
  static const String BIND_LIVE_ROOM = "/bind/live/room/v2";
  static const String USER_SCRIPT = "/user/script";
  static const String USER_SCRIPT_DELETE = "/user/script";
  static const String KEYWORD_ALL = "/user/keyword2/v2/all";
  static const String LAST_UPDATE_TIME_2 = "/user/keyword2/lastUpdateTime";
  static const String KEYWORD_TYPE = "/user/keyword/type/v6";
  static const String MENU_SHOW = "/user/menu/show";
  static const String AUDIO_LIB = "/app/config/audio/lib";
  static const String VIDEO_LIB = "/app/config/video/lib";
  static const String DOUYIN_LOGIN = "/app/config/login/douyin";
  static const String PERMISSION_IMAGE = "/app/config/permission/image";
  static const String ALI_CREDENTIALS = "/ali/credentials/v2";
  static const String TRANSFORM_VIDEO = "/ali/transform/video/v3";
  static const String SAVE_KEYWORD = "/user/keyword2";
}
