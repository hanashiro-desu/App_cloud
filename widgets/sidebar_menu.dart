import 'package:flutter/material.dart';

class SidebarMenu extends StatelessWidget {
  final Function(String type, {String? query}) onSelect;
  final VoidCallback onTrash;

  const SidebarMenu({
    super.key,
    required this.onSelect,
    required this.onTrash,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer( // 👈 mobile sẽ mở ra từ trái
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person, size: 32),
                ),
                SizedBox(width: 12),
                Text(
                  "Tên người dùng",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            onTap: () => onSelect("dashboard"),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text("Search"),
            onTap: () => onSelect("search"),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text("All Files"),
            onTap: () => onSelect("all"),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text("Images"),
            onTap: () => onSelect("images"),
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text("Videos"),
            onTap: () => onSelect("videos"),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Documents"),
            onTap: () => onSelect("documents"),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Trash"),
            onTap: onTrash,
          ),
        ],
      ),
    );
  }
}
