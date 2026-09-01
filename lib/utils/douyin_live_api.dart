import 'dart:convert'; // For utf8 and json decoding
import 'dart:io';
import 'package:code_zero/utils/log_utils.dart';
import 'package:code_zero/utils/platform_utils.dart';
import 'package:code_zero/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:sp_util/sp_util.dart';

class DouyinLiveApi {
  // --- Patterns from the previous example ---
  final RegExp _roomIdPattern = RegExp(r'\\"roomId\\":\\"(\d+)\\"');
  final RegExp _userPattern = RegExp(r'\\"user_unique_id\\":\\"(\d+)\\"');
  final RegExp _statusPattern = RegExp(r'\\"status_str\\":\\"([^\"]+)\\"');

  // --- New pattern for Nickname from the current request ---
  // This regex is taken from your Java code. It looks for "nickname":"some value"
  final RegExp _nickNamePattern = RegExp(r'\\"nickname\\":\\"(.+?)\\"');

  // --- Method from the previous example (fetchLiveRoomInfo) would go here ---
  // ...

  http.Client _createHttpClient() {
    if (PlatformUtils.isWeb) return http.Client();
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(httpClient);
  }

  /// Fetches a user's nickname from their Douyin user page.
  ///
  /// This corresponds to the new Java snippet provided.
  /// It takes a user's `webcastId` (the unique string in their profile URL).
  Future<({String nickName, String? pageTitle})> fetchUserNicknameByWebcastId(
      String? webcastId,
      {String? initialCookie}) async {
    final url = Uri.parse('https://live.douyin.com/$webcastId');

    final headMap = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
      // Content-Type is not typically needed for a GET request, but kept for fidelity
      'Content-Type': 'text/plain;charset=UTF-8',
    };

    String? currentCookie = initialCookie;
    http.Response response;
    final client = _createHttpClient();

