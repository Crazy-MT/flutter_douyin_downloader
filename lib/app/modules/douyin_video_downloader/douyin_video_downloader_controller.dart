import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:code_zero/douyin_api/abogus_signer.dart';
import 'package:code_zero/douyin_api/aweme_detail_tool.dart';
import 'package:code_zero/douyin_api/douyin_request.dart';
import 'package:code_zero/douyin_api/lyrics_recognition_tool.dart';
import 'package:code_zero/app/modules/douyin_video_downloader/douyin_music_lyrics_page.dart';
import 'package:code_zero/app/routes/app_routes.dart';
import 'package:code_zero/utils/sp_helper.dart';
import 'package:code_zero/utils/log_utils.dart';

class LocalMusicTrack {
  const LocalMusicTrack({
    required this.title,
    required this.path,
  });

  final String title;
  final String path;
}

class LocalVideoTrack {
  const LocalVideoTrack({
    required this.title,
    required this.path,
  });

  final String title;
  final String path;
}

enum MusicPlaybackMode {
  listLoop,
  singleLoop,
  shuffle,
}

enum MusicImportMode {
  videoExtractAudio,
  directMusicUrl,
}

class DouyinVideoDownloaderController extends GetxController {
  final cookieController = TextEditingController();

  final signer = ABogusSigner();
  late final DouyinRequest request;
  late final AwemeDetailTool tool;
  late final LyricsRecognitionTool lyricsTool;
  Player? _audioPlayer;
  Player? _videoPlayer;
  VideoController? _videoController;

  final awemeId = TextEditingController();
  final shareText = TextEditingController();
  final musicName = TextEditingController();
  final outputPath = TextEditingController();
  final summary = Rxn<Map<String, dynamic>>();
  final awemeMessage = Rxn<String>();
  final awemeLoading = false.obs;
  final downloading = false.obs;
  final extractingAudio = false.obs;
  final generatingLyrics = false.obs;
  final recognizingLyricsPath = Rxn<String>();
  final generatedLyricsPath = Rxn<String>();
  final hasSavedCookie = false.obs;
  final lyricsByAudioPath = <String, String>{}.obs;
  final savedAudioPath = Rxn<String>();
  final savedVideoPath = Rxn<String>();
  final musicList = <LocalMusicTrack>[].obs;
  final videoList = <LocalVideoTrack>[].obs;
  final currentPlayingAudioPath = Rxn<String>();
  final currentPlayingVideoPath = Rxn<String>();
  final currentTrackIndex = RxnInt();
  final musicPlaying = false.obs;
  final videoPlaying = false.obs;
  final playbackMode = MusicPlaybackMode.listLoop.obs;
  final musicImportMode = MusicImportMode.directMusicUrl.obs;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Playlist>? _playlistSubscription;
  StreamSubscription<bool>? _videoPlayingSubscription;
  StreamSubscription<Playlist>? _videoPlaylistSubscription;
  String? _lastAutoOutputPath;

  Player get _player {
    final player = _audioPlayer;
    if (player != null) return player;
    final created = Player();
    _audioPlayer = created;
    _bindAudioPlayer(created);
    return created;
  }

  Player get _video {
    final player = _videoPlayer;
    if (player != null) return player;
    final created = Player();
    _videoPlayer = created;
    _videoController = VideoController(created);
    _bindVideoPlayer(created);
    return created;
  }

  VideoController? get videoController => _videoController;

  bool get busy =>
      awemeLoading.value ||
      downloading.value ||
      extractingAudio.value ||
      generatingLyrics.value;

  bool get needsCookieLoginBeforeDownload => !hasSavedCookie.value;

  bool get supportsCustomDownloadDirectory =>
      Platform.isMacOS || Platform.isWindows;

  String get outputDirectoryText {
    final path = outputPath.text.trim();
    if (path.isEmpty) return '默认下载文件夹';
    return p.dirname(path);
  }

  String get primaryStatusText {
    if (awemeLoading.value) return '正在获取视频详情';
    if (downloading.value) return awemeMessage.value ?? '正在下载';
    if (extractingAudio.value) return '正在提取音频';
    if (generatingLyrics.value) return '正在识别歌词';
    return awemeMessage.value ?? '准备就绪';
  }

  @override
  void onInit() {
    super.onInit();
    request = DouyinRequest(signer);
    tool = AwemeDetailTool(request);
    lyricsTool = LyricsRecognitionTool();
    _initDefaultCookie();

    awemeId.text = '';
    _refreshDefaultOutputPath(force: true);
    awemeId.addListener(_syncDefaultOutputPath);
    refreshLocalMusicList();
  }

  @override
  void onClose() {
    _playingSubscription?.cancel();
    _playlistSubscription?.cancel();
    _videoPlayingSubscription?.cancel();
    _videoPlaylistSubscription?.cancel();
    _audioPlayer?.dispose();
    _videoPlayer?.dispose();
    cookieController.dispose();
    awemeId.removeListener(_syncDefaultOutputPath);
    awemeId.dispose();
    shareText.dispose();
    musicName.dispose();
    outputPath.dispose();
    super.onClose();
  }

