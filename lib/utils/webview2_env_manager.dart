import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// WebView2 环境管理器
///
/// Windows 上 flutter_inappwebview 底层依赖 Microsoft Edge WebView2 Runtime。
/// 该管理器优先检测系统是否已安装 WebView2 Runtime，若未安装则尝试从
/// 应用目录下加载打包的 Fixed Version（固定版本）运行时。
///
/// Fixed Version 的下载与放置方式见 README 或 AGENTS.md 中的说明。
class WebView2EnvManager {
  WebView2EnvManager._();

  static final WebView2EnvManager _instance = WebView2EnvManager._();
  factory WebView2EnvManager() => _instance;
  static WebView2EnvManager get instance => _instance;

  WebViewEnvironment? _environment;
  CookieManager? _cookieManager;
  bool _initialized = false;
  bool _useFixedVersion = false;

  /// 是否已初始化完成
  bool get isInitialized => _initialized;

  /// 是否可用（环境已创建）
  bool get isAvailable => _initialized && _environment != null;

  /// 是否正在使用 Fixed Version 运行时
  bool get useFixedVersion => _useFixedVersion;

  /// 共享的 WebViewEnvironment 实例，传给 InAppWebView 使用
  WebViewEnvironment? get environment => _environment;

  /// 与当前 WebViewEnvironment 关联的 CookieManager
  /// 
  /// 在 Windows 平台使用 Fixed Version 运行时时，CookieManager 需要与
  /// WebView 使用同一个环境才能正确获取 Cookie。
  CookieManager get cookieManager {
    if (_cookieManager == null) {
      if (_environment != null && Platform.isWindows) {
        _cookieManager = CookieManager.fromPlatformCreationParams(
          PlatformCookieManagerCreationParams(
            webViewEnvironment: _environment!.platform,
          ),
        );
      } else {
        _cookieManager = CookieManager.instance();
      }
    }
    return _cookieManager!;
  }

  /// 初始化 WebView2 环境，应在 main() 启动时尽早调用
  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb || !Platform.isWindows) {
      // 非 Windows 平台无需 WebView2
      _initialized = true;
      return;
    }

    // 1) 先检查系统是否已安装 WebView2 Runtime（Evergreen）
    final systemVersion = await WebViewEnvironment.getAvailableVersion();
    if (systemVersion != null) {
      _environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(),
      );
      _initialized = true;
      return;
    }

    // 2) 系统未安装，尝试从应用目录加载 Fixed Version
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final webview2Dir = [exeDir, 'data', 'webview2'].join(Platform.pathSeparator);
    final webview2Root = Directory(webview2Dir);

    if (await webview2Root.exists()) {
      // Fixed Version 解压后可能有一层额外目录（如 Microsoft.WebView2.FixedVersionRuntime.xxx）
      // 需要找到包含 msedgewebview2.exe 的那一层
      String? fixedVersionPath;
      final entries = webview2Root.listSync().whereType<Directory>().toList();
      for (final dir in entries) {
        final hasExe = dir.listSync().any((e) =>
            e is File && e.path.endsWith('msedgewebview2.exe'));
        if (hasExe) {
          fixedVersionPath = dir.path;
          break;
        }
      }
      // 如果子目录没找到，直接用根目录
      fixedVersionPath ??= webview2Dir;

      final fixedVersion = await WebViewEnvironment.getAvailableVersion(
        browserExecutableFolder: fixedVersionPath,
      );
      if (fixedVersion != null) {
        _environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            browserExecutableFolder: fixedVersionPath,
          ),
        );
        _useFixedVersion = true;
        _initialized = true;
        return;
      }
    }

    // 3) 既无系统运行时，也无打包的运行时
    _initialized = true;
    _environment = null;
  }

  /// 释放环境资源
  Future<void> dispose() async {
    if (_cookieManager != null) {
      _cookieManager = null;
    }
    if (_environment != null) {
      await _environment!.dispose();
      _environment = null;
    }
    _initialized = false;
    _useFixedVersion = false;
  }
}