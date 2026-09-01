import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:code_zero/douyin_api/aweme_detail_tool.dart';

void main() {
  test('android default download directory keeps public downloads', () {
    final appDownloads = Directory(
      '/storage/emulated/0/Android/data/app/files/Download',
    );
    final publicDownloads = Directory('/storage/emulated/0/Download');
    final documents = Directory('/data/user/0/app/files');

    final selected = AwemeDetailTool.pickAndroidDefaultDownloadDirectory(
      appDownloadDirectories: [appDownloads],
      publicDownloadDirectory: publicDownloads,
      documentsDirectory: documents,
    );

    expect(selected.path, publicDownloads.path);
  });
}
