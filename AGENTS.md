# Repository Guidelines

## 功能范围

本仓库的全部用户功能集中在 `DouyinVideoDownloaderPage`：获取抖音 Cookie、解析分享链接、
提取 `aweme_id`、获取视频详情、下载视频并提取音频。贡献时优先围绕这一条链路工作，不新增
无关页面、模块或通用平台能力。其它目录只作为该页面的依赖维护。

## 需求文档结构
- CodeGraph 使用约定
    - 当前项目存在 .codegraph/ 时，理解代码、定位流程、准备修改前优先使用 CodeGraph。
    - codegraph_explore 用于架构、流程、bug、区域浏览和大多数代码问题。
    - codegraph_node 用于读取单个符号或源码文件。
    - codegraph_callers 用于调用点和影响面分析。
    - 不要用 grep/read 重复验证 CodeGraph 已返回的结构性结果。
- 当你的记忆功能无法定位需求和代码入口的时候，先读 `docs/INDEX.md`，用“任务路由表”定位需求文档和代码入口。
- 不要从 `docs/` 全量读取开始；按 `docs/INDEX.md` 的关键词、必读章节、目标代码入口渐进读取。

## 文档渐进式管理

- 改动改变需求、已实现状态、待实现状态、验证方式或代码入口时，同步更新原需求文档和 `docs/INDEX.md`。
- 新增 `docs/` 文档时，必须在 `docs/INDEX.md` 补任务关键词、优先阅读、适用场景、目标代码入口和文档卡片。
- 跨 Flutter、Android overlay、iOS native 的行为，文档和索引必须写全三端入口。
- 用户明确给出的中文语义、标题、按钮文案、模式映射和流程顺序优先于通用最佳实践。



## 项目结构与模块组织

- `lib/app/modules/douyin_video_downloader/`：唯一功能页面、Controller 和 Binding。
- `lib/app/routes/app_routes.dart`、`lib/app/routes/app_pages.dart`：该页面的 GetX 路由入口。
- `lib/douyin_api/`：抖音请求、签名、视频详情、下载和默认路径等核心能力。
- `lib/utils/sp_helper.dart`：Cookie 等本地状态读取。
- `assets/douyin_reverse/`：抖音逆向相关资源；新增资源需同步 `pubspec.yaml`。
- `test/`：围绕链接解析、下载流程、路径生成和错误提示补测试。

## 构建、测试与开发命令
- flutter 版本3.47.1， 路径：/Users/maotong/fvm/versions/3.47.1
- `flutter pub get`：安装依赖。
- `flutter run`：运行页面并手动验证 Cookie、解析、下载、音频提取流程。
- `flutter test`：运行全部 Dart/Flutter 测试。
- `flutter test test/<name>_test.dart`：运行单个目标测试。
- `dart analyze lib/app/modules/douyin_video_downloader lib/douyin_api`：分析核心功能代码。
- `dart run build_runner build --delete-conflicting-outputs`：仅在改动生成代码依赖时执行。

## 代码风格与命名约定

沿用现有 GetX 写法：页面负责 UI，`DouyinVideoDownloaderController` 负责状态和流程编排，
下载、详情、签名逻辑留在 `lib/douyin_api/`。Dart 使用两个空格缩进；文件名使用
`lower_snake_case.dart`，类名使用 `UpperCamelCase`，成员使用 `lowerCamelCase`。先复用现有
helper、tool 和 request，不为单一页面增加新抽象或依赖。

## 测试规范

优先测试纯逻辑：分享文本提取 URL、URL 提取 `aweme_id`、空输入提示、下载路径同步和异常提示。
测试文件以 `_test.dart` 结尾，命名直接对应行为，例如 `douyin_share_link_parse_test.dart`。
涉及真实网络、Cookie 或文件下载时，尽量隔离为可 mock 的工具方法；无法自动化时在 PR 中写明手动验证步骤。

## 提交与 Pull Request 规范

提交信息用简短中文说明改动，例如 `修复抖音分享链接解析`。PR 必须说明影响的下载流程步骤、
验证命令和手动验证结果。涉及 UI 改动时附截图；涉及 Cookie、签名或下载行为时注明是否验证过真实抖音链接。

## 安全与配置提示

不要提交 Cookie、账号信息、下载产物、签名密钥或本机 SDK 路径。下载默认输出应指向用户目录，
不要写入源码目录。避免提交 `build/`、`.dart_tool/`、平台缓存和临时视频/音频文件。

## 完成标准

- 行为符合用户原话；涉及多个端或多个页面时，所有点名端都完成。
- 需求文档和 `docs/INDEX.md` 已按实际改动同步，或确认本次无需改文档。
- 代码入口、消息路径、路由和 native channel 没有只改一半。
- 已运行最小必要验证，并能说明命令、结果和任何无关环境噪音。
- `git diff --check` 通过，或明确说明无法运行及原因。
- git commit 信息必须是中文
- 工作区没有被无关格式化、生成物、缓存或用户改动污染。
