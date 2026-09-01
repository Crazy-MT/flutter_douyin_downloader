import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:code_zero/utils/cookie_manager_utils.dart';
import 'package:flutter/services.dart';

class DouyinUserApi {
  DouyinUserApi({
    required String cookie,
    required this.secUserId,
    DouyinUserApiSignatureGenerator? signatureGenerator,
  })  : _cookies = DouyinUserCookieJar.from(cookie),
        _signatureGenerator =
            signatureGenerator ?? DouyinUserApiSignatureGenerator.asset() {
    _httpClient.userAgent = _headers['User-Agent'];
    _httpClient.connectionTimeout = const Duration(seconds: 30);
  }

  static const _host = 'https://www.douyin.com';
  static const _web2Host = 'https://www-hj.douyin.com';

  static Future<DouyinUserApi?> fromSavedDouyinCookie({
    required String secUserId,
  }) async {
    final cookie = await CookieManagerUtils.getCookie(
      CookieManagerUtils.DY_COOKIE,
    );
    final value = cookie?.cookie ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DouyinUserApi(cookie: value, secUserId: secUserId);
  }

  final String secUserId;
  final DouyinUserCookieJar _cookies;
  final DouyinUserApiSignatureGenerator _signatureGenerator;
  final HttpClient _httpClient = HttpClient();
  String _webid = '';

  final LinkedHashMap<String, String> _baseParams = LinkedHashMap.of({
    'device_platform': 'webapp',
    'aid': '6383',
    'channel': 'channel_pc_web',
    'update_version_code': '170400',
    'pc_client_type': '1',
    'version_code': '190500',
    'version_name': '19.5.0',
    'cookie_enabled': 'true',
    'screen_width': '2560',
    'screen_height': '1440',
    'browser_language': 'zh-CN',
    'browser_platform': 'Win32',
    'browser_name': 'Chrome',
    'browser_version': '126.0.0.0',
    'browser_online': 'true',
    'engine_name': 'Blink',
    'engine_version': '126.0.0.0',
    'os_name': 'Windows',
    'os_version': '10',
    'cpu_core_num': '24',
    'device_memory': '8',
    'platform': 'PC',
    'downlink': '10',
    'effective_type': '4g',
    'round_trip_time': '50',
  });

  final LinkedHashMap<String, String> _headers = LinkedHashMap.of({
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'sec-fetch-site': 'same-origin',
    'sec-fetch-mode': 'cors',
    'sec-fetch-dest': 'empty',
    'sec-ch-ua-platform': 'Windows',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua':
        '"Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"',
    'referer': 'https://www.douyin.com/?recommend=1',
    'priority': 'u=1, i',
    'pragma': 'no-cache',
    'cache-control': 'no-cache',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'accept': 'application/json, text/plain, */*',
    'dnt': '1',
  });

  Future<DouyinUserApiOverview> overview({int count = 18}) async {
    final profile = await userProfile();
    final posts = await userPosts(count: count);
    final favorites = await userFavorites(count: count);
    return DouyinUserApiOverview(
      secUserId: secUserId,
      profile: profile,
      posts: posts,
      favorites: favorites,
    );
  }

  Future<Map<String, dynamic>> userProfile() {
    return _getJson(
      uri: '/aweme/v1/web/user/profile/other/',
      params: LinkedHashMap.of({
        'sec_user_id': secUserId,
        'source': 'channel_pc_web',
        'publish_video_strategy_type': '2',
        'personal_center_strategy': '1',
      }),
      referer: 'https://www.douyin.com/user/$secUserId?',
    );
  }

  Future<Map<String, dynamic>> userPosts({int count = 10}) {
    return _getJson(
      uri: '/aweme/v1/web/aweme/post/',
      params: LinkedHashMap.of({
        'sec_user_id': secUserId,
        'count': '$count',
        'max_cursor': '0',
        'locate_item_id': '',
        'locate_query': 'false',
        'forward_anchor_cursor': '',
        'show_live_replay_strategy': '1',
        'need_time_list': '1',
        'locate_item_cursor': '',
        'time_list_query': '0',
        'publish_video_strategy_type': '2',
      }),
      referer: 'https://www.douyin.com/user/$secUserId?',
    );
  }

  Future<Map<String, dynamic>> userFavorites({int count = 10}) async {
    final response = await _getJson(
      uri: '/aweme/v1/web/aweme/favorite/',
      params: LinkedHashMap.of({
        'sec_user_id': secUserId,
        'count': '$count',
        'max_cursor': '0',
        'min_cursor': '0',
        'whale_cut_token': '',
        'cut_version': '1',
        'publish_video_strategy_type': '2',
      }),
      referer: 'https://www.douyin.com/',
      web2: true,
      requiresWebSign: true,
    );
    if (response['status_code'] == 0 && response['aweme_list'] == null) {
      response['aweme_list'] = <dynamic>[];
    }
    return response;
  }

