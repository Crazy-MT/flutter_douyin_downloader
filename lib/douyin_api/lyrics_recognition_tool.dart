import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class RecognizedLyricsLine {
  const RecognizedLyricsLine({
    required this.start,
    required this.text,
  });

  final Duration start;
  final String text;
}

class AudioSampleChunk {
  const AudioSampleChunk({
    required this.startSample,
    required this.endSample,
    required this.start,
  });

  final int startSample;
  final int endSample;
  final Duration start;
}

class LyricsRecognitionTool {
  LyricsRecognitionTool({
    Future<String> Function()? modelDirProvider,
    Future<Directory> Function()? supportDirProvider,
    Future<ByteData> Function(String)? assetLoader,
  })  : _manualModelDirProvider = modelDirProvider,
        _supportDirProvider =
            supportDirProvider ?? getApplicationSupportDirectory,
        _assetLoader = assetLoader ?? rootBundle.load;

  static const defaultModelName =
      'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17';
  static const defaultChunkDuration = Duration(seconds: 15);
  static const _assetModelDir = 'assets/asr_models/$defaultModelName';

  final Future<String> Function()? _manualModelDirProvider;
  final Future<Directory> Function() _supportDirProvider;
  final Future<ByteData> Function(String) _assetLoader;

  static bool _bindingsReady = false;

  Future<String> generateLrc(String audioPath) async {
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw FileSystemException('音频文件不存在', audioPath);
    }

    final modelDir = await prepareModelDir();
    await _ensureModelFiles(modelDir);

