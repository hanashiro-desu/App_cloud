// lib/select_folder_screen.dart
import 'package:flutter/material.dart';
import 'storage_service.dart';

class SelectFolderScreen extends StatefulWidget {
  final String currentPath;
  const SelectFolderScreen({super.key, required this.currentPath});

  @override
  State<SelectFolderScreen> createState() => _SelectFolderScreenState();
}

class _SelectFolderScreenState extends State<SelectFolderScreen> {
  final StorageService storage = StorageService();
  List<Map<String, dynamic>> items = [];
  String browsingPath = '';

  @override
  void initState() {
    super.initState();
    browsingPath = widget.currentPath;
    _load();
  }

  Future<void> _load() async {
    final list = await storage.listFiles(path: browsingPath);
    setState(() {
      // Chỉ lấy folder
      items = list.where((e) => e['isFolder'] == true).toList();
    });
  }

  void _openFolder(Map<String, dynamic> folder) {
    setState(() {
      browsingPath = folder['path'] as String;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chọn thư mục")),
      body: Column(
        children: [
          // Root option (dùng để di chuyển ra thư mục cha)
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blue),
            title: const Text("Root (Thư mục gốc)"),
            subtitle: const Text("Chọn để di chuyển ra thư mục cha"),
            trailing: IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => Navigator.pop(context, ''), // path rỗng = root
            ),
          ),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("Không có thư mục con"))
                : ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) {
                final folder = items[i];
                return ListTile(
                  leading:
                  const Icon(Icons.folder, color: Colors.amber),
                  title: Text(folder['name'] ?? ''),
                  onTap: () => _openFolder(folder),
                  trailing: IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () =>
                        Navigator.pop(context, folder['path']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
