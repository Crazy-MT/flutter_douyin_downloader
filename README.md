# 抖音资源下载器

Flutter/GetX 小工具，用于把抖音分享文本里的视频保存为本地视频，或下载成本地音乐播放。当前主流程集中在 `DouyinVideoDownloaderPage`：

```text
粘贴分享文本 -> 下载音乐/下载视频 -> 本地列表播放
```

## 功能

- 点击下载时若未保存抖音 Cookie，会先引导跳转登录并回填本地 Cookie。
- 支持从“分享 -> 复制链接”的完整文本中提取链接和 `aweme_id`。
- 优先直接下载 `aweme_detail.music.play_url` 音轨；失败时自动下载视频并提取音频。
- 支持下载并保存本地视频，视频列表内可直接播放和删除。
- 支持本地音乐列表、播放/暂停、上一首/下一首、重命名和删除。

## 环境

- Flutter：3.47.1，推荐使用仓库内 `.fvmrc`。
- Android 构建需要 JDK 17 或更高版本；本地用 `JAVA_HOME` 指定 JDK，不把本机 Java 路径写进仓库。

## 代码入口

- 页面和状态：`lib/app/modules/douyin_video_downloader/`
- 抖音请求、详情、下载、音频提取：`lib/douyin_api/`
- Cookie 本地状态：`lib/utils/sp_helper.dart`
- 路由：`lib/app/routes/app_routes.dart`、`lib/app/routes/app_pages.dart`

真实下载链路依赖有效 Cookie、抖音返回数据和网络状态。涉及 Cookie、签名或下载行为的改动，仍需要用真实分享文本手动验证一次。

## 免责声明

本项目仅用于个人学习与技术研究，不拥有、托管、分发或授权任何第三方视频、
音乐、元数据或平台数据。使用者应自行遵守相关平台协议、版权法律及所在地法规。