  void close() {
    _httpClient.close(force: true);
  }

  Future<Map<String, dynamic>> _getJson({
    required String uri,
    required LinkedHashMap<String, String> params,
    required String referer,
    bool web2 = false,
    bool requiresWebSign = false,
  }) async {
    final baseUrl = '${web2 ? _web2Host : _host}$uri';
    Map<String, dynamic> lastResponse = {};
    for (var attempt = 1; attempt <= 3; attempt++) {
      final signedParams = await _withCommonParams(params);
      if (requiresWebSign) {
        signedParams.remove('uifid');
      }
      signedParams['a_bogus'] =
          await _signatureGenerator.generate(_urlWithQuery(baseUrl, signedParams));
      if (requiresWebSign) {
        _appendCookieBackedWebSign(signedParams);
      }

      final url = Uri.parse(_urlWithQuery(baseUrl, signedParams));
      final headers = LinkedHashMap<String, String>.of(_headers);
      headers['referer'] = referer;
      if (web2) {
        headers['sec-fetch-site'] = 'same-site';
        headers['origin'] = _host;
        headers['bd-ticket-guard-version'] = '2';
        headers['bd-ticket-guard-web-version'] = '2';
        headers['bd-ticket-guard-web-sign-type'] = '1';
        final ticketData = _cookies.value('bd_ticket_guard_client_data_v2');
        if (ticketData.isNotEmpty) {
          headers['bd-ticket-guard-client-data'] = ticketData;
          final reeKey = _decodeReePublicKey(ticketData);
          if (reeKey.isNotEmpty) {
            headers['bd-ticket-guard-ree-public-key'] = reeKey;
          }
        }
        final uifid = signedParams['uifid'];
        if (uifid != null && uifid.isNotEmpty) {
          headers['uifid'] = uifid;
        }
      }

      final response = await _sendGet(url, headers);
      response['_attempt'] = attempt;
      lastResponse = response;
      if (!_isSignInvalid(response)) {
        return response;
      }
    }
    return lastResponse;
  }

