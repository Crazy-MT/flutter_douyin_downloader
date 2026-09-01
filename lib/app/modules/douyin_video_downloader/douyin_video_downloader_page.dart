import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosted_ui_kit/frosted_ui_kit.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import 'package:code_zero/utils/utils.dart';
import 'douyin_video_downloader_controller.dart';

Color _panelFill(ThemeData theme) => Colors.white.withValues(alpha: 0.90);

Color _tileFill(ThemeData theme) => Colors.white.withValues(alpha: 0.94);

Color _accentColor(ThemeData theme) => Color.alphaBlend(
      Colors.black.withValues(alpha: 0.42),
      theme.colorScheme.tertiary,
    );

Color _accentFill(ThemeData theme) => Color.alphaBlend(
      Colors.black.withValues(alpha: 0.50),
      theme.colorScheme.tertiary,
    );

Color _onAccentFill(ThemeData theme) => theme.colorScheme.onInverseSurface;

Color _clearBorder(ThemeData theme, [double alpha = 0.34]) =>
    _accentColor(theme).withValues(alpha: alpha);

List<BoxShadow> _softShadow([double alpha = 0.08]) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: alpha),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ];

class DouyinVideoDownloaderPage
    extends GetView<DouyinVideoDownloaderController> {
  const DouyinVideoDownloaderPage({Key? key}) : super(key: key);

  static const _renameTrackAction = 'rename';
  static const _showTrackPathAction = 'path';
  // 暂时屏蔽歌词入口。恢复菜单时再打开这两个 action。
  // static const _generateLyricsAction = 'generateLyrics';
  // static const _viewLyricsAction = 'lyrics';
  static const _deleteTrackAction = 'delete';

  Future<bool> _downloadWithCookieGuide(
    BuildContext context,
    Future<bool> Function() download,
  ) async {
    if (!controller.needsCookieLoginBeforeDownload) {
      return download();
    }
    final login = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要登录获取 Cookie'),
        content: const Text('下载前请先登录抖音获取 Cookie，获取成功后再点击下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.login),
            label: const Text('去登录'),
          ),
        ],
      ),
    );
    if (login == true) {
      await controller.goToLoginAndGetCookie();
    }
    return false;
  }

  Future<void> _downloadAndCloseImportDialog(
    BuildContext context,
    Future<bool> Function() download,
  ) async {
    final success = await _downloadWithCookieGuide(context, download);
    if (!success || !context.mounted) return;
    controller.clearImportForm();
    Navigator.of(context).pop();
  }

  Widget _circleActionButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
    double size = 42,
    bool filled = false,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: IconTheme(
        data: IconThemeData(
          color: filled ? _onAccentFill(theme) : _accentColor(theme),
        ),
        child: CircleButton(
          onPressed: onPressed,
          icon: icon,
          size: size,
          sigmaX: 8,
          sigmaY: 8,
          glassColor: filled ? _accentFill(theme) : _tileFill(theme),
          borderColor: filled ? _accentFill(theme) : _clearBorder(theme, 0.42),
          boxShadow: _softShadow(filled ? 0.12 : 0.07),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 68,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('抖音资源'),
              Text(
                '视频和音乐',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FilledButton.icon(
                onPressed: () => _showImportDialog(context),
                icon: const Icon(Icons.library_add),
                label: const Text('导入'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentFill(theme),
                  foregroundColor: _onAccentFill(theme),
                  fixedSize: const Size(88, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _circleActionButton(
              context,
              onPressed: () => _showAdvancedSettingsDialog(context),
              icon: Icons.tune,
              tooltip: '高级设置',
              size: 44,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground(context)),
            Positioned.fill(
              child: _ClipboardImportGate(
                onImport: (text) {
                  controller.shareText.text = text;
                  _showImportDialog(context);
                },
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: _buildLibraryTabs(context),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildVideoLibrary(context),
                              _buildMusicLibrary(context),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _buildPlaylistHeader(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            theme.colorScheme.surface,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildImportPanel(BuildContext context) {
    final theme = Theme.of(context);
    final outline = _clearBorder(theme, 0.46);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: outline, width: 1.2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller.shareText,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '抖音分享文本',
            filled: true,
            fillColor: _tileFill(theme),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: inputBorder.copyWith(
              borderSide: BorderSide(color: _accentColor(theme), width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.musicName,
          decoration: InputDecoration(
            labelText: '资源名称',
            hintText: '不填则使用默认名称',
            filled: true,
            fillColor: _tileFill(theme),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: inputBorder.copyWith(
              borderSide: BorderSide(color: _accentColor(theme), width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            AppButton(
              onPressed: controller.pasteShareText,
              icon: Icons.content_paste,
              title: '粘贴分享',
              style: AppButtonStyle.glass,
              height: 42,
              backgroundColor: _tileFill(theme),
              borderColor: _clearBorder(theme, 0.42),
              iconColor: _accentColor(theme),
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                color: _accentColor(theme),
                fontWeight: FontWeight.w700,
              ),
              boxShadow: _softShadow(0.06),
            ),
            Obx(() {
              final busy = controller.busy;
              return AppButton(
                onPressed: () => _downloadAndCloseImportDialog(
                  context,
                  controller.downloadMusicFromShareText,
                ),
                isDisabled: busy,
                isLoading: busy,
                icon: Icons.music_note_rounded,
                title: '下载音乐',
                style: AppButtonStyle.colored,
                height: 42,
                backgroundColor: _accentFill(theme),
                borderColor: _accentFill(theme),
                iconColor: _onAccentFill(theme),
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: _onAccentFill(theme),
                  fontWeight: FontWeight.w700,
                ),
                boxShadow: _softShadow(0.12),
              );
            }),
            Obx(() {
              final busy = controller.busy;
              return AppButton(
                onPressed: () => _downloadAndCloseImportDialog(
                  context,
                  controller.downloadVideoFromShareText,
                ),
                isDisabled: busy,
                icon: Icons.movie_filter_outlined,
                title: '下载视频',
                style: AppButtonStyle.glass,
                height: 42,
                backgroundColor: _tileFill(theme),
                borderColor: _clearBorder(theme, 0.42),
                iconColor: _accentColor(theme),
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: _accentColor(theme),
                  fontWeight: FontWeight.w700,
                ),
                boxShadow: _softShadow(0.06),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() => _buildStatusPill(
              context,
              text: controller.primaryStatusText,
              active: controller.busy,
            )),
      ],
    );
  }

  Widget _buildStatusPill(
    BuildContext context, {
    required String text,
    required bool active,
    double? width,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? _accentColor(theme).withValues(alpha: 0.14)
              : _tileFill(theme),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? _accentColor(theme).withValues(alpha: 0.42)
                : _clearBorder(theme, 0.32),
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.sync : Icons.check_circle_outline,
              size: 18,
              color: _accentColor(theme),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLibrary(BuildContext context) {
    return Obx(() {
      final list = controller.videoList;
      if (list.isEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            _buildEmptyLibraryState(
              context,
              icon: Icons.video_library_outlined,
              title: '暂无本地视频',
              subtitle: '从右上角导入一个抖音视频吧。',
            ),
          ],
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildVideoTile(context, item, index);
        },
      );
    });
  }

  Widget _buildMusicLibrary(BuildContext context) {
    return Obx(() {
      final list = controller.musicList;
      if (list.isEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            _buildEmptyLibraryState(
              context,
              icon: Icons.library_music_outlined,
              title: '暂无本地音乐',
              subtitle: '从右上角导入一首抖音音乐吧。',
            ),
          ],
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildTrackTile(context, item);
        },
      );
    });
  }

  Widget _buildLibraryTabs(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: TabBar(
              labelColor: _accentColor(theme),
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: _accentColor(theme),
              indicatorWeight: 1,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: _clearBorder(theme, 0.18),
              tabs: [
                Tab(text: '视频 ${controller.videoList.length}'),
                Tab(text: '音乐 ${controller.musicList.length}'),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: controller.refreshLocalResourceLists,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            color: theme.colorScheme.onSurfaceVariant,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
          ),
        ],
      );
    });
  }

  Widget _buildPlaylistHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final currentTrack = controller.currentTrack;
      final currentIndex = controller.currentTrackIndex.value;
      final trackCount = controller.musicList.length;
      final subtitle = currentTrack == null
          ? controller.playbackModeLabel
          : '第 ${currentIndex == null ? '-' : currentIndex + 1} / $trackCount 首'
              ' · ${controller.playbackModeLabel}';
      return BlurredCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        radius: 18,
        color: _panelFill(theme),
        border: Border.all(
          color: _clearBorder(theme, 0.18),
          width: 1,
        ),
        sigmaX: 18,
        sigmaY: 18,
        boxShadow: _softShadow(0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accentColor(theme).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _clearBorder(theme, 0.18)),
                  ),
                  child: Icon(
                    controller.musicPlaying.value
                        ? Icons.graphic_eq_rounded
                        : Icons.queue_music_rounded,
                    size: 19,
                    color: _accentColor(theme),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTrack?.title ?? '还没有正在播放的音乐',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCompactControlButton(
                  context,
                  onPressed: controller.playPreviousTrack,
                  icon: Icons.skip_previous_rounded,
                  tooltip: '上一首',
                ),
                const SizedBox(width: 6),
                _buildCompactControlButton(
                  context,
                  onPressed: controller.togglePlayPause,
                  icon: controller.musicPlaying.value
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: controller.musicPlaying.value ? '暂停' : '播放',
                  filled: true,
                ),
                const SizedBox(width: 6),
                _buildCompactControlButton(
                  context,
                  onPressed: controller.playNextTrack,
                  icon: Icons.skip_next_rounded,
                  tooltip: '下一首',
                ),
                const SizedBox(width: 6),
                _buildCompactControlButton(
                  context,
                  onPressed: () async {
                    await controller.togglePlaybackMode();
                    Utils.showToastMsg('已切换到${controller.playbackModeLabel}');
                  },
                  icon: _playbackModeIcon(controller.playbackMode.value),
                  tooltip: controller.playbackModeLabel,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyLibraryState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return BlurredCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      radius: 24,
      color: _panelFill(theme),
      border: Border.all(
        color: _clearBorder(theme, 0.34),
        width: 1.2,
      ),
      sigmaX: 18,
      sigmaY: 18,
      boxShadow: _softShadow(0.06),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 44,
            color: _accentColor(theme),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactControlButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
    bool filled = false,
  }) {
    return _circleActionButton(
      context,
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      size: 34,
      filled: filled,
    );
  }

  IconData _playbackModeIcon(MusicPlaybackMode mode) {
    switch (mode) {
      case MusicPlaybackMode.listLoop:
        return Icons.repeat_rounded;
      case MusicPlaybackMode.singleLoop:
        return Icons.repeat_one_rounded;
      case MusicPlaybackMode.shuffle:
        return Icons.shuffle_rounded;
    }
  }

  String _resourceInfo(String path) {
    final type = p.extension(path).replaceFirst('.', '').toUpperCase();
    final size = _fileSizeText(path);
    return [
      if (type.isNotEmpty) type,
      '本地',
      if (size != null) size,
    ].join(' · ');
  }

  String? _fileSizeText(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes >= 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '$bytes B';
    } catch (_) {
      return null;
    }
  }

  Widget _buildVideoTile(
    BuildContext context,
    LocalVideoTrack item,
    int index,
  ) {
    final theme = Theme.of(context);
    return Obx(() {
      final isCurrent = controller.currentPlayingVideoPath.value == item.path;
      final playing = isCurrent && controller.videoPlaying.value;
      final videoController = controller.videoController;
      return BlurredCard(
        radius: 14,
        color: _tileFill(theme),
        border: Border.all(
          color: _accentColor(theme).withValues(alpha: isCurrent ? 0.24 : 0.10),
          width: 1,
        ),
        sigmaX: 14,
        sigmaY: 14,
        boxShadow: _softShadow(isCurrent ? 0.06 : 0.03),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () => controller.playVideo(item),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                minVerticalPadding: 6,
                leading: SizedBox(
                  width: 32,
                  child: Center(
                    child: isCurrent
                        ? Icon(
                            playing
                                ? Icons.play_circle_fill
                                : Icons.pause_circle_outline,
                            color: _accentColor(theme),
                          )
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => controller.playVideo(item),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            _accentColor(theme).withValues(alpha: 0.10),
                        side: BorderSide(color: _clearBorder(theme, 0.28)),
                      ),
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 30,
                      ),
                      color: _accentColor(theme),
                      tooltip: playing ? '暂停' : '播放',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: () => _showDeleteVideoDialog(context, item),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.78),
                        side: BorderSide(
                          color:
                              theme.colorScheme.error.withValues(alpha: 0.24),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      color: theme.colorScheme.error,
                      tooltip: '删除视频',
                    ),
                  ],
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isCurrent ? _accentColor(theme) : null,
                    fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  isCurrent
                      ? '当前${playing ? '正在播放' : '已暂停'} · ${_resourceInfo(item.path)}'
                      : _resourceInfo(item.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (isCurrent && videoController != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(controller: videoController),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildTrackTile(
    BuildContext context,
    LocalMusicTrack item,
  ) {
    final theme = Theme.of(context);
    return Obx(() {
      final isCurrent = controller.currentPlayingAudioPath.value == item.path;
      final playing = isCurrent && controller.musicPlaying.value;
      // 暂时屏蔽歌词入口。恢复时再展示已有歌词状态。
      // final recognizing = controller.recognizingLyricsPath.value == item.path;
      // final hasLyrics = controller.hasLyrics(item.path);
      // final lyricsPath = controller.lyricsPathFor(item.path);
      final subtitleText = isCurrent
          ? '当前${playing ? '正在播放' : '已暂停'} · ${_resourceInfo(item.path)}'
          : _resourceInfo(item.path);
      // final subtitleText = isCurrent
      //     ? '当前${playing ? '正在播放' : '已暂停'}'
      //     : hasLyrics
      //         ? '已生成歌词 · ${lyricsPath ?? item.path}'
      //         : item.path;
      return BlurredCard(
        radius: 12,
        color: _tileFill(theme),
        border: Border.all(
          color: _accentColor(theme).withValues(alpha: isCurrent ? 0.24 : 0.10),
          width: 1,
        ),
        sigmaX: 14,
        sigmaY: 14,
        boxShadow: _softShadow(isCurrent ? 0.05 : 0.02),
        child: SizedBox(
          height: 72,
          child: Stack(
            children: [
              if (isCurrent)
                Positioned(
                  left: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: _accentColor(theme),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => controller.playMusic(item),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                  minVerticalPadding: 0,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => controller.playMusic(item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 42,
                          height: 42,
                        ),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              _accentColor(theme).withValues(alpha: 0.10),
                          side: BorderSide(color: _clearBorder(theme, 0.22)),
                        ),
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 28,
                        ),
                        color: _accentColor(theme),
                        tooltip: playing ? '暂停' : '播放',
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: PopupMenuButton<String>(
                          tooltip: '更多操作',
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_horiz),
                          iconSize: 22,
                          onSelected: (value) async {
                            // 暂时屏蔽歌词入口。恢复菜单时再打开这两个分支。
                            // if (value == _viewLyricsAction) {
                            //   await controller.openLyricsPage(item);
                            //   return;
                            // }
                            // if (value == _generateLyricsAction) {
                            //   await controller.generateLyrics(item);
                            //   return;
                            // }
                            if (value == _showTrackPathAction) {
                              await _showTrackPathDialog(context, item);
                              return;
                            }
                            if (value == _renameTrackAction) {
                              await _showRenameDialog(context, item);
                              return;
                            }
                            if (value == _deleteTrackAction) {
                              await _showDeleteDialog(context, item);
                            }
                          },
                          itemBuilder: (context) => [
                            // 暂时屏蔽歌词入口。恢复菜单时再打开这两个菜单项。
                            // PopupMenuItem<String>(
                            //   value: _viewLyricsAction,
                            //   enabled: hasLyrics,
                            //   child: const ListTile(
                            //     contentPadding: EdgeInsets.zero,
                            //     leading: Icon(Icons.lyrics_outlined),
                            //     title: Text('查看歌词'),
                            //   ),
                            // ),
                            // PopupMenuItem<String>(
                            //   value: _generateLyricsAction,
                            //   enabled: !recognizing,
                            //   child: ListTile(
                            //     contentPadding: EdgeInsets.zero,
                            //     leading: recognizing
                            //         ? const SizedBox(
                            //             width: 24,
                            //             height: 24,
                            //             child: CircularProgressIndicator(strokeWidth: 2),
                            //           )
                            //         : Icon(
                            //             Icons.subtitles_rounded,
                            //             color:
                            //                 hasLyrics ? theme.colorScheme.primary : null,
                            //           ),
                            //     title: Text(hasLyrics ? '重新生成歌词' : '生成歌词'),
                            //   ),
                            // ),
                            const PopupMenuItem<String>(
                              value: _showTrackPathAction,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.folder_outlined),
                                title: Text('查看路径'),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: _renameTrackAction,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.drive_file_rename_outline),
                                title: Text('修改文件名'),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: _deleteTrackAction,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(
                                  '删除音乐',
                                  style:
                                      TextStyle(color: theme.colorScheme.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isCurrent ? _accentColor(theme) : null,
                      fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAdvancedSettings(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cookie_outlined),
            title: const Text('Cookie'),
            subtitle: Text(controller.hasSavedCookie.value ? '已保存' : '未保存'),
            trailing: IconButton(
              onPressed: controller.goToLoginAndGetCookie,
              icon: const Icon(Icons.login),
              tooltip: '登录',
            ),
          );
        }),
        // TextField(
        //   controller: controller.awemeId,
        //   decoration: InputDecoration(
        //     labelText: 'aweme_id',
        //     border: const OutlineInputBorder(),
        //     suffixIcon: IconButton(
        //       icon: const Icon(Icons.open_in_browser),
        //       onPressed: controller.showAwemeIdExtractorDialog,
        //       tooltip: '解析',
        //     ),
        //   ),
        // ),
        // const SizedBox(height: 12),
        if (controller.supportsCustomDownloadDirectory) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.outputPath,
            builder: (context, value, _) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: const Text('下载路径'),
                subtitle: Text(
                  controller.outputDirectoryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: OutlinedButton.icon(
                  onPressed: controller.selectOutputDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        Obx(() {
          final summary = controller.summary.value;
          if (summary == null) return const SizedBox.shrink();
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('视频详情'),
            children: [
              SizedBox(
                width: double.infinity,
                height: 220,
                child: SingleChildScrollView(
                  child: SelectableText(
                    controller.tool.encodeSummary(summary),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _showImportDialog(BuildContext context) {
    return _showPanelDialog(
      context,
      title: '导入资源',
      child: Builder(builder: _buildImportPanel),
    );
  }

  Future<void> _showAdvancedSettingsDialog(BuildContext context) {
    return _showPanelDialog(
      context,
      title: '高级设置',
      child: _buildAdvancedSettings(context),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    LocalMusicTrack track,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RenameTrackDialog(
        track: track,
        renameTrack: controller.renameMusicTrack,
      ),
    );
  }

  Future<void> _showTrackPathDialog(
    BuildContext context,
    LocalMusicTrack track,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(track.title),
        content: SelectableText(track.path),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    LocalMusicTrack track,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除音乐'),
        content: Text('确定删除「${track.title}」吗？本地音频和歌词都会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteMusicTrack(track);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  Future<void> _showDeleteVideoDialog(
    BuildContext context,
    LocalVideoTrack video,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定删除「${video.title}」吗？本地视频文件会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteVideoTrack(video);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  Future<void> _showPanelDialog(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
            maxHeight: 680,
          ),
          child: BlurredCard(
            radius: 28,
            color: _panelFill(Theme.of(dialogContext)),
            border: Border.all(
              color: _clearBorder(Theme.of(dialogContext), 0.42),
              width: 1.2,
            ),
            sigmaX: 20,
            sigmaY: 20,
            boxShadow: _softShadow(0.16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(dialogContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipboardImportGate extends StatefulWidget {
  const _ClipboardImportGate({required this.onImport});

  final ValueChanged<String> onImport;

  @override
  State<_ClipboardImportGate> createState() => _ClipboardImportGateState();
}

class _ClipboardImportGateState extends State<_ClipboardImportGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromClipboard());
  }

  Future<void> _openFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    widget.onImport(text);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _RenameTrackDialog extends StatefulWidget {
  const _RenameTrackDialog({
    required this.track,
    required this.renameTrack,
  });

  final LocalMusicTrack track;
  final Future<void> Function(LocalMusicTrack track, String rawName)
      renameTrack;

  @override
  State<_RenameTrackDialog> createState() => _RenameTrackDialogState();
}

class _RenameTrackDialogState extends State<_RenameTrackDialog> {
  late final TextEditingController _inputController;
  String? _errorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: p.basenameWithoutExtension(widget.track.path),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.renameTrack(widget.track, _inputController.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '重命名失败：$e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: BlurredCard(
        radius: 28,
        color: _panelFill(theme),
        border: Border.all(
          color: _clearBorder(theme, 0.42),
          width: 1.2,
        ),
        sigmaX: 20,
        sigmaY: 20,
        boxShadow: _softShadow(0.16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '修改音乐文件名',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _inputController,
                  autofocus: true,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: '文件名',
                    hintText: '不需要输入扩展名',
                    filled: true,
                    fillColor: _tileFill(theme),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _clearBorder(theme, 0.42)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _clearBorder(theme, 0.42)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _accentColor(theme),
                        width: 1.6,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