    try {
      if (currentCookie == null || currentCookie.isEmpty) {
        print(
            "No initial cookie provided, making first request to get cookies.");
        response = await client.get(url, headers: headMap);

        // Extract cookies from the first response
        String? newCookies = _extractCookiesFromHeaders(response.headers);
        if (newCookies != null) {
          headMap['cookie'] = newCookies;
          currentCookie = newCookies;
        }
        print("newCookies:$newCookies");
      } else {
        headMap['cookie'] = currentCookie;
      }
      response = await client.get(url, headers: headMap);

      if (response.statusCode != 200) {
        throw DouyinApiException(
          'Failed to load user page. Status: ${response.statusCode}',
          '',
        );
      }

      final String responseBody = utf8.decode(response.bodyBytes);
      final dom.Document doc = html_parser.parse(responseBody);

      // --- NEW: Call the helper to get the page title ---
      final String? pageTitle = _parsePageTitle(doc);
      print('Page Title Found: ${pageTitle ?? "Not available"}');

      if (pageTitle?.isNotEmpty ?? false) {
        bool isTestMode =
            SpUtil.getBool('isTestMode', defValue: false) ?? false;
        if (isTestMode) {
          Utils.showToastMsg("提示：$pageTitle");
        }
        throw DouyinApiException(
          "'Page Title Found: ${pageTitle}'",
          responseBody,
          code: "DOUYIN_PAGE_TITLE",
          headMap: headMap,
        );
      }

      // 1. Check for system error page
      // The class name ".FV0BvoOn" might be dynamic and could change.
      // This looks for a specific div that indicates an error (e.g., user not found).
      final errorDivs = doc.querySelectorAll(".FV0BvoOn");

      // The Java `parseSystemError` function likely just checks if this element exists.
      if (errorDivs.isNotEmpty) {
        print("Found error indicator div (.FV0BvoOn). User may not exist.");
        throw DouyinApiException(
          "Douyin user not found.",
          responseBody,
          code: "DOUYIN_NUMBER_NOT_FOUND",
          headMap: headMap,
        );
      }

      // 2. Select all script tags to find the nickname
      final scriptElements = doc.querySelectorAll('script');

      // 3. Parse the nickname from the script tags
      final String? nickName = _parseNickName(scriptElements.toList());

      // 4. Validate the result and throw an error if not found
      if (nickName == null || nickName.isEmpty) {
        throw DouyinApiException(
          "Failed to get Douyin nickname, please try again later!",
          '',
          code: "FAILURE",
        );
      }

      return (nickName: nickName, pageTitle: pageTitle);
    } finally {
      client.close();
    }
  }

  /// Fetches live room details from a Douyin live URL.
  ///
  /// Takes an initial [roomIdFromUrl] (the one in the URL, e.g., a username or number)
  /// and an optional existing [cookie] string.
  ///
  /// Returns a Map containing the actual 'liveRoomId' and 'userUniqueId'.
  Future<
          ({
            bool? radioRoom,
            Map<String, String> headMap,
            String liveRoomId,
            String? userUniqueId,
            String? pageTitle,
            bool douyinNeedLogin,
          })>
      fetchLiveRoomInfo(String roomIdFromUrl, {String? initialCookie}) async {
    final headMap = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
      // Content-Type is not typically needed for a GET request, but kept for fidelity
      'Content-Type': 'text/plain;charset=UTF-8',
    };

    bool douyinNeedLogin = false;

    String? currentCookie = initialCookie;

    final url = Uri.parse('https://live.douyin.com/$roomIdFromUrl');

    // --- First Request: To get initial cookies if none are provided ---
    // The Java code seems to perform two requests. The first one is to ensure cookies are set.
    http.Response response;
    final client = _createHttpClient();

    try {
      if (currentCookie == null || currentCookie.isEmpty) {
        print(
            "No initial cookie provided, making first request to get cookies.");
        response = await client.get(url, headers: headMap);

        // Extract cookies from the first response
        String? newCookies = _extractCookiesFromHeaders(response.headers);
        if (newCookies != null) {
          headMap['cookie'] = newCookies;
          currentCookie = newCookies;
        }
        print("newCookies:$newCookies");
      } else {
        headMap['cookie'] = currentCookie;
      }

      // --- Second Request: To get the page content with cookies ---
      print("Making main request to get page content.");
      response = await client.get(url, headers: headMap);

      // Merge any new cookies from the second response
      String? finalCookies = _extractCookiesFromHeaders(response.headers);
      if (finalCookies != null) {
        final mergedCookie = _mergeCookies(currentCookie, finalCookies);
        currentCookie = mergedCookie;
        headMap['cookie'] = mergedCookie;

        print("mergeCookies:$currentCookie");
      }

      if (response.statusCode != 200) {
        throw DouyinApiException(
          "Failed to fetch Douyin page. Status code: ${response.statusCode}",
          '',
        );
      }

      // Decode the response body using UTF-8
      final String responseBody = utf8.decode(response.bodyBytes);

      // lLog('DouyinLiveApi.fetchLiveRoomInfo ${responseBody} ');
      // Parse the HTML document
      final dom.Document doc = html_parser.parse(responseBody);

      if (_hasLoginButtonPrompt(doc)) {
        douyinNeedLogin = true;
        /*throw DouyinApiException(
          'Douyin page requires login.',
          responseBody,
          code: 'DOUYIN_NEED_LOGIN',
          headMap: headMap,
        );*/
      }

      // --- NEW: Call the helper to get the page title ---
      final String? pageTitle = _parsePageTitle(doc);
      print('Page Title Found: ${pageTitle ?? "Not available"}');

      if (pageTitle?.isNotEmpty ?? false) {
        bool isTestMode =
            SpUtil.getBool('isTestMode', defValue: false) ?? false;
        if (isTestMode) {
          Utils.showToastMsg("提示：$pageTitle");
        }
        throw DouyinApiException(
          "'Page Title Found: ${pageTitle}'",
          responseBody,
          code: "DOUYIN_PAGE_TITLE",
          headMap: headMap,
        );
      }

      final List<dom.Element> scriptElements = doc.querySelectorAll('script');

      String? liveRoomId;
      String? userUniqueId;
      // throw DouyinApiException("Stream is not live (status is not '2').", responseBody,
      //     code: "DOUYIN_NUMBER_NOT_LIVE", headMap: headMap);

      for (final script in scriptElements) {
        final String dataHtml = script.innerHtml;

        // Use RegExp to check if the script contains the required data structure
        // (?s) in Java is equivalent to dotAll: true in Dart's RegExp
        final scriptMatch =
            RegExp(r'self.__pace_f\.push\(\[1,"(?:[c-f]|10):', dotAll: true);

        if (scriptMatch.hasMatch(dataHtml)) {
          print("Found matching script tag. Parsing for details...");

          // 3. Extract userUniqueId
          final userMatcher = _userPattern.firstMatch(dataHtml);
          if (userMatcher != null && userMatcher.groupCount >= 1) {
            userUniqueId = userMatcher.group(1);
            print("Found userUniqueId: $userUniqueId");
          } else {
            print(
                "Error: Could not find userUniqueId in script data for URL room ID: $roomIdFromUrl");
            continue;
          }

          if (responseBody.contains('该直播类型或玩法电脑端暂未支持')) {
            // break;
            return (
              radioRoom: true,
              liveRoomId: '',
              userUniqueId:
                  userUniqueId, // We know it's not null due to checks above
              headMap: headMap,
              pageTitle: pageTitle,
              douyinNeedLogin: douyinNeedLogin
            );
          }

          // print(dataHtml);
          // 1. Check live status
          final statusMatcher = _statusPattern.firstMatch(dataHtml);
          if (statusMatcher != null) {
            final status = statusMatcher.group(1);
            print("Found live status: $status");
            if (status != '2') {
              throw DouyinApiException(
                "Stream is not live (status is not '2').",
                responseBody,
                code: "DOUYIN_NUMBER_NOT_LIVE",
                headMap: headMap,
              );
            }
          } else {
            // If status is not found, it might be a different page structure. Continue to the next script.
            print("Live status not found in this script. Checking next...");
            continue;
          }

          // 2. Extract liveRoomId
          final roomIdMatcher = _roomIdPattern.firstMatch(dataHtml);
          if (roomIdMatcher != null && roomIdMatcher.groupCount >= 1) {
            liveRoomId = roomIdMatcher.group(1);
            print("Found liveRoomId: $liveRoomId");
          } else {
            print(
                "Error: Could not find roomId in script data for URL room ID: $roomIdFromUrl");
            // throw DouyinApiException("Could not find liveRoomId.", code: "WWS_DY_ROOM_ID_ERROR");
            continue;
          }

          // Once we found the correct script and data, we can break the loop.
          break;
        }
      }

      // Final check after the loop
      if (liveRoomId == null || liveRoomId.isEmpty) {
        throw DouyinApiException(
          "Stream is not live or room ID could not be found.",
          responseBody,
          code: "DOUYIN_NUMBER_NOT_LIVE",
          headMap: headMap,
        );
      }

      if (userUniqueId == null || userUniqueId.isEmpty) {
        throw DouyinApiException(
          "Could not find userUniqueId.",
          responseBody,
          code: "WWS_DY_ROOM_ID_ERROR",
          headMap: headMap,
        );
      }

      return (
        radioRoom: false,
        liveRoomId: liveRoomId,
        userUniqueId: userUniqueId, // We know it's not null due to checks above
        headMap: headMap,
        pageTitle: pageTitle,
        douyinNeedLogin: douyinNeedLogin,
      );
    } finally {
      client.close();
    }
  }

  Future<
      ({
        Map<String, String> headMap,
        String liveRoomId,
      })> fetchLiveRoomId(String roomUrl, {String? initialCookie}) async {
    final headMap = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
      // Content-Type is not typically needed for a GET request, but kept for fidelity
      'Content-Type': 'text/plain;charset=UTF-8',
    };

    String? currentCookie = initialCookie;

    final url = Uri.parse(roomUrl);

    // --- First Request: To get initial cookies if none are provided ---
    // The Java code seems to perform two requests. The first one is to ensure cookies are set.
    http.Response response;
    final client = _createHttpClient();
    try {
      if (currentCookie == null || currentCookie.isEmpty) {
        print(
            "No initial cookie provided, making first request to get cookies.");
        response = await client.get(url, headers: headMap);

        // Extract cookies from the first response
        String? newCookies = _extractCookiesFromHeaders(response.headers);
        if (newCookies != null) {
          headMap['cookie'] = newCookies;
          currentCookie = newCookies;
        }
        print("newCookies:$newCookies");
      } else {
        headMap['cookie'] = currentCookie;
      }

      // --- Second Request: To get the page content with cookies ---
      print("Making main request to get page content.");
      response = await client.get(url, headers: headMap);

      // Merge any new cookies from the second response
      String? finalCookies = _extractCookiesFromHeaders(response.headers);
      if (finalCookies != null) {
        final mergedCookie = _mergeCookies(currentCookie, finalCookies);
        currentCookie = mergedCookie;
        headMap['cookie'] = mergedCookie;

        print("mergeCookies:$currentCookie");
      }

      if (response.statusCode != 200) {
        throw DouyinApiException(
          "Failed to fetch Douyin page. Status code: ${response.statusCode}",
          '',
        );
      }

      // Decode the response body using UTF-8
      final String responseBody = utf8.decode(response.bodyBytes);

      // lLog('DouyinLiveApi.fetchLiveRoomInfo ${responseBody} ');
      // Parse the HTML document
      final dom.Document doc = html_parser.parse(responseBody);

      final List<dom.Element> scriptElements = doc.querySelectorAll('script');

      String? liveRoomId;

      for (final script in scriptElements) {
        final String dataHtml = script.innerHtml;

        // Use RegExp to check if the script contains the required data structure
        // (?s) in Java is equivalent to dotAll: true in Dart's RegExp
        final scriptMatch =
            RegExp(r'self.__rsc_f\.push\(\[1,"5:', dotAll: true);

        if (scriptMatch.hasMatch(dataHtml)) {
          print("Found matching script tag. Parsing for details...");

          final roomIdMatcher =
              RegExp(r'\\"roomIdStr\\":\\"(\d+)\\"').firstMatch(dataHtml);
          if (roomIdMatcher != null && roomIdMatcher.groupCount >= 1) {
            liveRoomId = roomIdMatcher.group(1);
            print("Found liveRoomId: $liveRoomId");
          } else {
            // throw DouyinApiException("Could not find liveRoomId.", code: "WWS_DY_ROOM_ID_ERROR");
            continue;
          }
        }
      }

      // Final check after the loop
      if (liveRoomId == null || liveRoomId.isEmpty) {
        throw DouyinApiException(
          "Stream is not live or room ID could not be found.",
          responseBody,
          code: "DOUYIN_NUMBER_NOT_LIVE",
          headMap: headMap,
        );
      }

      return (
        liveRoomId: liveRoomId,
        headMap: headMap,
      );
    } finally {
      client.close();
    }
  }

  /// Helper method to extract the text from the <title> tag of a parsed document.
  String? _parsePageTitle(dom.Document doc) {
    // Find the first 'title' element and return its text.
    // The null-aware operator `?.` makes this very clean:
    // If querySelector finds nothing (returns null), the whole expression becomes null.
    // If it finds an element, it proceeds to access the .text property.
    return doc.querySelector('title')?.text;
  }

  String? _parsePageHead(dom.Document doc) {
    // Find the first 'title' element and return its text.
    // The null-aware operator `?.` makes this very clean:
    // If querySelector finds nothing (returns null), the whole expression becomes null.
    // If it finds an element, it proceeds to access the .text property.
    return doc.querySelector('head')?.text;
  }

  /// Returns true if the HTML contains a login prompt button under the
  /// expected container `div#MS3tMtRG`.
  ///
  /// This is intentionally strict to avoid false positives:
  /// - Must have the exact container id.
  /// - Must contain the expected button class chain.
  /// - Must contain visible text "登录" (trimmed).
  bool _hasLoginButtonPrompt(dom.Document doc) {
    final container = doc.querySelector('div#MS3tMtRG');
    lLog('DouyinLiveApi._hasLoginButtonPrompt ${container} ');
    if (container == null) return false;

    final loginText = container
        .querySelector(
          'button.semi-button.semi-button-primary.QPtP8FSi p.KetGEJla',
        )
        ?.text
        .trim();
    if (loginText == '登录') return true;

    final hasExpectedButton = container.querySelector(
          'button.semi-button.semi-button-primary.QPtP8FSi',
        ) !=
        null;
    if (!hasExpectedButton) return false;

    return container.text.contains('登录');
  }

  /// Parses the 'set-cookie' header into a single string.
  String? _extractCookiesFromHeaders(Map<String, String> headers) {
    String? rawCookie = headers['set-cookie'];
    if (rawCookie == null) return null;

    // The 'set-cookie' header can contain multiple cookies separated by commas
    // followed by a space, and each cookie has attributes like Path, Expires, etc.
    // We only care about the key=value part for the next request's 'cookie' header.
    return rawCookie
        .split(',')
        .map((str) => str.split(';')[0].trim())
        .join('; ');
  }

  /// Merges two cookie strings, with new cookies overwriting old ones.
  String _mergeCookies(String? originalCookie, String newCookie) {
    if (originalCookie == null || originalCookie.isEmpty) {
      return newCookie;
    }

    final Map<String, String> originalMap = _parseCookieToMap(originalCookie);
    final Map<String, String> newMap = _parseCookieToMap(newCookie);

    // Merge new cookies into the original map, overwriting duplicates.
    originalMap.addAll(newMap);

    // Convert the merged map back to a string.
    return originalMap.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  /// Helper to convert a cookie string to a Map.
  Map<String, String> _parseCookieToMap(String cookieStr) {
    final map = <String, String>{};
    final parts = cookieStr.split(';');
    for (final part in parts) {
      final cookiePair = part.trim().split('=');
      if (cookiePair.length == 2) {
        map[cookiePair[0]] = cookiePair[1];
      }
    }
    return map;
  }

  /// Helper method to parse the nickname from a list of script elements.
  /// Checks if any of the provided elements contain the system error message.
  ///
  /// Corresponds to Java's `parseSystemError` and `extractSystemError`.
  bool _parseSystemError(List<dom.Element> elements) {
    const String errorMessage = "服务器开小差了，点击刷新重试";
    for (final element in elements) {
      // Using .contains() is the direct equivalent of searching for a literal string,
      // which is what Pattern.quote() achieves in Java.
      if (element.innerHtml.contains(errorMessage)) {
        print("Found system error message in div.");
        return true;
      }
    }
    return false;
  }

  /// Iterates through script elements to find the first valid nickname.
  ///
  /// Corresponds to Java's `parseNickName`.
  String? _parseNickName(List<dom.Element> scriptElements) {
    for (final script in scriptElements) {
      final String? statusStr = _extractNickName(script.innerHtml);
      if (statusStr != null && statusStr.isNotEmpty) {
        return statusStr; // Return the first one found
      }
    }
    return null; // Return null if not found in any script
  }

  /// Extracts a valid nickname from a single script's content.
  ///
  /// Corresponds to Java's `extractNickName`.
  String? _extractNickName(String scriptContent) {
    // Check if the script content starts with the specific required prefix.
    if (scriptContent.startsWith('self.__pace_f.push([1,"c:') ||
        scriptContent.startsWith('self.__pace_f.push([1,"d:')) {
      // Find all matches for the nickname pattern in the script.
      // This is the Dart equivalent of Java's `while (matcher.find())`.
      final matches = _nickNamePattern.allMatches(scriptContent);

      for (final match in matches) {
        // group(1) gets the content inside the first parentheses `(.*?)`.
        final data = match.group(1);

        // Check if the data is not null and not the specific "$undefined" string.
        // Using a raw string `r'$...'` ensures the '$' is treated literally.
        if (data != null && data != r'$undefined') {
          // A robust way to handle potential unicode escapes (e.g., \uXXXX)
          // is to decode the string as if it were a JSON string literal.
          try {
            final decodedName = json.decode('"$data"');
            print("Successfully parsed nickname: $decodedName");
            return decodedName;
          } catch (e) {
            print(
                "Could not JSON decode nickname, returning raw value. Raw: '$data'");
            return data;
          }
        }
      }
    }
    return null; // Return null if conditions aren't met or no valid match is found
  }
}

class DouyinApiException implements Exception {
  final String message;
  final String? code;
  final String html;
  final Map<String, String>? headMap;

  DouyinApiException(this.message, this.html, {this.code, this.headMap});

  @override
  String toString() =>
      'DouyinApiException: $message ${code != null ? "(Code: $code)" : ""}';
}
