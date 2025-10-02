import 'package:flutter/material.dart';

class FileDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> file;
  final void Function(Map<String, dynamic> file, String action) onAction;

  const FileDetailsScreen({
    super.key,
    required this.file,
    required this.onAction,
  });

  String _formatSize(int? size) {
    if (size == null) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final createdAt =
    file['createdAt'] is DateTime ? file['createdAt'] as DateTime : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(file['name'] ?? "Chi tiết"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              file['isFolder'] == true ? Icons.folder : Icons.insert_drive_file,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              file['name'] ?? "",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Ngày tạo: ${createdAt != null ? "${createdAt.day}/${createdAt.month}/${createdAt.year}" : "Không rõ"}"),
            Text("Dung lượng: ${_formatSize(file['size'])}"),
            if (file['description'] != null)
              Text("Mô tả: ${file['description']}"),
            const Spacer(),
            const Divider(),
            const Text(
              "Hành động",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove_red_eye),
                  label: const Text("Xem trước"),
                  onPressed: () => onAction(file, "preview"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.drive_file_rename_outline),
                  label: const Text("Đổi tên"),
                  onPressed: () => onAction(file, "rename"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Tải xuống"),
                  onPressed: () => onAction(file, "download"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Di chuyển"),
                  onPressed: () => onAction(file, "move"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Xóa"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => onAction(file, "delete"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
