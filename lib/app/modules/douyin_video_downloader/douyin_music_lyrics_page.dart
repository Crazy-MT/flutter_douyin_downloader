import 'dart:io';

import 'package:flutter/material.dart';

class DouyinMusicLyricsPage extends StatefulWidget {
  const DouyinMusicLyricsPage({
    Key? key,
    required this.trackTitle,
    required this.audioPath,
    required this.lyricsPath,
  }) : super(key: key);

  final String trackTitle;
  final String audioPath;
  final String lyricsPath;

  @override
  State<DouyinMusicLyricsPage> createState() => _DouyinMusicLyricsPageState();
}

class _DouyinMusicLyricsPageState extends State<DouyinMusicLyricsPage> {
  late final Future<_LyricsPageData> _lyricsFuture = _loadLyrics();

  Future<_LyricsPageData> _loadLyrics() async {
    final file = File(widget.lyricsPath);
    if (!await file.exists()) {
      throw FileSystemException('歌词文件不存在', widget.lyricsPath);
    }
    final rawText = await file.readAsString();
    final lines = _parseLyrics(rawText);
    return _LyricsPageData(rawText: rawText, lines: lines);
  }

  List<_LyricsLine> _parseLyrics(String rawText) {
    final result = <_LyricsLine>[];
    final timestampPattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\]');
    for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final matches = timestampPattern.allMatches(line).toList();
      final text = line.replaceAll(timestampPattern, '').trim();
      if (matches.isEmpty) {
        result.add(
            _LyricsLine(timestamp: null, text: text.isEmpty ? line : text));
        continue;
      }
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final centiseconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        result.add(
          _LyricsLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: centiseconds * 10,
            ),
            text: text,
          ),
        );
      }
    }
    return result;
  }

  String _formatTimestamp(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final centiseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds.$centiseconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trackTitle),
      ),
      body: FutureBuilder<_LyricsPageData>(
        future: _lyricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载歌词失败：${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data!;
          if (data.lines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                    data.rawText.isEmpty ? '歌词内容为空' : data.rawText),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '歌词文件',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.lyricsPath,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '音频文件：${widget.audioPath}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '歌词内容',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...data.lines.map(
                (line) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          line.timestamp == null
                              ? '--:--.--'
                              : _formatTimestamp(line.timestamp!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectableText(
                          line.text.isEmpty ? '...' : line.text,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LyricsPageData {
  const _LyricsPageData({
    required this.rawText,
    required this.lines,
  });

  final String rawText;
  final List<_LyricsLine> lines;
}

class _LyricsLine {
  const _LyricsLine({
    required this.timestamp,
    required this.text,
  });

  final Duration? timestamp;
  final String text;
}
