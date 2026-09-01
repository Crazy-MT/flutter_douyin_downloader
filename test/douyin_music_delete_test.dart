import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:code_zero/app/modules/douyin_video_downloader/douyin_video_downloader_controller.dart';
import 'package:code_zero/douyin_api/lyrics_recognition_tool.dart';

void main() {
  test('togglePlaybackMode cycles list, single, shuffle', () async {
    final controller = DouyinVideoDownloaderController();

    expect(controller.playbackMode.value, MusicPlaybackMode.listLoop);

    await controller.togglePlaybackMode();
    expect(controller.playbackMode.value, MusicPlaybackMode.singleLoop);

    await controller.togglePlaybackMode();
    expect(controller.playbackMode.value, MusicPlaybackMode.shuffle);

    await controller.togglePlaybackMode();
    expect(controller.playbackMode.value, MusicPlaybackMode.listLoop);
  });

  test('local resource path helpers split audio and video files', () {
    expect(DouyinVideoDownloaderController.isAudioPath('/tmp/a.MP3'), isTrue);
    expect(DouyinVideoDownloaderController.isAudioPath('/tmp/a.mp4'), isFalse);

    expect(DouyinVideoDownloaderController.isVideoPath('/tmp/v.MP4'), isTrue);
    expect(DouyinVideoDownloaderController.isVideoPath('/tmp/v.aac'), isFalse);
  });

  test('download requires cookie login guidance when cookie is missing', () {
    final controller = DouyinVideoDownloaderController();

    expect(controller.needsCookieLoginBeforeDownload, isTrue);

    controller.hasSavedCookie.value = true;

    expect(controller.needsCookieLoginBeforeDownload, isFalse);
  });

  test('deleteMusicTrack removes audio, lyrics, and list state', () async {
    final dir = await Directory.systemTemp.createTemp('douyin_music_delete_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final audio = File('${dir.path}/track.aac');
    await audio.writeAsString('audio');
    final lyrics = File(LyricsRecognitionTool.lrcPathFor(audio.path));
    await lyrics.writeAsString('[00:00.00]line');

    final controller = DouyinVideoDownloaderController()
      ..musicList.add(LocalMusicTrack(title: 'track', path: audio.path))
      ..lyricsByAudioPath[audio.path] = lyrics.path;

    await controller.deleteMusicTrack(controller.musicList.single);

    expect(await audio.exists(), isFalse);
    expect(await lyrics.exists(), isFalse);
    expect(controller.musicList, isEmpty);
    expect(controller.lyricsByAudioPath, isEmpty);
    expect(controller.awemeMessage.value, '已删除：track');
  });
}