  void _initDefaultCookie() {
    final savedCookie = SpHelper.getDyCookie();
    hasSavedCookie.value = savedCookie.isNotEmpty;
    if (savedCookie.isNotEmpty) {
      cookieController.text = savedCookie;
      lLog(
          'DouyinVideoDownloaderController._initDefaultCookie 从本地存储加载抖音 Cookie');
    }
  }

  Future<void> goToLoginAndGetCookie() async {
    final result = await Get.toNamed(RoutesID.DOUYIN_LOGIN_PAGE);
    lLog('DouyinVideoDownloaderController.goToLoginAndGetCookie 返回结果: $result');
    if (result == 3) {
      final savedCookie = SpHelper.getDyCookie();
      lLog(
          'DouyinVideoDownloaderController.goToLoginAndGetCookie 返回结果: $savedCookie');
      if (savedCookie.isNotEmpty) {
        cookieController.text = savedCookie;
        hasSavedCookie.value = true;
        lLog(
            'DouyinVideoDownloaderController.goToLoginAndGetCookie 已更新抖音 Cookie');
      }
    }
  }

  Future<void> selectOutputDirectory() async {
    if (!supportsCustomDownloadDirectory) return;
    final selected = await FilePicker.platform.getDirectoryPath(
      initialDirectory:
          outputPath.text.trim().isEmpty ? null : p.dirname(outputPath.text),
    );
    if (selected == null) return;
    final path = await _buildAutoOutputPath(
      awemeId:
          awemeId.text.trim().isEmpty ? 'douyin_music' : awemeId.text.trim(),
      summary: summary.value,
      directory: selected,
    );
    outputPath.text = path;
    _lastAutoOutputPath = path;
  }

  void _syncDefaultOutputPath() {
    final id = awemeId.text.trim();
    if (id.isEmpty) return;
    final current = outputPath.text.trim();
    if (current.isEmpty || current == _lastAutoOutputPath) {
      _refreshDefaultOutputPath();
    }
  }

  Future<void> _refreshDefaultOutputPath({
    bool force = false,
    Map<String, dynamic>? summary,
  }) async {
    final id = awemeId.text.trim();
    if (id.isEmpty) return;
    final current = outputPath.text.trim();
    if (!force && current.isNotEmpty && current != _lastAutoOutputPath) {
      return;
    }
    final currentSummary = summary ?? this.summary.value;
    final path = await _buildAutoOutputPath(
      awemeId: id,
      summary:
          '${currentSummary?['aweme_id'] ?? ''}' == id ? currentSummary : null,
    );
    outputPath.text = path;
    _lastAutoOutputPath = path;
  }

  Future<void> fetchAweme() async {
    final id = awemeId.text.trim();
    if (id.isEmpty) {
      awemeMessage.value = '请输入 aweme_id';
      return;
    }
    awemeLoading.value = true;
    awemeMessage.value = null;
    summary.value = null;
    try {
      final s = await tool.fetchSummary(
        awemeId: id,
        cookie: cookieController.text,
      );
      summary.value = s;
      await _refreshDefaultOutputPath(summary: s);
      awemeMessage.value = '已获取视频详情';
    } catch (e) {
      awemeMessage.value = '获取失败：$e';
      debugPrint(summary.toString());
      debugPrint(e.toString());
    } finally {
      awemeLoading.value = false;
    }
  }

  Future<void> downloadAweme() async {
    final s = summary.value;
    if (s == null) {
      awemeMessage.value = '请先获取视频详情';
      return;
    }
    downloading.value = true;
    awemeMessage.value = null;
    savedAudioPath.value = null;
    try {
      final path = await tool.downloadVideo(
        summary: s,
        awemeId: awemeId.text.trim(),
        cookie: cookieController.text,
        outputPath: outputPath.text,
      );
      awemeMessage.value = '正在提取音频...';
      extractingAudio.value = true;
      final audioPath = await tool.extractAudio(
        videoPath: path,
        outputAudioPath: _customAudioOutputPath(path),
      );
      _rememberAudio(
        audioPath,
        summary: s,
        titleOverride: _customMusicTitle(),
      );
      // 暂时屏蔽模型生成歌词入口。恢复时改回 _rememberAudioAndGenerateLyrics。
      // final lyricsPath = await _rememberAudioAndGenerateLyrics(
      //   audioPath,
      //   summary: s,
      //   titleOverride: _customMusicTitle(),
      // );
      awemeMessage.value = '已下载: $path\n已提取音频: $audioPath';
    } catch (e) {
      if (savedAudioPath.value == null && !downloading.value) {
        awemeMessage.value = '视频已下载，但提取音频失败：$e';
      } else {
        awemeMessage.value = '操作失败：$e';
      }
    } finally {
      downloading.value = false;
      extractingAudio.value = false;
    }
    debugPrint(awemeMessage.value);
  }

