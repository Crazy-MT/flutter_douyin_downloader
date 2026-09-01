import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'abogus_signer.dart';
import 'douyin_endpoint.dart';

class DouyinResult {
  DouyinResult({
    required this.statusCode,
    required this.url,
    required this.body,
    required this.elapsed,
    this.warning,
  });

  final int statusCode;
  final String url;
  final String body;
  final Duration elapsed;
  final String? warning;
}

class DouyinRequest {
  DouyinRequest(this._signer);

  final ABogusSigner _signer;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  String _webid = '';

  static const _hosts = {
    DouyinHost.www: 'https://www.douyin.com',
    DouyinHost.live: 'https://live.douyin.com',
    DouyinHost.web2: 'https://www-hj.douyin.com',
  };

  static const _baseParams = {
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
  };

  Future<DouyinResult> send(DouyinEndpoint endpoint, Map<String, String> input,
      String cookieText) async {
    final cookies = _parseCookies(cookieText);
    final params = <String, String>{
      ...endpoint.defaults,
      ...input,
      ..._baseParams,
      'msToken': cookies['msToken'] ?? _randomToken(),
      'screen_width': cookies['dy_swidth'] ?? '2560',
      'screen_height': cookies['dy_sheight'] ?? '1440',
      'cpu_core_num': cookies['device_web_cpu_core'] ?? '24',
      'device_memory': cookies['device_web_memory_size'] ?? '8',
      if (cookies['s_v_web_id'] != null) 'verifyFp': cookies['s_v_web_id']!,
      if (cookies['s_v_web_id'] != null) 'fp': cookies['s_v_web_id']!,
      if (!endpoint.needsWebSign && cookies['UIFID'] != null)
        'uifid': cookies['UIFID']!,
    }..removeWhere((_, value) => value.trim().isEmpty);

    params['webid'] = await _getWebid(cookies);
    params['a_bogus'] = await _signer.generate();

    final host = _hosts[endpoint.host]!;
    final requestUri = Uri.parse('$host${endpoint.remoteUri}')
        .replace(queryParameters: params);
    final headers = _headers(endpoint, params, cookies);
    final body = {
      for (final key in endpoint.bodyParams)
        if ((input[key] ?? endpoint.defaults[key] ?? '').trim().isNotEmpty)
          key: input[key] ?? endpoint.defaults[key]!,
    };

    final started = DateTime.now();
    final request = await (endpoint.method == EndpointMethod.post
        ? _client.postUrl(requestUri)
        : _client.getUrl(requestUri));
    headers.forEach(request.headers.set);
    if (cookieText.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookieText.trim());
    }
    if (endpoint.method == EndpointMethod.post) {
      request.headers.set(
          HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
      request.write(Uri(queryParameters: body).query);
    }

    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return DouyinResult(
      statusCode: response.statusCode,
      url: requestUri.toString(),
      body: _prettyJson(text),
      elapsed: DateTime.now().difference(started),
      warning: endpoint.needsWebSign
          ? '这个接口在 Python 版里还会补 x-secsdk-web-signature；Dart 端当前只生成 a_bogus，失败时请用 Node 签名代理补齐。'
          : null,
    );
  }

  Map<String, String> _headers(DouyinEndpoint endpoint,
      Map<String, String> params, Map<String, String> cookies) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'sec-fetch-site':
          endpoint.host == DouyinHost.web2 ? 'same-site' : 'same-origin',
      'sec-fetch-mode': 'cors',
      'sec-fetch-dest': 'empty',
      'sec-ch-ua-platform': 'Windows',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua':
          '"Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"',
      'referer': _referer(endpoint.remoteUri, params),
      'priority': 'u=1, i',
      'pragma': 'no-cache',
      'cache-control': 'no-cache',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'accept': 'application/json, text/plain, */*',
      'dnt': '1',
    };
    if (endpoint.host == DouyinHost.web2) {
      headers['origin'] = 'https://www.douyin.com';
      headers['bd-ticket-guard-version'] = '2';
      headers['bd-ticket-guard-web-version'] = '2';
      headers['bd-ticket-guard-web-sign-type'] = '1';
      final data = cookies['bd_ticket_guard_client_data_v2'];
      if (data != null && data.isNotEmpty) {
        headers['bd-ticket-guard-client-data'] = data;
      }
      final uifid = params['uifid'];
      if (uifid != null) headers['uifid'] = uifid;
    }
    return headers;
  }

  String _referer(String uri, Map<String, String> params) {
    return switch (uri) {
      '/aweme/v1/web/aweme/related/' =>
        'https://www.douyin.com/video/${params['aweme_id'] ?? ''}',
      '/aweme/v1/web/comment/list/' =>
        'https://www.douyin.com/video/${params['aweme_id'] ?? ''}',
      '/aweme/v1/web/comment/list/reply/' =>
        'https://www.douyin.com/video/${params['item_id'] ?? ''}',
      '/aweme/v1/web/user/profile/other/' =>
        'https://www.douyin.com/user/${params['sec_user_id'] ?? ''}?',
      '/aweme/v1/web/aweme/post/' =>
        'https://www.douyin.com/user/${params['sec_user_id'] ?? ''}?',
      '/aweme/v1/web/locate/post/' ||
      '/aweme/v1/web/aweme/favorite/' =>
        'https://www.douyin.com/',
      '/aweme/v2/web/module/feed/' => 'https://www.douyin.com/jingxuan',
      _
          when uri.contains('/collects/') ||
              uri.contains('/listcollection/') ||
              uri.contains('/series/collections') =>
        'https://www.douyin.com/user/self?from_tab_name=main&showTab=favorite_collection',
      _ => 'https://www.douyin.com/?recommend=1',
    };
  }

  Future<String> _getWebid(Map<String, String> cookies) async {
    if (_webid.isNotEmpty) return _webid;
    try {
      final request = await _client
          .getUrl(Uri.parse('https://www.douyin.com/?recommend=1'));
      if (cookies.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader,
            cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }
      final response = await request.close();
      final html = await utf8.decodeStream(response);
      final match =
          RegExp(r'\\?"user_unique_id\\?":\\?"(\d+)\\?"').firstMatch(html);
      _webid = match?.group(1) ?? '';
    } catch (_) {
      _webid = '';
    }
    return _webid;
  }

  Map<String, String> _parseCookies(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return {};
    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, '$value'));
    }
    return {
      for (final part in trimmed.split(';'))
        if (part.contains('='))
          part.split('=')[0].trim():
              part.substring(part.indexOf('=') + 1).trim(),
    };
  }

  String _randomToken() {
    const chars =
        'ABCDEFGHIGKLMNOPQRSTUVWXYZabcdefghigklmnopqrstuvwxyz0123456789=';
    final random = Random.secure();
    return List.generate(120, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  String _prettyJson(String text) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(text));
    } catch (_) {
      return text;
    }
  }
}
