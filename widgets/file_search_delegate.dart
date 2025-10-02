import 'package:flutter/material.dart';

/// SearchDelegate trả về Map<String,dynamic>? khi người dùng chọn 1 item
class FileSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final List<Map<String, dynamic>> items;

  FileSearchDelegate(this.items);

  List<Map<String, dynamic>> _filter(String q) {
    final lower = q.toLowerCase();
    return items
        .where((item) =>
        (item['name'] ?? '').toString().toLowerCase().contains(lower))
        .toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          if (query.isEmpty) {
            close(context, null);
          } else {
            query = '';
            showSuggestions(context);
          }
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _filter(query);
    if (results.isEmpty) {
      return const Center(child: Text("Không tìm thấy kết quả"));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final createdAt = item['createdAt'] is DateTime
            ? item['createdAt'] as DateTime
            : null;
        return ListTile(
          leading: Icon(
            item['isFolder'] == true ? Icons.folder : Icons.insert_drive_file,
            color: item['isFolder'] == true ? Colors.amber : Colors.blueGrey,
          ),
          title: Text(item['name'] ?? ''),
          subtitle: createdAt != null
              ? Text("${createdAt.day}/${createdAt.month}/${createdAt.year}")
              : null,
          onTap: () {
            // Trả về item đã chọn cho showSearch
            close(context, item);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? items.take(10).toList() // show top 10 khi query rỗng
        : _filter(query);

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: Icon(
            item['isFolder'] == true ? Icons.folder : Icons.insert_drive_file,
            color: item['isFolder'] == true ? Colors.amber : Colors.blueGrey,
          ),
          title: Text(item['name'] ?? ''),
          onTap: () {
            // Đặt query rồi show results (hành vi giống Drive)
            query = item['name'] ?? '';
            showResults(context);
          },
        );
      },
    );
  }
}
