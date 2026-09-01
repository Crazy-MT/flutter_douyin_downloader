import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:media_kit_video/media_kit_video.dart';

Widget buildPlayerOverlay(
    Rxn<String> currentPlayingUrl,
    Rxn<String> currentPlayingTitle,
    VideoController? videoController,
    VoidCallback func) {
  return Positioned(
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    child: GestureDetector(
      onTap: () {}, // To prevent clicks from passing through
      child: Container(
        color: Colors.black54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Obx(() => currentPlayingUrl.value!.endsWith('.mp3')
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note,
                          size: 100, color: Colors.white),
                      const SizedBox(height: 20),
                      Text(currentPlayingTitle.value ?? 'Playing Audio...',
                          style: const TextStyle(color: Colors.white)),
                    ],
                  )
                : (videoController != null)
                    ? Focus(
                        autofocus: true,
                        onKey: (FocusNode node, RawKeyEvent event) {
                          // 拦截空格键事件
                          if (event.logicalKey == LogicalKeyboardKey.space &&
                              event is RawKeyDownEvent) {
                            return KeyEventResult.handled; // 阻止默认行为
                          }
                          return KeyEventResult.ignored; // 其他按键正常处理
                        },
                        child: Video(controller: videoController))
                    : const CircularProgressIndicator()),
            // Show loading for video
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: func,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
