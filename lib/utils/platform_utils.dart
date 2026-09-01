import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PlatformUtils {
  static bool _isWeb() {
    return kIsWeb == true;
  }

  static bool _isAndroid() {
    return _isWeb() ? false : Platform.isAndroid;
  }

  static bool _isIOS() {
    return _isWeb() ? false : Platform.isIOS;
  }

  static bool _isMacOS() {
    return _isWeb() ? false : Platform.isMacOS;
  }

  static bool _isWindows() {
    return _isWeb() ? false : Platform.isWindows;
  }

  static bool _isFuchsia() {
    return _isWeb() ? false : Platform.isFuchsia;
  }

  static bool _isLinux() {
    return _isWeb() ? false : Platform.isLinux;
  }

  static bool get isWeb => _isWeb();

  static bool get isAndroid => _isAndroid();

  static bool get isIOS => _isIOS();

  static bool get isMacOS => _isMacOS();

  static bool get isWindows => _isWindows();

  static bool get isFuchsia => _isFuchsia();

  static bool get isLinux => _isLinux();

  static Future<bool> hasVCRedist2015To2022x64() async {
    if (!isWindows) return true;

    const registryKeys = <String>[
      r'HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      r'HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    ];

    for (final key in registryKeys) {
      try {
        final result = await Process.run(
          'reg',
          <String>['query', key, '/v', 'Installed', '/reg:64'],
        ).timeout(const Duration(seconds: 2));

        if (result.exitCode != 0) continue;

        final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
        final installedLine = output
            .split('\n')
            .map((e) => e.trim())
            .firstWhere((line) => line.contains('installed'), orElse: () => '');

        if (installedLine.isEmpty) continue;
        if (RegExp(r'0x0*1\b').hasMatch(installedLine)) return true;
      } catch (_) {}
    }

    return false;
  }

  static Future<File> copyBundledWindowsFileToDownloadsDir({
    required String fileName,
    String bundleSubDir = 'data',
  }) async {
    if (!isWindows) {
      throw StateError('copyBundledWindowsFileToDownloadsDir: not windows');
    }

    final String exeDirPath = File(Platform.resolvedExecutable).parent.path;
    final String bundledFilePath = [
      exeDirPath,
      bundleSubDir,
      fileName,
    ].join(Platform.pathSeparator);
    final File bundledFile = File(bundledFilePath);

    if (!await bundledFile.exists()) {
      throw FileSystemException('Bundled file not found', bundledFile.path);
    }

    final Directory? downloadsDir = await getDownloadsDirectory();
    final Directory targetDir = downloadsDir ?? await getTemporaryDirectory();

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final String targetFilePath = [
      targetDir.path,
      fileName,
    ].join(Platform.pathSeparator);
    final File targetFile = File(targetFilePath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    return bundledFile.copy(targetFile.path);
  }

  static Future<File> downloadFileToDownloadsDir({
    required Uri url,
    required String fileName,
  }) async {
    final Directory? downloadsDir = await getDownloadsDirectory();
    final Directory targetDir = downloadsDir ?? await getTemporaryDirectory();

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final String filePath =
        '${targetDir.path}${Platform.pathSeparator}$fileName';
    final File targetFile = File(filePath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(url);
      request.followRedirects = true;
      final HttpClientResponse response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
          uri: response.redirects.isNotEmpty
              ? response.redirects.last.location
              : url,
        );
      }

      final IOSink sink = targetFile.openWrite();
      await response.pipe(sink);
      return targetFile;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> revealFileInExplorer(String filePath) async {
    if (!isWindows) return;

    try {
      await Process.run('explorer', <String>['/select,$filePath']);
    } catch (_) {}
  }
}
