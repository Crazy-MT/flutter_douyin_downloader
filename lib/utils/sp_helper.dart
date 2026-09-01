import 'dart:convert';
import 'dart:io';

import 'package:code_zero/common/C.dart';
import 'package:code_zero/utils/log_utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:sp_util/sp_util.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SpHelper {
  static const String SP_CHAT_POSITION_X = 'sp_chat_position_x';
  static const String SP_CHAT_POSITION_Y = 'sp_chat_position_y';
  static const String SP_CHAT_HEIGHT = 'chatHeight';
  static const String SP_CHAT_WIDTH = 'sp_chat_width';

  static const String SP_MUSIC_HEIGHT = 'sp_music_height';
  static const String SP_MUSIC_WIDTH = 'sp_music_width';
  static const String SP_MUSIC_POSITION_X = 'sp_music_position_x';
  static const String SP_MUSIC_POSITION_Y = 'sp_music_position_y';

  static const String SP_TELE_HEIGHT = 'sp_tele_height';

  static const String SP_EDIT_PAGE_HEIGHT = 'sp_edit_page_height';
  static const String SP_EDIT_PAGE_WIDTH = 'sp_edit_page_width';
  static const String SP_EDIT_PAGE_POSITION_X = 'sp_edit_page_position_x';
  static const String SP_EDIT_PAGE_POSITION_Y = 'sp_edit_page_position_y';
  static const String SP_DOUYIN_ONE_MENU_BUTTONS = 'sp_douyin_one_menu_buttons';
  static const String SP_DOUYIN_ONE_BOTTOM_MENU_BUTTONS =
      'sp_douyin_one_bottom_menu_buttons';
  static const String SP_DOUYIN_LOGIN_URL = 'sp_douyin_login_url';



  static String getDouyinLoginUrl() {
    return SpUtil.getString(SP_DOUYIN_LOGIN_URL,
        defValue: '') ??
        '';
  }

  static Future<bool>? setDouyinLoginUrl(String url) {
    return SpUtil.putString(SP_DOUYIN_LOGIN_URL, url);
  }


  static String getDyCookie() {
    return SpUtil.getString(C.DOUYIN_COOKIE) ?? '';
  }

  static Future<bool>? setDyCookie(String cookie) {
    return SpUtil.putString(C.DOUYIN_COOKIE, cookie);
  }
}
