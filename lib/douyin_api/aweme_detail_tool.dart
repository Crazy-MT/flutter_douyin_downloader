import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:code_zero/utils/log_utils.dart';

import 'douyin_endpoint.dart';
import 'douyin_request.dart';

class VideoDownloadSource {
  const VideoDownloadSource({
    required this.url,
    required this.source,
    required this.bitRate,
    required this.width,
    required this.height,
    this.codec,
    this.qualityLabel,
  });

  final String url;
  final String source;
  final int bitRate;
  final int width;
  final int height;
  final String? codec;
  final String? qualityLabel;

  int get pixelCount => width * height;
}

class AwemeDetailTool {
  const AwemeDetailTool(this._request);

  final DouyinRequest _request;

  Future<Map<String, dynamic>> fetchSummary({
    required String awemeId,
    required String cookie,
  }) async {
    final result = await _request.send(
      videoEndpoints.first,
      {'aweme_id': awemeId},
      cookie,
    );
    final data = jsonDecode(result.body) as Map<String, dynamic>;
    final detail = (data['aweme_detail'] as Map?) ?? const {};
    final author = (detail['author'] as Map?) ?? const {};
    final stats = (detail['statistics'] as Map?) ?? const {};
    final video = (detail['video'] as Map?) ?? const {};
    final music = (detail['music'] as Map?) ?? const {};

    lLog('AwemeDetailTool.fetchSummary 顶层字段: ${data.keys.toList()}');
    lLog(
        'AwemeDetailTool.fetchSummary aweme_detail 字段: ${detail.keys.toList()}');
    lLog('AwemeDetailTool.fetchSummary author 字段: ${author.keys.toList()}');
    lLog('AwemeDetailTool.fetchSummary statistics 字段: ${stats.keys.toList()}');
    lLog('AwemeDetailTool.fetchSummary video 字段: ${video.keys.toList()}');
    lLog('AwemeDetailTool.fetchSummary music 字段: ${music.keys.toList()}');
    lLog('AwemeDetailTool.fetchSummary 接口原始响应:\n${result.body}');
    lLog(
      'AwemeDetailTool.fetchSummary aweme_detail 原始内容:\n'
      '${const JsonEncoder.withIndent('  ').convert(detail)}',
    );
    final selectedVideo = pickBestVideoSource(video);
    lLog(
      'AwemeDetailTool.fetchSummary 选中的视频地址: '
      'source=${selectedVideo?.source}, '
      'bit_rate=${selectedVideo?.bitRate}, '
      'resolution=${selectedVideo?.width}x${selectedVideo?.height}, '
      'url=${selectedVideo?.url}',
    );

    return {
      'http_status': result.statusCode,
      'status_code': data['status_code'],
      'aweme_id': detail['aweme_id'],
      'item_title': detail['item_title'],
      'desc': detail['desc'],
      'author_nickname': author['nickname'],
      'author_uid': author['uid'],
      'create_time': _formatSeconds(detail['create_time']),
      'duration_ms': detail['duration'],
      'digg_count': stats['digg_count'],
      'comment_count': stats['comment_count'],
      'share_count': stats['share_count'],
      'collect_count': stats['collect_count'],
      'cover_url': _firstUrl((video['cover'] as Map?) ?? const {}),
      'play_url': selectedVideo?.url,
      'music_play_url': _firstUrl((music['play_url'] as Map?) ?? const {}),
      'music_title': music['title'],
      'music_author': music['author'],
      'selected_video_source': selectedVideo?.source,
      'selected_video_bit_rate': selectedVideo?.bitRate,
      'selected_video_width': selectedVideo?.width,
      'selected_video_height': selectedVideo?.height,
      'selected_video_codec': selectedVideo?.codec,
      'selected_video_quality_label': selectedVideo?.qualityLabel,
    };
  }

