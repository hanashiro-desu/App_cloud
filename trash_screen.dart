// lib/trash_screen.dart
import 'package:flutter/material.dart';
import 'trash_service.dart';

class TrashScreen extends StatefulWidget {
  final TrashService trashService;

  const TrashScreen({super.key, required this.trashService});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    widget.trashService.getTrashFiles();
    widget.trashService.trashFilesNotifier.addListener(_onNotifier);
  }

  void _onNotifier() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.trashService.trashFilesNotifier.removeListener(_onNotifier);
    Navigator.pop(context, _changed);
    super.dispose();
  }

  /// 🔄 Hàm hiển thị loading spinner
  Future<T> _withLoading<T>(Future<T> Function() action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await action();
    } finally {
      if (mounted) Navigator.pop(context); // đóng loading
    }
  }

  Future<void> _restoreFile(String id) async {
    final restoredPath = await _withLoading(() => widget.trashService.restoreFile(id));
    if (!mounted) return;
    if (restoredPath != null) {
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã khôi phục: $restoredPath')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khôi phục thất bại')),
      );
    }
  }

  Future<void> _deleteFile(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa vĩnh viễn'),
        content: const Text('Bạn có chắc muốn xóa vĩnh viễn file này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await _withLoading(() => widget.trashService.deleteFileForever(id));
    if (!mounted) return;
    if (ok) {
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa vĩnh viễn')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trashFiles = widget.trashService.trashFilesNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thùng rác"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Dọn thùng rác (30 ngày)',
            onPressed: () async {
              await _withLoading(() => widget.trashService.autoCleanTrash());
              if (!mounted) return;
              _changed = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã dọn thùng rác')),
              );
            },
          )
        ],
      ),
      body: trashFiles.isEmpty
          ? const Center(child: Text("Thùng rác trống"))
          : ListView.builder(
        itemCount: trashFiles.length,
        itemBuilder: (context, index) {
          final file = Map<String, dynamic>.from(trashFiles[index]);
          final type = file["type"] ?? "file";
          final fileName = file["fileName"] ?? "(no name)";
          final deletedAtStr = file["deletedAt"] as String? ?? '';
          DateTime? deletedAt;
          try {
            deletedAt = DateTime.parse(deletedAtStr);
          } catch (_) {
            deletedAt = null;
          }
          final daysLeft = deletedAt == null
              ? '-'
              : (30 - DateTime.now().difference(deletedAt).inDays)
              .clamp(0, 30)
              .toString();
          final id = file['id'] as String? ?? '';

          return ListTile(
            leading: Icon(
              type == "folder" ? Icons.folder : Icons.insert_drive_file,
              color: type == "folder" ? Colors.orange : Colors.grey,
            ),
            title: Text(fileName),
            subtitle: Text(
              'Xóa lúc: ${deletedAt?.toLocal().toString() ?? "?"}\n'
                  'Tự động xóa sau: $daysLeft ngày',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.green),
                  onPressed: () => _restoreFile(id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () => _deleteFile(id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
