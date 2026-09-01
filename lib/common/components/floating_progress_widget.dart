import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class FloatingProgressController extends GetxController {
  static FloatingProgressController get to => Get.find();

  var isShowing = false.obs;
  var progress = 0.0.obs;
  var statusText = ''.obs;

  OverlayEntry? _overlayEntry;

  void show(double initialProgress, String status) {
    progress.value = initialProgress;
    statusText.value = status;

    if (isShowing.value) return;

    isShowing.value = true;
    _overlayEntry = OverlayEntry(
      builder: (context) => _FloatingProgressView(),
    );

    if (Get.overlayContext != null) {
      Overlay.of(Get.overlayContext!)?.insert(_overlayEntry!);
    }
  }

  void updateProgress(double p, String status) {
    if (!isShowing.value) {
      show(p, status);
      return;
    }
    progress.value = p;
    statusText.value = status;
  }

  void dismiss() {
    if (!isShowing.value) return;
    isShowing.value = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _FloatingProgressView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100, // Positioned above typical bottom navigation bars
      child: Material(
        color: Colors.transparent,
        child: Obx(() {
          final controller = FloatingProgressController.to;
          return Container(
            width: 120.w,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        controller.statusText.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(controller.progress.value * 100).toInt()}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: controller.progress.value,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor),
                  minHeight: 4,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

void initFloatingProgress() {
  Get.put(FloatingProgressController());
}