  Future<bool> fetchAndDownloadAweme() async {
    final id = awemeId.text.trim();
    if (id.isEmpty) {
      awemeMessage.value = '请输入 aweme_id';
      return false;
    }
    awemeLoading.value = true;
    awemeMessage.value = '正在获取视频详情...';
    summary.value = null;
    savedAudioPath.value = null;
    try {
      final s = await tool.fetchSummary(
        awemeId: id,
        cookie: cookieController.text,
      );
      summary.value = s;
      await _refreshDefaultOutputPath(summary: s);
      awemeLoading.value = false;
      downloading.value = true;
      awemeMessage.value = '正在下载视频...';
      final path = await tool.downloadVideo(
        summary: s,
        awemeId: id,
        cookie: cookieController.text,
        outputPath: await _buildVideoOutputPath(
          awemeId: id,
          summary: s,
        ),
      );
      downloading.value = false;
      extractingAudio.value = true;
      awemeMessage.value = '正在提取音频...';
      final audioPath = await tool.extractAudio(
        videoPath: path,
        outputAudioPath: _customAudioOutputPath(path),
      );
      _rememberAudio(
        audioPath,
        summary: s,
        titleOverride: _customMusicTitle(),
      );
      // 暂时屏蔽模型生成歌词入口。恢复时改回 _rememberAudioAndGenerateLyrics。
      // final lyricsPath = await _rememberAudioAndGenerateLyrics(
      //   audioPath,
      //   summary: s,
      //   titleOverride: _customMusicTitle(),
      // );
      awemeMessage.value = '已下载: $path\n已提取音频: $audioPath';
      return true;
    } catch (e) {
      final prev = awemeMessage.value ?? '';
      if (prev == '正在提取音频...') {
        awemeMessage.value = '视频已下载，但提取音频失败：$e';
      } else {
        awemeMessage.value = '操作失败：$e';
      }
      debugPrint(e.toString());
      return false;
    } finally {
      awemeLoading.value = false;
      downloading.value = false;
      extractingAudio.value = false;
    }
  }

