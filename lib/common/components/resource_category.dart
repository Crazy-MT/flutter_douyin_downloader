import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

enum ResourceCategory {
  audioLocal(3),
  videoLocal(4),
  audioLibrary(1),
  videoLibrary(0);

  final int type;

  const ResourceCategory(this.type);

  int getType() {
    return type;
  }
}

extension ResourceCategoryExtension on ResourceCategory {
  String get label {
    switch (this) {
      case ResourceCategory.audioLocal:
        return '本地音频';
      case ResourceCategory.videoLocal:
        return '本地视频';
      case ResourceCategory.audioLibrary:
        return '云端音频';
      case ResourceCategory.videoLibrary:
        return '云端视频';
      default:
        return '';
    }
  }
}

/*
Future<ResourceCategory?> showMyBottomSheet(BuildContext context) async {
  return showModalBottomSheet<ResourceCategory>(
    context: context,
    builder: (BuildContext context) {
      return SafeArea( // Use SafeArea to avoid overlapping with system UI
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '请选择资源分类',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(height: 1.0),
            _buildBottomSheetItem(
              context: context,
              label: ResourceCategory.audioLocal.label,
              value: ResourceCategory.audioLocal,
            ),
            _buildBottomSheetItem(
              context: context,
              label: ResourceCategory.videoLocal.label,
              value: ResourceCategory.videoLocal,
            ),
            _buildBottomSheetItem(
              context: context,
              label: ResourceCategory.audioLibrary.label,
              value: ResourceCategory.audioLibrary,
            ),
            _buildBottomSheetItem(
              context: context,
              label: ResourceCategory.videoLibrary.label,
              value: ResourceCategory.videoLibrary,
            ),
            Divider(height: 1.0),
            InkWell(
              onTap: () {
                Navigator.pop(context, null); // Return null for "Cancel"
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    '取消',
                    style: TextStyle(fontSize: 16.0, color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
*/

/*
Widget _buildBottomSheetItem({
  required BuildContext context,
  required String label,
  required ResourceCategory value,
}) {
  return InkWell(
    onTap: () {
      Navigator.pop(context, value);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16.0),
          ),
        ],
      ),
    ),
  );
}*/
