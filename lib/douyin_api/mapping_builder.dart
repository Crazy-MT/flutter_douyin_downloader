import 'dart:convert';
import 'dart:io';

class MappingBuildResult {
  const MappingBuildResult({
    required this.total,
    required this.added,
    required this.outputPath,
    required this.logs,
  });

  final int total;
  final int added;
  final String outputPath;
  final List<String> logs;
}

class MappingBuilder {
  static const _s4Table =
      'Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe';

  Future<MappingBuildResult> build({
    required String repoRoot,
    required String outputPath,
    required int startTimestamp,
    required int stepMillis,
    required int count,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      throw UnsupportedError(
          '移动端不能直接运行 Node；请在 macOS/Windows 桌面端生成映射表后随 App 打包。');
    }

    final root = Directory(repoRoot);
    final bdms = File('${root.path}/lib/runtime/bdms/index.js');
    if (!bdms.existsSync()) {
      throw StateError('找不到 ${bdms.path}');
    }

    final output = File(outputPath);
    final mapping = output.existsSync()
        ? _readMapping(await output.readAsString())
        : <int, List<int>>{};
    final logs = <String>['已有样本: ${mapping.length}'];
    var added = 0;

    for (var i = 0; i < count; i++) {
      final timestamp = startTimestamp + i * stepMillis;
      if (mapping.containsKey(timestamp)) continue;

      final url =
          'https://www.douyin.com/aweme/v1/web/aweme/detail/?aweme_id=1&_t=$timestamp';
      var aBogus = '';
      var decodedLength = 0;
      for (var attempt = 1; attempt <= 20; attempt++) {
        aBogus = await _generateABogus(root.path, url);
        final decoded = _s4Decode(aBogus);
        decodedLength = decoded.length;
        if (decoded.length > 4) {
          mapping[timestamp] = decoded.sublist(4);
          added++;
          break;
        }
      }
      logs.add(
          '[$i/${count - 1}] T=$timestamp a_bogus=${aBogus.length} head=${aBogus.substring(0, aBogus.length < 12 ? aBogus.length : 12)} decoded=$decodedLength ${mapping.containsKey(timestamp) ? 'ok' : 'failed'}');
    }

    final sorted = Map.fromEntries(
      mapping.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(jsonEncode({
      for (final entry in sorted.entries) '${entry.key}': entry.value,
    }));

    return MappingBuildResult(
      total: sorted.length,
      added: added,
      outputPath: output.path,
      logs: logs,
    );
  }

  Map<int, List<int>> _readMapping(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        int.parse(entry.key): (entry.value as List<dynamic>).cast<int>(),
    };
  }

  Future<String> _generateABogus(String repoRoot, String url) async {
    const marker = '__ABOGUS__';
    final jsCode = '''
const { get_a_bogus } = require("./lib/runtime/bdms/index.js");
const r = get_a_bogus(${jsonEncode(url)}, "");
if (global._process) global.process = global._process;
console.log("$marker" + JSON.stringify({a_bogus:r}));
process.exit(0);
''';
    final result = await Process.run(
      '/bin/zsh',
      ['-lc', 'node -e ${_shellQuote(jsCode)}'],
      workingDirectory: repoRoot,
      environment: {
        'PATH': Platform.environment['PATH'] ??
            '/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin',
        if (Platform.environment['HOME'] != null)
          'HOME': Platform.environment['HOME']!,
      },
      includeParentEnvironment: false,
    ).timeout(const Duration(seconds: 30));
    for (final line in '${result.stdout}'.split('\n')) {
      final index = line.indexOf(marker);
      if (index != -1) {
        final decoded = jsonDecode(line.substring(index + marker.length))
            as Map<String, dynamic>;
        return decoded['a_bogus']?.toString() ?? '';
      }
    }
    throw StateError(
      'Node 未输出 a_bogus, code=${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}',
    );
  }

  String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  List<int> _s4Decode(String encoded) {
    final reverse = {for (var i = 0; i < _s4Table.length; i++) _s4Table[i]: i};
    final result = <int>[];
    for (var i = 0; i < encoded.length; i += 4) {
      final chunk = encoded.substring(i, (i + 4).clamp(0, encoded.length));
      if (chunk.length < 2) break;
      final b1 = reverse[chunk[0]] ?? 0;
      final b2 = reverse[chunk[1]] ?? 0;
      result.add((b1 << 2) | (b2 >> 4));
      if (chunk.length > 2 && reverse.containsKey(chunk[2])) {
        final b3 = reverse[chunk[2]]!;
        result.add(((b2 & 0x0f) << 4) | (b3 >> 2));
        if (chunk.length > 3 && reverse.containsKey(chunk[3])) {
          final b4 = reverse[chunk[3]]!;
          result.add(((b3 & 0x03) << 6) | b4);
        }
      }
    }
    return result;
  }
}