  Future<String> downloadVideo({
    required Map<String, dynamic> summary,
    required String awemeId,
    required String cookie,
    required String outputPath,
  }) async {
    final playUrl = '${summary['play_url'] ?? ''}';
    if (playUrl.isEmpty) {
      throw StateError('没有可下载的视频地址');
    }
    final path = outputPath.trim().isEmpty
        ? await defaultDownloadPath(awemeId)
        : outputPath.trim();
    final file = File(path);
    try {
      if (file.parent.path != '.') {
        await file.parent.create(recursive: true);
      }
    } on FileSystemException catch (error) {
      throw FileSystemException(
        '无法创建下载目录；请保存到默认下载路径，或给 App 对应目录权限',
        error.path,
        error.osError,
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final request = await client.getUrl(Uri.parse(playUrl));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    );
    request.headers.set(
        HttpHeaders.refererHeader, 'https://www.douyin.com/video/$awemeId');
    if (cookie.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookie.trim());
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('下载失败 HTTP ${response.statusCode}',
          uri: Uri.parse(playUrl));
    }
    try {
      await response.pipe(file.openWrite());
    } on FileSystemException catch (error) {
      throw FileSystemException(
        '无法写入视频文件；请保存到默认下载路径，或给 App 对应目录权限',
        error.path,
        error.osError,
      );
    }
    client.close(force: true);
    return file.path;
  }

  Future<String> downloadAudio({
    required String audioUrl,
    required String awemeId,
    required String cookie,
    required String outputPath,
  }) async {
    if (audioUrl.trim().isEmpty) {
      throw StateError('没有可下载的音频地址');
    }
    final file = File(outputPath.trim());
    try {
      if (file.parent.path != '.') {
        await file.parent.create(recursive: true);
      }
    } on FileSystemException catch (error) {
      throw FileSystemException(
        '无法创建下载目录；请保存到默认下载路径，或给 App 对应目录权限',
        error.path,
        error.osError,
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final request = await client.getUrl(Uri.parse(audioUrl));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    );
    request.headers.set(
        HttpHeaders.refererHeader, 'https://www.douyin.com/video/$awemeId');
    if (cookie.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookie.trim());
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('下载失败 HTTP ${response.statusCode}',
          uri: Uri.parse(audioUrl));
    }
    try {
      await response.pipe(file.openWrite());
    } on FileSystemException catch (error) {
      throw FileSystemException(
        '无法写入音频文件；请保存到默认下载路径，或给 App 对应目录权限',
        error.path,
        error.osError,
      );
    } finally {
      client.close(force: true);
    }
    return file.path;
  }

  Future<String> extractAudio({
    required String videoPath,
    String? outputAudioPath,
  }) async {
    bool usePackage = true;
    if (Platform.isLinux || Platform.isWindows) {
      usePackage = false;
    }

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw FileSystemException('视频文件不存在', videoPath);
    }
    final audioCodec = await _detectAudioCodec(
      videoPath,
      usePackage: usePackage,
    );
    final audioPath = outputAudioPath?.trim().isNotEmpty == true
        ? outputAudioPath!
        : _defaultAudioPath(videoPath, codecName: audioCodec);
    final audioFile = File(audioPath);
    if (audioFile.parent.path != '.') {
      await audioFile.parent.create(recursive: true);
    }

    final commandArguments = <String>[
      '-y',
      '-i',
      videoPath,
      '-vn',
      '-acodec',
      'copy',
      audioPath,
    ];