  Future<void> pasteShareText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      awemeMessage.value = '剪贴板为空';
      return;
    }
    shareText.text = text;
  }

  void clearImportForm() {
    shareText.clear();
    musicName.clear();
  }

  Future<bool> downloadFromShareText() async {
    final text = shareText.text.trim();
    if (text.isEmpty) {
      awemeMessage.value = '请粘贴抖音分享文本';
      return false;
    }
    final url = parseShareText(text);
    if (url == null) {
      awemeMessage.value = '未找到可解析的链接';
      return false;
    }
    var id = extractAwemeIdFromUrl(url);
    if (id == null) {
      id = await extractAwemeIdFromShareText();
    }
    if (id == null) return false;
    awemeId.text = id;
    await _refreshDefaultOutputPath();
    switch (musicImportMode.value) {
      case MusicImportMode.videoExtractAudio:
        return fetchAndDownloadAweme();
      case MusicImportMode.directMusicUrl:
        return fetchAndDownloadMusic();
    }
  }

  Future<bool> downloadMusicFromShareText() async {
    musicImportMode.value = MusicImportMode.directMusicUrl;
    return downloadFromShareText();
  }

  Future<bool> downloadVideoFromShareText() async {
    final text = shareText.text.trim();
    if (text.isEmpty) {
      awemeMessage.value = '请粘贴抖音分享文本';
      return false;
    }
    final url = parseShareText(text);
    if (url == null) {
      awemeMessage.value = '未找到可解析的链接';
      return false;
    }
    var id = extractAwemeIdFromUrl(url);
    if (id == null) {
      id = await extractAwemeIdFromShareText();
    }
    if (id == null) return false;
    awemeId.text = id;
    await _refreshDefaultOutputPath();
    return fetchAndDownloadVideo();
  }

  Future<bool> fetchAndDownloadVideo() async {
    final id = awemeId.text.trim();
    if (id.isEmpty) {
      awemeMessage.value = '请输入 aweme_id';
      return false;
    }
    awemeLoading.value = true;
    awemeMessage.value = '正在获取视频详情...';
    summary.value = null;
    savedVideoPath.value = null;
    try {
      final s = await tool.fetchSummary(
        awemeId: id,
        cookie: cookieController.text,
      );
      summary.value = s;
      await _refreshDefaultOutputPath(summary: s);
      awemeLoading.value = false;
      downloading.value = true;
      awemeMessage.value = '正在下载视频...';
      final path = await tool.downloadVideo(
        summary: s,
        awemeId: id,
        cookie: cookieController.text,
        outputPath: await _buildVideoOutputPath(
          awemeId: id,
          summary: s,
        ),
      );
      _rememberVideo(
        path,
        summary: s,
        titleOverride: _customMusicTitle(),
      );
      awemeMessage.value = '已下载视频: $path';
      return true;
    } catch (e) {
      awemeMessage.value = '操作失败：$e';
      debugPrint(e.toString());
      return false;
    } finally {
      awemeLoading.value = false;
      downloading.value = false;
    }
  }

  Future<bool> fetchAndDownloadMusic() async {
    final id = awemeId.text.trim();
    if (id.isEmpty) {
      awemeMessage.value = '请输入 aweme_id';
      return false;
    }
    awemeLoading.value = true;
    awemeMessage.value = '正在获取视频详情...';
    summary.value = null;
    savedAudioPath.value = null;
    try {
      final s = await tool.fetchSummary(
        awemeId: id,
        cookie: cookieController.text,
      );
      summary.value = s;
      awemeLoading.value = false;
      try {
        downloading.value = true;
        awemeMessage.value = '正在下载音轨...';
        final musicUrl = '${s['music_play_url'] ?? ''}'.trim();
        if (musicUrl.isEmpty) {
          throw StateError('没有可直接下载的 aweme_detail.music.play_url');
        }
        final audioPath = await tool.downloadAudio(
          audioUrl: musicUrl,
          awemeId: id,
          cookie: cookieController.text,
          outputPath: await _buildDirectMusicOutputPath(
            awemeId: id,
            summary: s,
          ),
        );
        _rememberAudio(
          audioPath,
          summary: s,
          titleOverride: _customMusicTitle(),
        );
        // 暂时屏蔽模型生成歌词入口。恢复时改回 _rememberAudioAndGenerateLyrics。
        // final lyricsPath = await _rememberAudioAndGenerateLyrics(
        //   audioPath,
        //   summary: s,
        //   titleOverride: _customMusicTitle(),
        // );
        awemeMessage.value = '已下载音轨: $audioPath';
        return true;
      } catch (e) {
        debugPrint('直接下载音轨失败，改用视频转音频：$e');
        downloading.value = false;
        extractingAudio.value = false;
        awemeMessage.value = '音轨下载失败，正在改用视频转音频...';
        final path = await tool.downloadVideo(
          summary: s,
          awemeId: id,
          cookie: cookieController.text,
          outputPath: outputPath.text,
        );
        downloading.value = false;
        extractingAudio.value = true;
        awemeMessage.value = '正在提取音频...';
        final audioPath = await tool.extractAudio(
          videoPath: path,
          outputAudioPath: _customAudioOutputPath(path),
        );
        _rememberAudio(
          audioPath,
          summary: s,
          titleOverride: _customMusicTitle(),
        );
        // 暂时屏蔽模型生成歌词入口。恢复时改回 _rememberAudioAndGenerateLyrics。
        // final lyricsPath = await _rememberAudioAndGenerateLyrics(
        //   audioPath,
        //   summary: s,
        //   titleOverride: _customMusicTitle(),
        // );
        awemeMessage.value = '已下载: $path\n已提取音频: $audioPath';
        return true;
      }
    } catch (e) {
      awemeMessage.value = '操作失败：$e';
      debugPrint(e.toString());
      return false;
    } finally {
      awemeLoading.value = false;
      downloading.value = false;
      extractingAudio.value = false;
    }
  }

  Future<void> refreshLocalMusicList() async {
    final samplePath = await tool.defaultDownloadPath('sample');
    final dir = Directory(p.dirname(samplePath));
    if (!await dir.exists()) {
      musicList.clear();
      videoList.clear();
      lyricsByAudioPath.clear();
      unawaited(_audioPlayer?.stop());
      unawaited(_videoPlayer?.stop());
      currentTrackIndex.value = null;
      currentPlayingAudioPath.value = null;
      currentPlayingVideoPath.value = null;
      musicPlaying.value = false;
      videoPlaying.value = false;
      return;
    }
    final files =
        await dir.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    final audioFiles =
        files.where((file) => isAudioPath(file.path)).toList(growable: false);
    final videoFiles =
        files.where((file) => isVideoPath(file.path)).toList(growable: false);
    final detectedLyrics = <String, String>{};
    for (final file in audioFiles) {
      final lrcPath = LyricsRecognitionTool.lrcPathFor(file.path);
      if (await File(lrcPath).exists()) {
        detectedLyrics[file.path] = lrcPath;
      }
    }
    musicList.assignAll(
      audioFiles.map((file) => LocalMusicTrack(
            title: p.basenameWithoutExtension(file.path),
            path: file.path,
          )),
    );
    videoList.assignAll(
      videoFiles.map((file) => LocalVideoTrack(
            title: p.basenameWithoutExtension(file.path),
            path: file.path,
          )),
    );
    lyricsByAudioPath.assignAll(detectedLyrics);
    final currentPath = currentPlayingAudioPath.value;
    if (currentPath != null) {
      final refreshedIndex =
          musicList.indexWhere((item) => item.path == currentPath);
      if (refreshedIndex < 0) {
        unawaited(_audioPlayer?.stop());
        currentTrackIndex.value = null;
        currentPlayingAudioPath.value = null;
        musicPlaying.value = false;
      } else {
        currentTrackIndex.value = refreshedIndex;
      }
    }
    final currentVideoPath = currentPlayingVideoPath.value;
    if (currentVideoPath == null) return;
    final refreshedVideoIndex =
        videoList.indexWhere((item) => item.path == currentVideoPath);
    if (refreshedVideoIndex < 0) {
      unawaited(_videoPlayer?.stop());
      currentPlayingVideoPath.value = null;
      videoPlaying.value = false;
    }
  }

  Future<void> refreshLocalResourceLists() => refreshLocalMusicList();

  LocalMusicTrack? get currentTrack {
    final path = currentPlayingAudioPath.value;
    if (path == null) return null;
    for (final track in musicList) {
      if (track.path == path) return track;
    }
    return null;
  }

  LocalVideoTrack? get currentVideo {
    final path = currentPlayingVideoPath.value;
    if (path == null) return null;
    for (final video in videoList) {
      if (video.path == path) return video;
    }
    return null;
  }

  String get playbackModeLabel {
    switch (playbackMode.value) {
      case MusicPlaybackMode.listLoop:
        return '列表循环';
      case MusicPlaybackMode.singleLoop:
        return '单曲循环';
      case MusicPlaybackMode.shuffle:
        return '随机循环';
    }
  }

  bool hasLyrics(String audioPath) => lyricsByAudioPath.containsKey(audioPath);

  String? lyricsPathFor(String audioPath) => lyricsByAudioPath[audioPath];

  void _bindAudioPlayer(Player player) {
    _playingSubscription = player.stream.playing.listen((playing) {
      musicPlaying.value = playing;
    });
    _playlistSubscription = player.stream.playlist.listen((playlist) {
      if (playlist.medias.isEmpty ||
          playlist.index < 0 ||
          playlist.index >= playlist.medias.length) {
        currentTrackIndex.value = null;
        currentPlayingAudioPath.value = null;
        return;
      }
      currentTrackIndex.value = playlist.index;
      currentPlayingAudioPath.value =
          playlist.medias[playlist.index].extras?['sourcePath'] as String? ??
              playlist.medias[playlist.index].uri;
    });
  }

  void _bindVideoPlayer(Player player) {
    _videoPlayingSubscription = player.stream.playing.listen((playing) {
      videoPlaying.value = playing;
    });
    _videoPlaylistSubscription = player.stream.playlist.listen((playlist) {
      if (playlist.medias.isEmpty ||
          playlist.index < 0 ||
          playlist.index >= playlist.medias.length) {
        currentPlayingVideoPath.value = null;
        return;
      }
      currentPlayingVideoPath.value =
          playlist.medias[playlist.index].extras?['sourcePath'] as String? ??
              playlist.medias[playlist.index].uri;
    });
  }

  Future<void> playMusic(LocalMusicTrack track) async {
    await _videoPlayer?.pause();
    final index = musicList.indexWhere((item) => item.path == track.path);
    if (index < 0) return;
    final isCurrentTrack = currentPlayingAudioPath.value == track.path;
    if (isCurrentTrack) {
      if (musicPlaying.value) {
        await _audioPlayer?.pause();
        return;
      }
      if (_audioPlayer?.state.completed == true) {
        await _playFromIndex(index);
        return;
      }
      await _audioPlayer?.play();
      return;
    }
    await _playFromIndex(index);
  }

  Future<void> playVideo(LocalVideoTrack video) async {
    await _audioPlayer?.pause();
    final isCurrentVideo = currentPlayingVideoPath.value == video.path;
    if (isCurrentVideo) {
      if (videoPlaying.value) {
        await _videoPlayer?.pause();
        return;
      }
      if (_videoPlayer?.state.completed == true) {
        await _video
            .open(Media(video.path, extras: {'sourcePath': video.path}));
        return;
      }
      await _videoPlayer?.play();
      return;
    }
    await _video.open(Media(video.path, extras: {'sourcePath': video.path}));
  }

  Future<void> togglePlayPause() async {
    if (musicList.isEmpty) return;
    final index = currentTrackIndex.value;
    if (index == null) {
      await _playFromIndex(0);
      return;
    }
    if (musicPlaying.value) {
      await _audioPlayer?.pause();
      return;
    }
    if (_audioPlayer?.state.completed == true) {
      await _playFromIndex(index);
      return;
    }
    await _audioPlayer?.play();
  }

  Future<void> playNextTrack() async {
    if (musicList.isEmpty) return;
    if (currentTrackIndex.value == null) {
      await _playFromIndex(0);
      return;
    }
    await _audioPlayer?.next();
  }

  Future<void> playPreviousTrack() async {
    if (musicList.isEmpty) return;
    if (currentTrackIndex.value == null) {
      await _playFromIndex(0);
      return;
    }
    await _audioPlayer?.previous();
  }

  Future<void> setPlaybackMode(MusicPlaybackMode mode) async {
    playbackMode.value = mode;
    await _applyPlaybackMode();
  }

  Future<void> togglePlaybackMode() async {
    final modes = MusicPlaybackMode.values;
    await setPlaybackMode(
      modes[(modes.indexOf(playbackMode.value) + 1) % modes.length],
    );
  }

  Future<void> generateLyrics(LocalMusicTrack track) async {
    if (generatingLyrics.value) return;
    generatedLyricsPath.value = null;
    awemeMessage.value = '正在识别歌词...';
    final path = await _generateLyricsFile(track.path);
    if (path == null) {
      Get.snackbar(
        '歌词识别失败',
        awemeMessage.value ?? '未知错误',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    generatedLyricsPath.value = path;
    awemeMessage.value = '已生成歌词: $path';
    Get.snackbar(
      '歌词识别完成',
      p.basename(path),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> openLyricsPage(LocalMusicTrack track) async {
    final lyricsPath = await _resolveLyricsPath(track.path);
    if (lyricsPath == null) {
      awemeMessage.value = '这首音乐还没有歌词，请先识别歌词';
      Get.snackbar(
        '暂无歌词',
        '请先为「${track.title}」识别歌词',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    await Get.to<void>(
      () => DouyinMusicLyricsPage(
        trackTitle: track.title,
        audioPath: track.path,
        lyricsPath: lyricsPath,
      ),
    );
  }

  Future<void> renameMusicTrack(
    LocalMusicTrack track,
    String rawName,
  ) async {
    final sanitizedName = _sanitizeFileStem(rawName);
    if (sanitizedName == null) {
      awemeMessage.value = '文件名不能为空';
      throw StateError('文件名不能为空');
    }

    final oldAudioPath = track.path;
    final newAudioPath = p.join(
      p.dirname(oldAudioPath),
      '$sanitizedName${p.extension(oldAudioPath)}',
    );
    if (newAudioPath == oldAudioPath) {
      awemeMessage.value = '文件名未发生变化';
      return;
    }

    final oldAudioFile = File(oldAudioPath);
    if (!await oldAudioFile.exists()) {
      awemeMessage.value = '原音频文件不存在';
      throw FileSystemException('原音频文件不存在', oldAudioPath);
    }

    final newAudioFile = File(newAudioPath);
    if (await newAudioFile.exists()) {
      awemeMessage.value = '已存在同名音乐文件';
      throw FileSystemException('已存在同名音乐文件', newAudioPath);
    }

    final oldLyricsPath = await _resolveLyricsPath(oldAudioPath);
    final newLyricsPath = oldLyricsPath == null
        ? null
        : LyricsRecognitionTool.lrcPathFor(newAudioPath);
    if (newLyricsPath != null &&
        newLyricsPath != oldLyricsPath &&
        await File(newLyricsPath).exists()) {
      awemeMessage.value = '已存在同名歌词文件';
      throw FileSystemException('已存在同名歌词文件', newLyricsPath);
    }

    final wasCurrentTrack = currentPlayingAudioPath.value == oldAudioPath;
    final shouldResumePlayback = wasCurrentTrack && musicPlaying.value;
    if (wasCurrentTrack) {
      await _audioPlayer?.stop();
      currentPlayingAudioPath.value = newAudioPath;
    }

    try {
      await oldAudioFile.rename(newAudioPath);
      if (oldLyricsPath != null && newLyricsPath != null) {
        await File(oldLyricsPath).rename(newLyricsPath);
      }
      lyricsByAudioPath.remove(oldAudioPath);
      if (newLyricsPath != null) {
        lyricsByAudioPath[newAudioPath] = newLyricsPath;
      }
      await refreshLocalMusicList();

      final renamedIndex =
          musicList.indexWhere((item) => item.path == newAudioPath);
      if (renamedIndex >= 0) {
        currentTrackIndex.value =
            wasCurrentTrack ? renamedIndex : currentTrackIndex.value;
        if (shouldResumePlayback) {
          await _playFromIndex(renamedIndex);
        }
      }

      awemeMessage.value = '已重命名为：$sanitizedName';
      Get.snackbar(
        '重命名成功',
        sanitizedName,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (wasCurrentTrack) {
        currentPlayingAudioPath.value = oldAudioPath;
      }
      rethrow;
    }
  }

  Future<void> deleteMusicTrack(LocalMusicTrack track) async {
    final removedIndex =
        musicList.indexWhere((item) => item.path == track.path);
    final lyricsPath = await _resolveLyricsPath(track.path);
    final wasCurrentTrack = currentPlayingAudioPath.value == track.path;

    if (wasCurrentTrack) {
      await _audioPlayer?.stop();
      currentPlayingAudioPath.value = null;
      currentTrackIndex.value = null;
      musicPlaying.value = false;
    }

    try {
      final audioFile = File(track.path);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      if (lyricsPath != null) {
        final lyricsFile = File(lyricsPath);
        if (await lyricsFile.exists()) {
          await lyricsFile.delete();
        }
      }
      musicList.removeWhere((item) => item.path == track.path);
      lyricsByAudioPath.remove(track.path);
      if (!wasCurrentTrack && currentPlayingAudioPath.value != null) {
        final currentIndex = musicList.indexWhere(
          (item) => item.path == currentPlayingAudioPath.value,
        );
        currentTrackIndex.value = currentIndex < 0 ? null : currentIndex;
      }
      awemeMessage.value = '已删除：${track.title}';
    } catch (e) {
      if (wasCurrentTrack && removedIndex >= 0) {
        currentPlayingAudioPath.value = track.path;
        currentTrackIndex.value = removedIndex;
      }
      awemeMessage.value = '删除失败：$e';
      rethrow;
    }
  }

  Future<void> deleteVideoTrack(LocalVideoTrack video) async {
    final wasCurrentVideo = currentPlayingVideoPath.value == video.path;
    if (wasCurrentVideo) {
      await _videoPlayer?.stop();
      currentPlayingVideoPath.value = null;
      videoPlaying.value = false;
    }

    try {
      final videoFile = File(video.path);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }
      videoList.removeWhere((item) => item.path == video.path);
      awemeMessage.value = '已删除：${video.title}';
    } catch (e) {
      awemeMessage.value = '删除失败：$e';
      rethrow;
    }
  }

  Future<void> _playFromIndex(int index) async {
    final tracks = musicList.toList(growable: false);
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
    await _player.open(
      Playlist(
        tracks
            .map(
              (item) => Media(
                item.path,
                extras: {'sourcePath': item.path},
              ),
            )
            .toList(growable: false),
        index: index,
      ),
    );
    await _applyPlaybackMode();
  }

  Future<void> _applyPlaybackMode() async {
    switch (playbackMode.value) {
      case MusicPlaybackMode.listLoop:
        await _audioPlayer?.setShuffle(false);
        await _audioPlayer?.setPlaylistMode(PlaylistMode.loop);
        break;
      case MusicPlaybackMode.singleLoop:
        await _audioPlayer?.setShuffle(false);
        await _audioPlayer?.setPlaylistMode(PlaylistMode.single);
        break;
      case MusicPlaybackMode.shuffle:
        await _audioPlayer?.setPlaylistMode(PlaylistMode.loop);
        await _audioPlayer?.setShuffle(true);
        break;
    }
  }

  void _rememberAudio(
    String audioPath, {
    required Map<String, dynamic> summary,
    String? titleOverride,
  }) {
    savedAudioPath.value = audioPath;
    final title = titleOverride?.trim().isNotEmpty == true
        ? titleOverride!.trim()
        : _trackTitle(summary, fallback: p.basenameWithoutExtension(audioPath));
    final lrcPath = LyricsRecognitionTool.lrcPathFor(audioPath);
    if (File(lrcPath).existsSync()) {
      lyricsByAudioPath[audioPath] = lrcPath;
    } else {
      lyricsByAudioPath.remove(audioPath);
    }
    musicList.removeWhere((item) => item.path == audioPath);
    musicList.insert(0, LocalMusicTrack(title: title, path: audioPath));
  }

  void _rememberVideo(
    String videoPath, {
    required Map<String, dynamic> summary,
    String? titleOverride,
  }) {
    savedVideoPath.value = videoPath;
    final title = titleOverride?.trim().isNotEmpty == true
        ? titleOverride!.trim()
        : _trackTitle(summary, fallback: p.basenameWithoutExtension(videoPath));
    videoList.removeWhere((item) => item.path == videoPath);
    videoList.insert(0, LocalVideoTrack(title: title, path: videoPath));
  }

  // ignore: unused_element
  Future<String?> _rememberAudioAndGenerateLyrics(
    String audioPath, {
    required Map<String, dynamic> summary,
    String? titleOverride,
  }) async {
    savedAudioPath.value = audioPath;
    _rememberAudio(audioPath, summary: summary, titleOverride: titleOverride);
    awemeMessage.value = '正在识别歌词...';
    return _generateLyricsFile(audioPath);
  }

  Future<String?> _generateLyricsFile(String audioPath) async {
    if (generatingLyrics.value) return null;
    generatingLyrics.value = true;
    recognizingLyricsPath.value = audioPath;
    try {
      final path = await lyricsTool.generateLrc(audioPath);
      generatedLyricsPath.value = path;
      lyricsByAudioPath[audioPath] = path;
      return path;
    } catch (e) {
      awemeMessage.value = '歌词识别失败：$e';
      return null;
    } finally {
      generatingLyrics.value = false;
      recognizingLyricsPath.value = null;
    }
  }

  String? _customAudioOutputPath(String videoPath) {
    final title = _customMusicTitle();
    if (title == null) return null;
    return p.join(p.dirname(videoPath), '$title.aac');
  }

  Future<String> _buildDirectMusicOutputPath({
    required String awemeId,
    required Map<String, dynamic>? summary,
  }) async {
    final fileStem =
        _customMusicTitle() ?? _downloadFileStem(summary, fallback: awemeId);
    final sanitizedStem = _sanitizeFileStem(fileStem) ?? awemeId;
    return p.join(await _downloadDirectory(awemeId), '$sanitizedStem.mp3');
  }

  Future<String> _buildVideoOutputPath({
    required String awemeId,
    required Map<String, dynamic>? summary,
  }) async {
    final fileStem =
        _customMusicTitle() ?? _downloadFileStem(summary, fallback: awemeId);
    final sanitizedStem = _sanitizeFileStem(fileStem) ?? awemeId;
    return p.join(await _downloadDirectory(awemeId), '$sanitizedStem.mp4');
  }

  String? _customMusicTitle() {
    return _sanitizeFileStem(musicName.text);
  }

  Future<String> _buildAutoOutputPath({
    required String awemeId,
    Map<String, dynamic>? summary,
    String? directory,
  }) async {
    final fileStem = _downloadFileStem(summary, fallback: awemeId);
    final sanitizedStem = _sanitizeFileStem(fileStem) ?? awemeId;
    return p.join(
        directory ?? await _downloadDirectory(awemeId), '$sanitizedStem.mp4');
  }

  Future<String> _downloadDirectory(String awemeId) async {
    final customPath = outputPath.text.trim();
    if (supportsCustomDownloadDirectory && customPath.isNotEmpty) {
      return p.dirname(customPath);
    }
    final defaultPath = await tool.defaultDownloadPath(awemeId);
    return p.dirname(defaultPath);
  }

  String? _sanitizeFileStem(String rawName) {
    final sanitized = rawName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    if (sanitized.isEmpty) return null;
    return p.basenameWithoutExtension(sanitized);
  }

  Future<String?> _resolveLyricsPath(String audioPath) async {
    final cached = lyricsByAudioPath[audioPath];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }
    final lrcPath = LyricsRecognitionTool.lrcPathFor(audioPath);
    if (await File(lrcPath).exists()) {
      lyricsByAudioPath[audioPath] = lrcPath;
      return lrcPath;
    }
    lyricsByAudioPath.remove(audioPath);
    return null;
  }

  String _trackTitle(
    Map<String, dynamic> summary, {
    required String fallback,
  }) {
    final itemTitle = '${summary['item_title'] ?? ''}'.trim();
    if (itemTitle.isNotEmpty) return itemTitle;
    final desc = '${summary['desc'] ?? ''}'.trim();
    final author = '${summary['author_nickname'] ?? ''}'.trim();
    if (desc.isEmpty && author.isEmpty) return fallback;
    if (author.isEmpty) return desc;
    if (desc.isEmpty) return author;
    return '$author - $desc';
  }

  String _downloadFileStem(
    Map<String, dynamic>? summary, {
    required String fallback,
  }) {
    if (summary == null) return fallback;
    final itemTitle = '${summary['item_title'] ?? ''}'.trim();
    if (itemTitle.isNotEmpty) return itemTitle;
    final desc = '${summary['desc'] ?? ''}'.trim();
    if (desc.isNotEmpty) return desc;
    final author = '${summary['author_nickname'] ?? ''}'.trim();
    if (author.isNotEmpty) return author;
    return fallback;
  }

  static bool isAudioPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.aac':
      case '.mp3':
      case '.m4a':
      case '.ogg':
      case '.opus':
      case '.flac':
      case '.wav':
        return true;
      default:
        return false;
    }
  }

  static bool isVideoPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.mp4':
      case '.mov':
      case '.m4v':
      case '.webm':
      case '.mkv':
      case '.avi':
        return true;
      default:
        return false;
    }
  }

  String? parseShareText(String text) {
    final urlRegex = RegExp(
      r'https?://[^\s，,。、）)\]】]+',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text.trim());
    if (match == null) return null;
    return match.group(0);
  }

  String? extractAwemeIdFromUrl(String url) {
    final patterns = [
      RegExp(r'iesdouyin\.com/share/video/(\d+)'),
      RegExp(r'douyin\.com/video/(\d+)'),
      RegExp(r'/video/(\d+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  Future<String?> extractAwemeIdFromShareText() async {
    final text = shareText.text.trim();
    if (text.isEmpty) {
      awemeMessage.value = '请粘贴抖音分享文本';
      return null;
    }
    final initialUrl = parseShareText(text);
    if (initialUrl == null) {
      awemeMessage.value = '未找到可解析的链接';
      return null;
    }
    final result = await showDialog<String>(
      context: Get.context!,
      builder: (_) => _AwemeIdExtractorDialog(initialUrl: initialUrl),
    );
    if (result != null) {
      awemeId.text = result;
      awemeMessage.value = '已提取 aweme_id：$result';
    }
    return result;
  }

  Future<void> showAwemeIdExtractorDialog() async {
    await extractAwemeIdFromShareText();
  }
}

class _AwemeIdExtractorDialog extends StatefulWidget {
  const _AwemeIdExtractorDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_AwemeIdExtractorDialog> createState() =>
      _AwemeIdExtractorDialogState();
}

class _AwemeIdExtractorDialogState extends State<_AwemeIdExtractorDialog> {
  final _currentUrl = ''.obs;
  final _extractedId = Rxn<String>();
  final _progress = 0.obs;

  @override
  void initState() {
    super.initState();
    _currentUrl.value = widget.initialUrl;
  }

  void _tryExtractFromUrl(String url) {
    _currentUrl.value = url;
    final c = Get.find<DouyinVideoDownloaderController>();
    final id = c.extractAwemeIdFromUrl(url);
    if (id != null && _extractedId.value == null) {
      _extractedId.value = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('解析分享链接'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          children: [
            Obx(() {
              if (_extractedId.value != null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('已提取 aweme_id：'),
                      const SizedBox(height: 4),
                      SelectableText(
                        _extractedId.value!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 12),
            Obx(() {
              if (_progress.value > 0 && _progress.value < 100) {
                return LinearProgressIndicator(value: _progress.value / 100);
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 8),
            Obx(() => SelectableText(
                  _currentUrl.value,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall,
                )),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: webview.InAppWebView(
                  initialUrlRequest: webview.URLRequest(
                    url: webview.WebUri(widget.initialUrl),
                  ),
                  initialSettings: webview.InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    verticalScrollBarEnabled: true,
                  ),
                  onProgressChanged: (_, p) => _progress.value = p,
                  onLoadStart: (_, url) {
                    if (url != null) _tryExtractFromUrl(url.toString());
                  },
                  onLoadStop: (_, url) {
                    if (url != null) _tryExtractFromUrl(url.toString());
                  },
                  onUpdateVisitedHistory: (_, url, __) {
                    if (url != null) _tryExtractFromUrl(url.toString());
                  },
                  shouldOverrideUrlLoading: (controller, nav) async {
                    final url = nav.request.url?.toString() ?? '';
                    _tryExtractFromUrl(url);
                    return webview.NavigationActionPolicy.ALLOW;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '提示：页面会自动跳转，检测到 iesdouyin.com/share/video/xxx 链接时会自动提取 ID 并关闭弹窗。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        Obx(() => FilledButton.icon(
              onPressed: _extractedId.value == null
                  ? null
                  : () => Navigator.of(context).pop(_extractedId.value),
              icon: const Icon(Icons.check),
              label: const Text('使用此 ID'),
            )),
      ],
    );
  }
}
