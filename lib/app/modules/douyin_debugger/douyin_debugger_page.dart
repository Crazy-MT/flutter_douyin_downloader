import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'douyin_debugger_controller.dart';
import 'package:code_zero/douyin_api/douyin_endpoint.dart';
import 'package:code_zero/douyin_api/douyin_request.dart';

class DouyinDebuggerPage extends GetView<DouyinDebuggerController> {
  const DouyinDebuggerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Douyin API Debugger'),
        actions: [
          Obx(() => SegmentedButton<EndpointGroup>(
                segments: const [
                  ButtonSegment(
                    value: EndpointGroup.user,
                    icon: Icon(Icons.person_search),
                    label: Text('用户'),
                  ),
                  ButtonSegment(
                    value: EndpointGroup.video,
                    icon: Icon(Icons.smart_display),
                    label: Text('视频'),
                  ),
                ],
                selected: {controller.group.value},
                onSelectionChanged: (value) =>
                    controller.changeGroup(value.first),
              )),
          IconButton(
            tooltip: '生成映射表',
            onPressed: controller.showMappingDialog,
            icon: const Icon(Icons.table_chart),
          ),
          IconButton(
            tooltip: '视频详情脚本',
            onPressed: controller.showAwemeToolDialog,
            icon: const Icon(Icons.movie_filter),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 160,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: controller.searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索接口',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => controller.refreshSearch(),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final endpoints = controller.visibleEndpoints;
                    return ListView.builder(
                      itemCount: endpoints.length,
                      itemBuilder: (context, index) {
                        final endpoint = endpoints[index];
                        return Obx(() => ListTile(
                              selected: endpoint == controller.endpoint.value,
                              title: Text(
                                endpoint.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                endpoint.remoteUri,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => controller.selectEndpoint(endpoint),
                            ));
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Obx(() => Text(
                      controller.endpoint.value.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    )),
                const SizedBox(height: 6),
                Obx(() => SelectableText(
                      '${controller.endpoint.value.method.name.toUpperCase()} '
                      '${controller.endpoint.value.remoteUri}',
                    )),
                Obx(() {
                  if (controller.endpoint.value.needsWebSign) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '此接口 Python 版还会补 secsdk web-signature；'
                        'Dart 端先用于调参和验证 a_bogus。',
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.cookieController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Cookie',
                          hintText: '支持浏览器 cookie 字符串或 JSON cookie',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: controller.goToLoginAndGetCookie,
                      icon: const Icon(Icons.login),
                      label: const Text('去登录获取'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final ep = controller.endpoint.value;
                  final keys = {...ep.params, ...ep.defaults.keys};
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final key in keys)
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: controller.controllers[key],
                            decoration: InputDecoration(
                              labelText: key,
                              border: const OutlineInputBorder(),
                              suffixIcon: ep.defaults.containsKey(key)
                                  ? const Tooltip(
                                      message: '默认参数',
                                      child: Icon(Icons.tune),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Obx(() => FilledButton.icon(
                        onPressed:
                            controller.loading.value ? null : controller.send,
                        icon: controller.loading.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: const Text('发送请求'),
                      )),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  if (controller.error.value != null) {
                    return SelectableText(
                      controller.error.value!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                Obx(() {
                  if (controller.result.value != null) {
                    return _ResultView(result: controller.result.value!);
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final DouyinResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HTTP ${result.statusCode} · ${result.elapsed.inMilliseconds} ms',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SelectableText(result.url),
        if (result.warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              result.warning!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                result.body.isEmpty ? '<empty>' : result.body,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
