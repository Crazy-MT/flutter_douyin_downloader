import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:code_zero/douyin_api/abogus_signer.dart';
import 'package:code_zero/douyin_api/aweme_detail_tool.dart';
import 'package:code_zero/douyin_api/douyin_endpoint.dart';
import 'package:code_zero/douyin_api/douyin_request.dart';
import 'package:code_zero/douyin_api/mapping_builder.dart';
import 'package:code_zero/app/routes/app_routes.dart';
import 'package:code_zero/utils/sp_helper.dart';
import 'package:code_zero/utils/log_utils.dart';

class DouyinDebuggerController extends GetxController {
  final cookieController = TextEditingController();
  final searchController = TextEditingController();
  final controllers = <String, TextEditingController>{}.obs;

  final signer = ABogusSigner();
  late final DouyinRequest request;

  final group = EndpointGroup.user.obs;
  final endpoint = userEndpoints.first.obs;
  final result = Rxn<DouyinResult>();
  final error = Rxn<String>();
  final loading = false.obs;

  final awemeId = TextEditingController();
  final shareText = TextEditingController();
  final outputPath = TextEditingController();
  final summary = Rxn<Map<String, dynamic>>();
  final awemeMessage = Rxn<String>();
  final awemeLoading = false.obs;
  final downloading = false.obs;
  final webViewLoading = false.obs;

  final repoRoot = TextEditingController();
  final mappingOutputPath = TextEditingController();
  final start = TextEditingController();
  final step = TextEditingController();
  final count = TextEditingController();
  final logs = <String>[].obs;
  final running = false.obs;

