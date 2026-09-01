import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

class ABogusSigner {
  static const _s4Table =
      'Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe';

  final _random = Random.secure();
  Map<int, List<int>>? _timeMap;
  List<int>? _sortedTimes;
  List<int>? _keystream;

  int get mappingCount => _timeMap?.length ?? 0;

  Future<void> loadMappingFile(String path) async {
    final mappingText = await File(path).readAsString();
    _setMapping(jsonDecode(mappingText) as Map<String, dynamic>);
  }

  Future<String> generate() async {
    await _load();
    final bb = List<int>.from(_lookupBb(DateTime.now().millisecondsSinceEpoch));
    final key = _keystream!;
    final encrypted = <int>[];
    for (var i = 0; i < bb.length; i++) {
      encrypted.add(bb[i] ^ key[i % key.length]);
    }
    final finalBytes = <int>[
      for (var i = 0; i < 4; i++) _random.nextInt(256),
      ...encrypted,
    ];
    return _s4Encode(finalBytes);
  }

  Future<void> _load() async {
    if (_timeMap != null) return;

    final mappingText =
        await rootBundle.loadString('assets/signing/time_mapping_sample.json');
    _setMapping(jsonDecode(mappingText) as Map<String, dynamic>);

    final keyText =
        await rootBundle.loadString('assets/signing/FIXED_keystream.json');
    final keyJson = jsonDecode(keyText) as Map<String, dynamic>;
    _keystream = (keyJson['bb_keystream'] as List<dynamic>).cast<int>();
  }

  void _setMapping(Map<String, dynamic> mappingJson) {
    _timeMap = {
      for (final entry in mappingJson.entries)
        int.parse(entry.key): (entry.value as List<dynamic>).cast<int>(),
    };
    _sortedTimes = _timeMap!.keys.toList()..sort();
  }

  List<int> _lookupBb(int timestamp) {
    final exact = _timeMap![timestamp];
    if (exact != null) return exact;

    final times = _sortedTimes!;
    if (timestamp < times.first) return _timeMap![times.first]!;
    if (timestamp > times.last) return _timeMap![times.last]!;

    var left = 0;
    var right = times.length - 1;
    while (right - left > 1) {
      final mid = (left + right) ~/ 2;
      if (times[mid] < timestamp) {
        left = mid;
      } else {
        right = mid;
      }
    }
    final t1 = times[left];
    final t2 = times[right];
    return _timeMap![
        (timestamp - t1).abs() < (timestamp - t2).abs() ? t1 : t2]!;
  }

  String _s4Encode(List<int> data) {
    final result = StringBuffer();
    var i = 0;
    while (i < data.length) {
      final b1 = data[i];
      if (i + 2 < data.length) {
        final b2 = data[i + 1];
        final b3 = data[i + 2];
        result
          ..write(_s4Table[(b1 >> 2) & 0x3f])
          ..write(_s4Table[((b1 << 4) | (b2 >> 4)) & 0x3f])
          ..write(_s4Table[((b2 << 2) | (b3 >> 6)) & 0x3f])
          ..write(_s4Table[b3 & 0x3f]);
        i += 3;
      } else if (i + 1 < data.length) {
        final b2 = data[i + 1];
        result
          ..write(_s4Table[(b1 >> 2) & 0x3f])
          ..write(_s4Table[((b1 << 4) | (b2 >> 4)) & 0x3f])
          ..write(_s4Table[(b2 << 2) & 0x3f]);
        i += 2;
      } else {
        result
          ..write(_s4Table[(b1 >> 2) & 0x3f])
          ..write(_s4Table[(b1 << 4) & 0x3f]);
        i += 1;
      }
    }
    return result.toString();
  }
}