    if (usePackage) {
      final session = await FFmpegKit.executeWithArguments(commandArguments);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        if (audioFile.existsSync()) {
          try {
            await audioFile.delete();
          } catch (_) {}
        }
        final logs = await session.getLogs();
        final output = logs.map((l) => l.getMessage()).join('\n');
        throw StateError(
            'ffmpeg 提取音频失败: ${output.isEmpty ? 'exit ${returnCode?.getValue() ?? 'unknown'}' : output}');
      }
    } else {
      final result = await Process.run(
        'ffmpeg',
        commandArguments,
      );
      if (result.exitCode != 0) {
        if (audioFile.existsSync()) {
          try {
            await audioFile.delete();
          } catch (_) {}
        }
        final stderr = result.stderr?.toString() ?? '';
        if (stderr.toLowerCase().contains('not found') ||
            stderr.toLowerCase().contains('is not recognized') ||
            RegExp(r'"ffmpeg"[^\n]*not found').hasMatch(stderr)) {
          throw StateError(
            '未检测到 ffmpeg 可执行文件，请先安装 ffmpeg 并加入 PATH：https://ffmpeg.org/download.html',
          );
        }
        throw StateError('ffmpeg 提取音频失败 (exit ${result.exitCode}): $stderr');
      }
    }

    if (!await audioFile.exists()) {
      throw StateError('音频输出文件未生成');
    }
    return audioFile.path;
  }

  Future<String?> _detectAudioCodec(
    String videoPath, {
    required bool usePackage,
  }) async {
    if (usePackage) {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();
      if (info == null) return null;
      for (final stream in info.getStreams()) {
        if (stream.getType() == 'audio') {
          final codec = stream.getCodec()?.trim();
          if (codec != null && codec.isNotEmpty) {
            return codec;
          }
        }
      }
      return null;
    }

    try {
      final result = await Process.run(
        'ffprobe',
        <String>[
          '-v',
          'error',
          '-select_streams',
          'a:0',
          '-show_entries',
          'stream=codec_name',
          '-of',
          'default=nokey=1:noprint_wrappers=1',
          videoPath,
        ],
      );
      if (result.exitCode != 0) return null;
      final codec = result.stdout?.toString().trim();
      if (codec == null || codec.isEmpty) return null;
      return codec;
    } catch (_) {
      return null;
    }
  }

  String _defaultAudioPath(String videoPath, {String? codecName}) {
    final withoutExt = _stripExtension(videoPath);
    return '$withoutExt.${_audioExtensionForCodec(codecName)}';
  }

  String _stripExtension(String path) {
    final separator = Platform.pathSeparator;
    final fileNameStart = path.lastIndexOf(separator);
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex <= fileNameStart) {
      return path;
    }
    return path.substring(0, dotIndex);
  }

  String _audioExtensionForCodec(String? codecName) {
    switch ((codecName ?? '').toLowerCase()) {
      case 'aac':
        return 'aac';
      case 'mp3':
        return 'mp3';
      case 'opus':
        return 'opus';
      case 'vorbis':
        return 'ogg';
      case 'flac':
        return 'flac';
      case 'alac':
        return 'm4a';
      case 'ac3':
        return 'ac3';
      case 'eac3':
        return 'eac3';
      case 'dts':
        return 'dts';
      case 'amr_nb':
        return 'amr';
      case 'amr_wb':
        return 'awb';
      case 'wmav1':
      case 'wmav2':
      case 'wmapro':
      case 'wmavoice':
        return 'wma';
      default:
        if ((codecName ?? '').toLowerCase().startsWith('pcm_')) {
          return 'wav';
        }
        return 'aac';
    }
  }

  Future<String> defaultDownloadPath(String awemeId) async {
    Directory dir;
    if (Platform.isAndroid) {
      final externals =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      dir = pickAndroidDefaultDownloadDirectory(
        appDownloadDirectories: externals ?? const [],
        publicDownloadDirectory: Directory('/storage/emulated/0/Download'),
        documentsDirectory: await getApplicationDocumentsDirectory(),
      );
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    final subDir =
        Directory('${dir.path}${Platform.pathSeparator}douyin_video');
    // lLog('mtmtmt: $subDir');
    return '${subDir.path}${Platform.pathSeparator}$awemeId.mp4';
  }

  static Directory pickAndroidDefaultDownloadDirectory({
    required List<Directory> appDownloadDirectories,
    required Directory publicDownloadDirectory,
    required Directory documentsDirectory,
  }) {
    if (appDownloadDirectories.isNotEmpty) {
      return appDownloadDirectories.first;
    }
    return documentsDirectory;
  }

  String encodeSummary(Map<String, dynamic> summary) {
    return const JsonEncoder.withIndent('  ').convert(summary);
  }

  static VideoDownloadSource? pickBestVideoSource(Map video) {
    final bitRateCandidates = _collectBitRateCandidates(video);
    if (bitRateCandidates.isNotEmpty) {
      bitRateCandidates.sort(_compareVideoSource);
      return bitRateCandidates.first;
    }

    final fallbackCandidates = _collectFallbackCandidates(video);
    if (fallbackCandidates.isEmpty) return null;
    fallbackCandidates.sort(_compareVideoSource);
    return fallbackCandidates.first;
  }

  static List<VideoDownloadSource> _collectBitRateCandidates(Map video) {
    final items = video['bit_rate'];
    if (items is! List) return const [];
    final candidates = <VideoDownloadSource>[];
    for (final item in items) {
      if (item is! Map) continue;
      final source = _candidateFromEntry(
        entry: item,
        source: 'bit_rate',
        fallbackWidth: _intValue(video['width']) ?? 0,
        fallbackHeight: _intValue(video['height']) ?? 0,
        defaultBitRate: _intValue(item['bit_rate']) ?? 0,
      );
      if (source != null) {
        candidates.add(source);
      }
    }
    return candidates;
  }

  static List<VideoDownloadSource> _collectFallbackCandidates(Map video) {
    final fallbackWidth = _intValue(video['width']) ?? 0;
    final fallbackHeight = _intValue(video['height']) ?? 0;
    final candidates = <VideoDownloadSource>[];
    for (final entry in <MapEntry<String, Object?>>[
      MapEntry('play_addr_265', video['play_addr_265']),
      MapEntry('play_addr_h264', video['play_addr_h264']),
      MapEntry('play_addr', video['play_addr']),
      MapEntry('download_addr', video['download_addr']),
    ]) {
      final map = entry.value;
      if (map is! Map) continue;
      final source = _candidateFromEntry(
        entry: map,
        source: entry.key,
        fallbackWidth: fallbackWidth,
        fallbackHeight: fallbackHeight,
      );
      if (source != null) {
        candidates.add(source);
      }
    }
    return candidates;
  }

  static VideoDownloadSource? _candidateFromEntry({
    required Map entry,
    required String source,
    required int fallbackWidth,
    required int fallbackHeight,
    int defaultBitRate = 0,
  }) {
    final playAddr = (entry['play_addr'] as Map?) ?? entry;
    final url = _firstUrl(playAddr);
    if (url == null || url.isEmpty) return null;
    return VideoDownloadSource(
      url: url,
      source: source,
      bitRate: _intValue(entry['bit_rate']) ?? defaultBitRate,
      width: _intValue(playAddr['width']) ??
          _intValue(entry['width']) ??
          fallbackWidth,
      height: _intValue(playAddr['height']) ??
          _intValue(entry['height']) ??
          fallbackHeight,
      codec: _stringValue(entry['gear_name']) ??
          _stringValue(entry['codec_type']) ??
          _stringValue(entry['is_bytevc1']) ??
          _stringValue(entry['is_h265']),
      qualityLabel: _stringValue(entry['gear_name']) ??
          _stringValue(entry['quality_type']) ??
          _stringValue(entry['quality_name']),
    );
  }

  static int _compareVideoSource(
    VideoDownloadSource a,
    VideoDownloadSource b,
  ) {
    final byBitRate = b.bitRate.compareTo(a.bitRate);
    if (byBitRate != 0) return byBitRate;

    final byPixelCount = b.pixelCount.compareTo(a.pixelCount);
    if (byPixelCount != 0) return byPixelCount;

    final byWidth = b.width.compareTo(a.width);
    if (byWidth != 0) return byWidth;

    final byHeight = b.height.compareTo(a.height);
    if (byHeight != 0) return byHeight;

    return a.source.compareTo(b.source);
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse('$value');
  }

  static String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String? _firstUrl(Map obj) {
    final urls = obj['url_list'];
    if (urls is List && urls.isNotEmpty) return '${urls.first}';
    return null;
  }

  String? _formatSeconds(Object? value) {
    final seconds = value is int ? value : int.tryParse('$value');
    if (seconds == null) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}