  List<DouyinEndpoint> get visibleEndpoints {
    final query = searchController.text.trim().toLowerCase();
    return allEndpoints.where((ep) {
      if (ep.group != group.value) return false;
      if (query.isEmpty) return true;
      return ep.title.toLowerCase().contains(query) ||
          ep.remoteUri.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    request = DouyinRequest(signer);
    _initDefaultCookie();
    _syncControllers();

    awemeId.text = '';
    _refreshDefaultOutputPath(force: true);
    awemeId.addListener(_syncDefaultOutputPath);

    final defaultRoot = _defaultRepoRoot();
    repoRoot.text = defaultRoot;
    mappingOutputPath.text =
        '$defaultRoot/douyin_flutter_debugger/assets/signing/time_mapping_sample.json';
    start.text = '${DateTime.now().millisecondsSinceEpoch}';
    step.text = '600000';
    count.text = '10';
  }

  @override
  void onClose() {
    cookieController.dispose();
    searchController.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    awemeId.removeListener(_syncDefaultOutputPath);
    awemeId.dispose();
    shareText.dispose();
    outputPath.dispose();
    repoRoot.dispose();
    mappingOutputPath.dispose();
    start.dispose();
    step.dispose();
    count.dispose();
    super.onClose();
  }

  void _initDefaultCookie() {
    final savedCookie = SpHelper.getDyCookie();
    if (savedCookie.isNotEmpty) {
      cookieController.text = savedCookie;
      lLog('DouyinDebuggerController._initDefaultCookie 从本地存储加载抖音 Cookie');
    }
  }

  Future<void> goToLoginAndGetCookie() async {
    final result = await Get.toNamed(RoutesID.DOUYIN_LOGIN_PAGE);
    lLog('DouyinDebuggerController.goToLoginAndGetCookie 返回结果: $result');
    if (result == 3) {
      final savedCookie = SpHelper.getDyCookie();
      lLog('DouyinDebuggerController.goToLoginAndGetCookie 返回结果: $savedCookie');
      if (savedCookie.isNotEmpty) {
        cookieController.text = savedCookie;
        lLog('DouyinDebuggerController.goToLoginAndGetCookie 已更新抖音 Cookie');
      }
    }
  }

  void _syncControllers() {
    final keys = {...endpoint.value.params, ...endpoint.value.defaults.keys};
    for (final key in keys) {
      controllers.putIfAbsent(
        key,
        () => TextEditingController(text: endpoint.value.defaults[key] ?? ''),
      );
      if (endpoint.value.defaults.containsKey(key) &&
          controllers[key]!.text.isEmpty) {
        controllers[key]!.text = endpoint.value.defaults[key]!;
      }
    }
  }

  Future<void> send() async {
    FocusScope.of(Get.context!).unfocus();
    loading.value = true;
    error.value = null;
    result.value = null;
    try {
      final input = {
        for (final entry in controllers.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      };
      final r = await request.send(
        endpoint.value,
        input,
        cookieController.text,
      );
      result.value = r;
    } catch (e) {
      error.value = '$e';
    } finally {
      loading.value = false;
    }
  }

  void selectEndpoint(DouyinEndpoint ep) {
    endpoint.value = ep;
    result.value = null;
    error.value = null;
    _syncControllers();
  }

  void changeGroup(EndpointGroup g) {
    group.value = g;
    endpoint.value =
        g == EndpointGroup.user ? userEndpoints.first : videoEndpoints.first;
    searchController.clear();
    result.value = null;
    error.value = null;
    _syncControllers();
  }

  void refreshSearch() {
    // no-op, used to trigger rebuild on search text change
  }

  Future<void> showMappingDialog() async {
    final output = await showDialog<String>(
      context: Get.context!,
      builder: (_) => const _MappingDialogView(),
    );
    if (output == null) return;
    try {
      await signer.loadMappingFile(output);
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(content: Text('已加载映射表：${signer.mappingCount} 样本')),
      );
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(content: Text('加载映射表失败：$e')),
      );
    }
  }

  Future<void> showAwemeToolDialog() async {
    await showDialog<void>(
      context: Get.context!,
      builder: (_) => _AwemeDetailDialogView(
        tool: AwemeDetailTool(request),
        cookie: cookieController.text,
      ),
    );
  }

  void _syncDefaultOutputPath() {
    final id = awemeId.text.trim();
    if (id.isEmpty) return;
    final current = outputPath.text.trim();
    if (current.isEmpty || RegExp(r'[/\\][^/\\]+\.mp4$').hasMatch(current)) {
      _refreshDefaultOutputPath();
    }
  }

  Future<void> _refreshDefaultOutputPath({bool force = false}) async {
    final id = awemeId.text.trim();
    if (id.isEmpty) return;
    final current = outputPath.text.trim();
    if (!force &&
        current.isNotEmpty &&
        !RegExp(r'[/\\][^/\\]+\.mp4$').hasMatch(current)) {
      return;
    }
    final path = await AwemeDetailTool(request).defaultDownloadPath(id);
    outputPath.text = path;
  }

  Future<void> fetchAweme(AwemeDetailTool tool, String cookie) async {
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
        cookie: cookie,
      );
      summary.value = s;
      awemeMessage.value = '已复制到剪贴板';
    } catch (e) {
      awemeMessage.value = '获取失败：$e';
      debugPrint(summary.toString());
      debugPrint(e.toString());
    } finally {
      awemeLoading.value = false;
    }
  }

  Future<void> downloadAweme(AwemeDetailTool tool, String cookie) async {
    final s = summary.value;
    if (s == null) {
      awemeMessage.value = '请先获取视频详情';
      return;
    }
    downloading.value = true;
    awemeMessage.value = null;
    try {
      final path = await tool.downloadVideo(
        summary: s,
        awemeId: awemeId.text.trim(),
        cookie: cookie,
        outputPath: outputPath.text,
      );
      awemeMessage.value = '已下载: $path';
    } catch (e) {
      awemeMessage.value = '下载失败：$e';
    } finally {
      downloading.value = false;
    }
    debugPrint(awemeMessage.value);
  }

  Future<void> buildMapping() async {
    running.value = true;
    logs
      ..clear()
      ..add('开始生成...');
    try {
      final r = await MappingBuilder().build(
        repoRoot: repoRoot.text.trim(),
        outputPath: mappingOutputPath.text.trim(),
        startTimestamp: int.parse(start.text.trim()),
        stepMillis: int.parse(step.text.trim()),
        count: int.parse(count.text.trim()),
      );
      logs
        ..clear()
        ..addAll(r.logs)
        ..add('新增: ${r.added}, 总样本: ${r.total}')
        ..add('已保存: ${r.outputPath}');
    } catch (e) {
      logs.add('失败: $e');
    } finally {
      running.value = false;
    }
  }

  String _defaultRepoRoot() {
    final cwd = Directory.current.path;
    if (File('$cwd/lib/runtime/bdms/index.js').existsSync()) return cwd;
    final parent = Directory(cwd).parent.path;
    if (File('$parent/lib/runtime/bdms/index.js').existsSync()) return parent;
    return '/Users/maotong/Desktop/project/douyin-api';
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

  Future<void> showAwemeIdExtractorDialog() async {
    final text = shareText.text.trim();
    if (text.isEmpty) {
      awemeMessage.value = '请粘贴抖音分享文本';
      return;
    }
    final initialUrl = parseShareText(text);
    if (initialUrl == null) {
      awemeMessage.value = '未找到可解析的链接';
      return;
    }
    final result = await showDialog<String>(
      context: Get.context!,
      builder: (_) => _AwemeIdExtractorDialog(initialUrl: initialUrl),
    );
    if (result != null) {
      awemeId.text = result;
      awemeMessage.value = '已提取 aweme_id：$result';
    }
  }
}