    final wavPath = p.join(
      Directory.systemTemp.path,
      'lyrics_${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    try {
      await _convertToWav(audioPath, wavPath);
      _initSherpa();

      final wave = sherpa.readWave(wavPath);
      if (wave.samples.isEmpty || wave.sampleRate <= 0) {
        throw StateError('无法读取用于识别的 wav 音频');
      }

      final recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            senseVoice: sherpa.OfflineSenseVoiceModelConfig(
              model: p.join(modelDir, 'model.int8.onnx'),
              language: 'auto',
              useInverseTextNormalization: true,
            ),
            tokens: p.join(modelDir, 'tokens.txt'),
            modelType: 'sense-voice',
            numThreads: 2,
            debug: false,
          ),
        ),
      );
      try {
        final lines = _recognizeChunks(
          recognizer: recognizer,
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
        if (lines.isEmpty) {
          throw StateError('未识别到歌词文本');
        }
        final lrcPath = lrcPathFor(audioPath);
        await File(lrcPath).writeAsString(formatLrc(lines));
        return lrcPath;
      } finally {
        recognizer.free();
      }
    } finally {
      final wav = File(wavPath);
      if (await wav.exists()) {
        try {
          await wav.delete();
        } catch (_) {}
      }
    }
  }

  static String lrcPathFor(String audioPath) {
    return p.setExtension(audioPath, '.lrc');
  }

  static String formatLrc(List<RecognizedLyricsLine> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      buffer.writeln('${_formatTimestamp(line.start)}$text');
    }
    return buffer.toString();
  }

  static List<AudioSampleChunk> sampleChunks({
    required int sampleCount,
    required int sampleRate,
    Duration chunkDuration = defaultChunkDuration,
  }) {
    if (sampleCount <= 0 || sampleRate <= 0) return const [];
    final chunkSamples = sampleRate * chunkDuration.inMilliseconds ~/ 1000;
    if (chunkSamples <= 0) return const [];
    final chunks = <AudioSampleChunk>[];
    for (var start = 0; start < sampleCount; start += chunkSamples) {
      final end = (start + chunkSamples).clamp(0, sampleCount);
      chunks.add(
        AudioSampleChunk(
          startSample: start,
          endSample: end,
          start: Duration(milliseconds: start * 1000 ~/ sampleRate),
        ),
      );
    }
    return chunks;
  }

  Future<String> prepareModelDir() async {
    final manualDir = _manualModelDirProvider;
    if (manualDir != null) return manualDir();

    final dir = await _supportDirProvider();
    final modelDir = p.join(dir.path, 'asr_models', defaultModelName);
    await Directory(modelDir).create(recursive: true);
    await _copyAssetModelFile(modelDir, 'model.int8.onnx');
    await _copyAssetModelFile(modelDir, 'tokens.txt');
    return modelDir;
  }

  Future<void> _copyAssetModelFile(String modelDir, String fileName) async {
    final assetKey = '$_assetModelDir/$fileName';
    late final ByteData data;
    try {
      data = await _assetLoader(assetKey);
    } on FlutterError catch (e) {
      throw StateError(
        '未找到 ASR 模型资源：$assetKey。'
        '请确认 `pubspec.yaml` 已声明 `assets/asr_models/`，执行 `flutter pub get`，并完全重启应用后再试。'
        '原始错误：${e.message}',
      );
    } catch (e) {
      throw StateError(
        '加载 ASR 模型资源失败：$assetKey，错误：$e',
      );
    }
    final target = File(p.join(modelDir, fileName));
    if (await target.exists() && await target.length() == data.lengthInBytes) {
      return;
    }
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await target.writeAsBytes(bytes);
  }

  static Future<void> _ensureModelFiles(String modelDir) async {
    final missing = <String>[
      p.join(modelDir, 'model.int8.onnx'),
      p.join(modelDir, 'tokens.txt'),
    ].where((path) => !File(path).existsSync()).toList();
    if (missing.isEmpty) return;
    throw StateError(
      '未找到 ASR 模型文件：${p.basename(missing.first)}。请把 SenseVoice 模型放到：$modelDir',
    );
  }

  List<RecognizedLyricsLine> _recognizeChunks({
    required sherpa.OfflineRecognizer recognizer,
    required Float32List samples,
    required int sampleRate,
  }) {
    final lines = <RecognizedLyricsLine>[];
    for (final chunk in sampleChunks(
      sampleCount: samples.length,
      sampleRate: sampleRate,
    )) {
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: Float32List.sublistView(
            samples,
            chunk.startSample,
            chunk.endSample,
          ),
          sampleRate: sampleRate,
        );
        recognizer.decode(stream);
        final text = _cleanRecognizedText(recognizer.getResult(stream).text);
        if (text.isNotEmpty) {
          lines.add(RecognizedLyricsLine(start: chunk.start, text: text));
        }
      } finally {
        stream.free();
      }
    }
    return lines;
  }

  static String _cleanRecognizedText(String text) {
    final buffer = StringBuffer();
    var insideTag = false;
    for (var i = 0; i < text.length; i++) {
      final current = text[i];
      final next = i + 1 < text.length ? text[i + 1] : '';
      if (!insideTag && current == '<' && next == '|') {
        insideTag = true;
        i++;
        continue;
      }
      if (insideTag && current == '|' && next == '>') {
        insideTag = false;
        i++;
        continue;
      }
      if (!insideTag) buffer.write(current);
    }
    return buffer.toString().trim();
  }

  static void _initSherpa() {
    if (_bindingsReady) return;
    sherpa.initBindings();
    _bindingsReady = true;
  }

  static Future<void> _convertToWav(String inputPath, String outputPath) async {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-ac',
      '1',
      '-ar',
      '16000',
      '-f',
      'wav',
      outputPath,
    ];

    if (Platform.isLinux || Platform.isWindows) {
      final result = await Process.run('ffmpeg', args);
      if (result.exitCode != 0) {
        throw StateError('ffmpeg 转换 wav 失败：${result.stderr}');
      }
      return;
    }

    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getLogs();
      throw StateError(
        'ffmpeg 转换 wav 失败：${logs.map((log) => log.getMessage()).join('\n')}',
      );
    }
  }

  static String _formatTimestamp(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(100).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final centiseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '[$minutes:$seconds.$centiseconds]';
  }
}
