// lib/widgets/file_grid.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

class FileGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onTap;
  final void Function(Map<String, dynamic> item, String action) onAction;

  const FileGrid({
    Key? key,
    required this.items,
    required this.onTap,
    required this.onAction,
  }) : super(key: key);

  /// Xác định đang chạy desktop hay mobile
  bool get _isDesktop {
    if (kIsWeb) return true;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.macOS ||
        p == TargetPlatform.windows ||
        p == TargetPlatform.linux;
  }

  /// Chuyển dung lượng file thành chuỗi dễ đọc
  String _sizeToStr(int? size) {
    if (size == null) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text("Không có file hoặc thư mục"));
    }

    final width = MediaQuery.of(context).size.width;
    final crossCount = width >= 800 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isFolder = item['isFolder'] == true;
        final String name = (item['name'] ?? '').toString();
        final int? size = item['size'] is int ? item['size'] as int : null;
        final DateTime? createdAt =
        item['createdAt'] is DateTime ? item['createdAt'] as DateTime : null;

        // ✅ Số file con trong thư mục (nếu có)
        final int? childCount = item['childCount'] as int?;

        final nameWidget = Text(
          name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        );

        // ✅ Subtitle cho file/folder
        String subtitle;
        if (isFolder) {
          subtitle = 'Thư mục';
          if (childCount != null) {
            subtitle += ' • $childCount mục';
          }
        } else {
          subtitle = createdAt != null
              ? '${createdAt.day}/${createdAt.month}/${createdAt.year} • ${_sizeToStr(size)}'
              : _sizeToStr(size);
        }

        return GestureDetector(
          onTap: () => onTap(item),
          onLongPress: () {
            if (!_isDesktop) {
              // Mobile hiển thị tên đầy đủ
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(name),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // icon + menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isFolder ? Icons.folder : Icons.insert_drive_file,
                      size: 36,
                      color: isFolder ? Colors.amber : Colors.blueGrey,
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (action) => onAction(item, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'rename', child: Text('Đổi tên')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Xóa')),
                        const PopupMenuItem(
                            value: 'move', child: Text('Di chuyển')),
                        if (!isFolder)
                          const PopupMenuItem(
                              value: 'download', child: Text('Tải xuống')),
                        if (!isFolder)
                          const PopupMenuItem(
                              value: 'preview', child: Text('Xem trước')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // tên file (tooltip desktop, snackbar mobile)
                if (_isDesktop)
                  Tooltip(message: name, child: nameWidget)
                else
                  nameWidget,

                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