class _AwemeDetailDialogView extends StatelessWidget {
  const _AwemeDetailDialogView({required this.tool, required this.cookie});

  final AwemeDetailTool tool;
  final String cookie;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DouyinDebuggerController>();
    return AlertDialog(
      title: const Text('视频详情脚本'),
      content: SizedBox(
        width: 720,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: c.shareText,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '抖音分享文本',
                hintText: '粘贴抖音「分享」→「复制链接」的完整文本',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: c.showAwemeIdExtractorDialog,
                  tooltip: '解析链接并提取 aweme_id',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: c.showAwemeIdExtractorDialog,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('解析分享链接'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.awemeId,
              decoration: const InputDecoration(
                labelText: 'aweme_id',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.outputPath,
              decoration: const InputDecoration(
                labelText: '下载路径',
                hintText: '建议保存到 Downloads',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              if (c.awemeMessage.value != null) {
                return Text(c.awemeMessage.value!);
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 260,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Obx(() {
                    final text = c.summary.value == null
                        ? '尚未获取'
                        : tool.encodeSummary(c.summary.value!);
                    return SelectableText(text);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (c.awemeLoading.value || c.downloading.value)
              ? null
              : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        Obx(() => FilledButton.icon(
              onPressed: c.awemeLoading.value
                  ? null
                  : () => c.fetchAweme(tool, cookie),
              icon: c.awemeLoading.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_copy),
              label: const Text('获取并复制'),
            )),
        Obx(() => FilledButton.tonalIcon(
              onPressed:
                  c.downloading.value ? null : () => c.downloadAweme(tool, cookie),
              icon: c.downloading.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: const Text('下载视频'),
            )),
      ],
    );
  }
}

class _MappingDialogView extends StatelessWidget {
  const _MappingDialogView();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DouyinDebuggerController>();
    return AlertDialog(
      title: const Text('生成 a_bogus 映射表'),
      content: SizedBox(
        width: 720,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('调用仓库里的 Node bdms 补环境生成 a_bogus，再解码出 140 字节 bb。'),
            const SizedBox(height: 12),
            TextField(
              controller: c.repoRoot,
              decoration: const InputDecoration(
                labelText: '仓库根目录',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.mappingOutputPath,
              decoration: const InputDecoration(
                labelText: '输出 JSON',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: c.start,
                    decoration: const InputDecoration(
                      labelText: '起始毫秒时间戳',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: c.step,
                    decoration: const InputDecoration(
                      labelText: '步长 ms',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: c.count,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Obx(() {
                    final text =
                        c.logs.isEmpty ? '尚未生成' : c.logs.join('\n');
                    return SelectableText(text);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: c.running.value ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        Obx(() => FilledButton.icon(
              onPressed: c.running.value ? null : c.buildMapping,
              icon: c.running.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('生成'),
            )),
        Obx(() => FilledButton.tonal(
              onPressed: c.running.value
                  ? null
                  : () => Navigator.pop(
                        context,
                        c.mappingOutputPath.text.trim(),
                      ),
              child: const Text('加载此表'),
            )),
      ],
    );
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
  webview.InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _currentUrl.value = widget.initialUrl;
  }

  void _tryExtractFromUrl(String url) {
    _currentUrl.value = url;
    final c = Get.find<DouyinDebuggerController>();
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
                  onWebViewCreated: (c) => _controller = c,
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