  Future<Map<String, dynamic>> _sendGet(
    Uri url,
    LinkedHashMap<String, String> headers,
  ) async {
    final request = await _httpClient.getUrl(url);
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.cookieHeader, _cookies.header);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (body.isEmpty) {
      return {
        '_http_status': response.statusCode,
        '_request_url': url.toString(),
      };
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        decoded['_http_status'] = response.statusCode;
        return decoded;
      }
      return {
        '_http_status': response.statusCode,
        'data': decoded,
      };
    } catch (_) {
      return {
        '_http_status': response.statusCode,
        '_request_url': url.toString(),
        'error': 'Invalid JSON response',
        'raw': body.length > 500 ? body.substring(0, 500) : body,
      };
    }
  }

  bool _isSignInvalid(Map<String, dynamic> response) {
    return response['_http_status'] == 403 &&
        response['raw'] is String &&
        (response['raw'] as String).contains('ArgusSecurityPlugin Sign Invalid');
  }

  Future<LinkedHashMap<String, String>> _withCommonParams(
    LinkedHashMap<String, String> params,
  ) async {
    final out = LinkedHashMap<String, String>.of(params);
    out.addAll(_baseParams);
    out['msToken'] = _msToken();
    out['screen_width'] = _cookies.value('dy_swidth', fallback: '2560');
    out['screen_height'] = _cookies.value('dy_sheight', fallback: '1440');
    out['cpu_core_num'] = _cookies.value('device_web_cpu_core', fallback: '24');
    out['device_memory'] = _cookies.value('device_web_memory_size', fallback: '8');
    final fp = _cookies.value('s_v_web_id');
    if (fp.isNotEmpty) {
      out['verifyFp'] = fp;
      out['fp'] = fp;
    }
    final uifid = _cookies.value('UIFID');
    if (uifid.isNotEmpty) {
      out['uifid'] = uifid;
    }
    out['webid'] = await _getWebid();
    return out;
  }

  Future<String> _getWebid() async {
    if (_webid.isNotEmpty) {
      return _webid;
    }
    final request = await _httpClient.getUrl(Uri.parse('$_host/?recommend=1'));
    final headers = LinkedHashMap<String, String>.of(_headers);
    headers['sec-fetch-dest'] = 'document';
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.cookieHeader, _cookies.header);
    final response = await request.close();
    final html = await response.transform(utf8.decoder).join();
    final match = RegExp(r'\\"user_unique_id\\":\\"(\d+)\\"').firstMatch(html);
    _webid = match?.group(1) ?? '';
    return _webid;
  }

  String _msToken() {
    final fromCookie = _cookies.value('msToken');
    if (fromCookie.isNotEmpty) {
      return fromCookie;
    }
    const chars =
        'ABCDEFGHIGKLMNOPQRSTUVWXYZabcdefghigklmnopqrstuvwxyz0123456789=';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(120, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _appendCookieBackedWebSign(LinkedHashMap<String, String> params) {
    final uifid = _cookies.value('UIFID');
    final signature = _cookies.value('x-secsdk-web-signature');
    final timestamp = _cookies.value('timestamp');
    if (uifid.isNotEmpty) {
      params['uifid'] = uifid;
    }
    if (timestamp.isNotEmpty) {
      params['timestamp'] = timestamp;
    }
    if (signature.isNotEmpty) {
      params['x-secsdk-web-signature'] = signature;
    }
  }
}

class DouyinUserApiOverview {
  DouyinUserApiOverview({
    required this.secUserId,
    required this.profile,
    required this.posts,
    required this.favorites,
  });

  final String secUserId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> posts;
  final Map<String, dynamic> favorites;

  Map<String, dynamic> toJson() => {
        'sec_user_id': secUserId,
        'profile': profile,
        'posts': posts,
        'favorites': favorites,
      };
}

class DouyinUserCookieJar {
  DouyinUserCookieJar(this.values);

  factory DouyinUserCookieJar.from(String input) {
    return DouyinUserCookieJar(_normalizeCookie(input));
  }

  final Map<String, String> values;

  String get header {
    return values.entries
        .where((entry) => entry.key.isNotEmpty)
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  String value(String key, {String fallback = ''}) {
    final value = values[key];
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return value;
  }
}

class DouyinUserApiSignatureGenerator {
  DouyinUserApiSignatureGenerator._(this._mappingLoader, this._keystreamLoader);

  factory DouyinUserApiSignatureGenerator.asset() {
    return DouyinUserApiSignatureGenerator._(
      () => rootBundle.loadString(
        'assets/douyin_reverse/time_mapping_sample.json',
      ),
      () => rootBundle.loadString(
        'assets/douyin_reverse/FIXED_keystream.json',
      ),
    );
  }

  factory DouyinUserApiSignatureGenerator.raw({
    required String timeMapping,
    required String keystream,
  }) {
    return DouyinUserApiSignatureGenerator._(
      () async => timeMapping,
      () async => keystream,
    );
  }

  static const _s4Table =
      'Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe';

  final Future<String> Function() _mappingLoader;
  final Future<String> Function() _keystreamLoader;
  Map<int, List<int>>? _timeMap;
  List<int>? _sortedTimes;
  List<int>? _keystream;

  Future<String> generate(String url, {int? timestamp}) async {
    await _ensureLoaded();
    final t = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final bb = Uint8List.fromList(_lookupBb(t));
    final keystream = _keystream!;
    final encrypted = Uint8List(bb.length);
    for (var i = 0; i < bb.length; i++) {
      encrypted[i] = bb[i] ^ keystream[i % keystream.length];
    }
    final random = Random.secure();
    final data = <int>[
      for (var i = 0; i < 4; i++) random.nextInt(256),
      ...encrypted,
    ];
    return _s4Encode(data);
  }

  Future<void> _ensureLoaded() async {
    if (_timeMap != null && _sortedTimes != null && _keystream != null) {
      return;
    }
    final rawMap = jsonDecode(await _mappingLoader());
    final timeMap = <int, List<int>>{};
    if (rawMap is Map) {
      for (final entry in rawMap.entries) {
        final list = entry.value as List;
        timeMap[int.parse(entry.key.toString())] =
            list.map((value) => (value as num).toInt()).toList();
      }
    }
    final sortedTimes = timeMap.keys.toList()..sort();
    final keyData = jsonDecode(await _keystreamLoader());
    final keystream = (keyData['bb_keystream'] as List)
        .map((value) => (value as num).toInt())
        .toList();
    _timeMap = timeMap;
    _sortedTimes = sortedTimes;
    _keystream = keystream;
  }

  List<int> _lookupBb(int timestamp) {
    final timeMap = _timeMap!;
    final sortedTimes = _sortedTimes!;
    if (timeMap.containsKey(timestamp)) {
      return timeMap[timestamp]!;
    }
    if (timestamp < sortedTimes.first) {
      return timeMap[sortedTimes.first]!;
    }
    if (timestamp > sortedTimes.last) {
      return timeMap[sortedTimes.last]!;
    }

    var left = 0;
    var right = sortedTimes.length - 1;
    while (right - left > 1) {
      final mid = (left + right) ~/ 2;
      if (sortedTimes[mid] < timestamp) {
        left = mid;
      } else {
        right = mid;
      }
    }
    final t1 = sortedTimes[left];
    final t2 = sortedTimes[right];
    final closest = (timestamp - t1).abs() < (timestamp - t2).abs() ? t1 : t2;
    return timeMap[closest]!;
  }

  String _s4Encode(List<int> data) {
    final result = StringBuffer();
    var i = 0;
    while (i < data.length) {
      if (i + 2 < data.length) {
        final b1 = data[i];
        final b2 = data[i + 1];
        final b3 = data[i + 2];
        result
          ..write(_s4Table[(b1 >> 2) & 0x3f])
          ..write(_s4Table[((b1 << 4) | (b2 >> 4)) & 0x3f])
          ..write(_s4Table[((b2 << 2) | (b3 >> 6)) & 0x3f])
          ..write(_s4Table[b3 & 0x3f]);
        i += 3;
      } else if (i + 1 < data.length) {
        final b1 = data[i];
        final b2 = data[i + 1];
        result
          ..write(_s4Table[(b1 >> 2) & 0x3f])
          ..write(_s4Table[((b1 << 4) | (b2 >> 4)) & 0x3f])
          ..write(_s4Table[(b2 << 2) & 0x3f]);
        i += 2;
      } else {
        final b1 = data[i];
        result
          ..write(_s4Table[(b1 >> 2) & 0x3f])
          ..write(_s4Table[(b1 << 4) & 0x3f]);
        i += 1;
      }
    }
    return result.toString();
  }
}

Map<String, String> _normalizeCookie(dynamic input) {
  dynamic value = input;
  for (var i = 0; i < 10; i++) {
    if (value is Map) {
      if (value.isEmpty) {
        return {};
      }
      if (_looksFlatCookie(value)) {
        return {
          for (final entry in value.entries)
            if (entry.key.toString().isNotEmpty)
              entry.key.toString(): entry.value?.toString() ?? '',
        };
      }
      final keys = value.keys.toList();
      if (keys.length <= 2 && keys.first.toString().trimLeft().startsWith('{')) {
        final candidate = keys.first.toString();
        final tail = value[keys.first].toString();
        var decodedMalformed = false;
        for (final attempt in [candidate, '$candidate"$tail"}', '$candidate$tail']) {
          try {
            value = jsonDecode(attempt);
            decodedMalformed = true;
            break;
          } catch (_) {
            // Try the next historical malformed-cookie shape.
          }
        }
        if (decodedMalformed) {
          continue;
        }
      }
      return {
        for (final entry in value.entries)
          if (entry.key.toString().isNotEmpty)
            entry.key.toString(): entry.value?.toString() ?? '',
      };
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('"')) {
        try {
          value = jsonDecode(trimmed);
          continue;
        } catch (_) {
          return _cookieStringToMap(trimmed);
        }
      }
      return _cookieStringToMap(trimmed);
    }
    return {};
  }
  return {};
}

bool _looksFlatCookie(Map<dynamic, dynamic> value) {
  if (value.containsKey('sessionid') || value.containsKey('ttwid')) {
    return true;
  }
  for (final key in value.keys) {
    final s = key.toString();
    if (s.length > 120 || s.trimLeft().startsWith('{')) {
      return false;
    }
  }
  return true;
}

Map<String, String> _cookieStringToMap(String cookie) {
  final out = <String, String>{};
  for (final part in cookie.split(';')) {
    final trimmed = part.trim();
    final index = trimmed.indexOf('=');
    if (trimmed.isEmpty || trimmed == 'douyin.com' || index <= 0) {
      continue;
    }
    out[trimmed.substring(0, index).trim()] = trimmed.substring(index + 1);
  }
  return out;
}

String _decodeReePublicKey(String clientData) {
  try {
    var padded = clientData;
    final missing = padded.length % 4;
    if (missing != 0) {
      padded += '=' * (4 - missing);
    }
    final decoded = utf8.decode(base64.decode(padded));
    final parsed = jsonDecode(decoded);
    if (parsed is Map && parsed['ree_public_key'] != null) {
      return parsed['ree_public_key'].toString();
    }
  } catch (_) {
    return '';
  }
  return '';
}

String _urlWithQuery(String baseUrl, LinkedHashMap<String, String> params) {
  final query = params.entries
      .map((entry) => '${entry.key}=${_quote(entry.value)}')
      .join('&');
  return '$baseUrl?$query';
}

String _quote(String value) {
  return Uri.encodeComponent(value).replaceAll('%20', '%20');
}
