// lib/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'storage_service.dart';
import 'select_folder_screen.dart';
import 'preview_screen.dart';
import 'trash_service.dart';
import 'trash_screen.dart';
import 'widgets/sidebar_menu.dart';
import 'widgets/file_grid.dart';
import 'widgets/file_details_screen.dart';
import 'widgets/file_search_delegate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService storage = StorageService();
  late final TrashService trashService;

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItemsRecursive = [];
  List<Map<String, dynamic>> filteredItems = [];
  String currentPath = '';
  String searchQuery = '';
  String filterType = 'dashboard';

  @override
  void initState() {
    super.initState();
    trashService = TrashService(supabase: storage.supabase);
    _load();
  }

  Future<T> _withLoading<T>(Future<T> Function() action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await action();
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _load({String? path}) async {
    final pth = path ?? currentPath;
    final list = await storage.listFiles(path: pth);
    final filteredList = list.where((item) => item['name'] != 'Trash').toList();

    for (var f in filteredList) {
      if (f['isFolder'] == true) {
        final children = await storage.listFiles(path: f['path'] as String);
        f['childCount'] = children.length;
      }
    }

    final allList = await _listAllRecursively('');

    setState(() {
      items = filteredList;
      allItemsRecursive = allList;
      filteredItems = _applySearch(searchQuery, filterType);
      if (path != null) currentPath = pth;
    });
  }

  Future<List<Map<String, dynamic>>> _listAllRecursively(String path) async {
    final result = <Map<String, dynamic>>[];
    final list = await storage.listFiles(path: path);
    for (var item in list) {
      if (item['name'] == 'Trash') continue;
      result.add(item);
      if (item['isFolder'] == true) {
        final children = await _listAllRecursively(item['path'] as String);
        result.addAll(children);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _applySearch(String query, String filter) {
    Iterable<Map<String, dynamic>> base;
    if (filter == 'dashboard') {
      base = items;
    } else if (filter == 'all') {
      base = allItemsRecursive.where((it) => it['isFolder'] != true);
    } else if (filter == 'videos') {
      base = allItemsRecursive.where((it) =>
      !(it['isFolder'] == true) &&
          (it['name'] as String).toLowerCase().endsWith('.mp4'));
    } else if (filter == 'documents') {
      base = allItemsRecursive.where((it) =>
      !(it['isFolder'] == true) &&
          ((it['name'] as String).toLowerCase().endsWith('.doc') ||
              (it['name'] as String).toLowerCase().endsWith('.docx') ||
              (it['name'] as String).toLowerCase().endsWith('.txt') ||
              (it['name'] as String).toLowerCase().endsWith('.pdf')));
    } else if (filter == 'images') {
      base = allItemsRecursive.where((it) =>
      !(it['isFolder'] == true) &&
          ((it['name'] as String).toLowerCase().endsWith('.jpg') ||
              (it['name'] as String).toLowerCase().endsWith('.jpeg') ||
              (it['name'] as String).toLowerCase().endsWith('.png')));
    } else {
      base = allItemsRecursive;
    }

    if (query.isEmpty) return base.toList();
    final lower = query.toLowerCase();
    return base.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      return name.contains(lower);
    }).toList();
  }

  void _updateSearch(String query) {
    setState(() {
      searchQuery = query;
      filteredItems = _applySearch(searchQuery, filterType);
    });
  }

  void _updateFilter(String type) {
    setState(() {
      filterType = type;
      filteredItems = _applySearch(searchQuery, filterType);
    });
  }

  Future<String> _getUniqueFileName(String dest) async {
    String baseName = p.basenameWithoutExtension(dest);
    String ext = p.extension(dest);
    String dir = p.dirname(dest);
    if (dir == '.') dir = '';

    int counter = 1;
    String candidate = dest;
    while (await storage.exists(candidate)) {
      final newName = "$baseName($counter)$ext";
      candidate = dir.isEmpty ? newName : "$dir/$newName";
      counter++;
    }
    return candidate;
  }

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles();
    if (res == null) return;
    final filePath = res.files.single.path;
    final fileName = res.files.single.name;
    if (filePath == null) return;
    final file = File(filePath);

    String dest = currentPath.isEmpty ? fileName : '$currentPath/$fileName';
    dest = await _getUniqueFileName(dest);

    final ok = await _withLoading(() => storage.uploadFile(file, dest));
    _show(ok ? 'Upload thành công' : 'Upload thất bại');
    if (ok) _load();
  }

  Future<void> _createFolderDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tạo thư mục'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Tên thư mục')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Tạo')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      String dest = currentPath.isEmpty ? name : "$currentPath/$name";
      dest = await _getUniqueFileName(dest);

      final ok = await _withLoading(() => storage.createFolder("", dest));
      _show(ok ? 'Tạo folder thành công' : 'Tạo folder thất bại');
      if (ok) _load();
    }
  }

  Future<void> _rename(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: item['name'] as String? ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Đổi tên ${item['isFolder'] ? 'thư mục' : 'file'}'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, null),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;

    final oldPath = item['path'] as String;
    final idx = oldPath.lastIndexOf('/');
    final parent = idx >= 0 ? oldPath.substring(0, idx) : '';
    String newPath = parent.isEmpty ? newName : '$parent/$newName';
    newPath = await _getUniqueFileName(newPath);

    final ok = await _withLoading(() => storage.renameItem(oldPath, newPath));
    _show(ok ? 'Đổi tên thành công' : 'Đổi tên thất bại');
    if (ok) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Chuyển vào thùng rác'),
        content: Text("Bạn có chắc muốn chuyển '${item['name']}' vào thùng rác?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    if (confirm != true) return;

    final path = item['path'] as String;
    debugPrint("DEBUG DELETE path=$path");
    try {
      // moveToTrash trả về id (String?) hoặc null khi thất bại
      final id = await _withLoading(() => trashService.moveToTrash(path));
      if (id != null) {
        _show('Đã chuyển vào thùng rác');
        await _load(); // chỉ load lại khi thao tác thành công
      } else {
        _show('Chuyển vào thùng rác thất bại');
      }
    } catch (e) {
      _show('Chuyển vào thùng rác thất bại: $e');
    }
  }



  Future<void> _move(Map<String, dynamic> item) async {
    final dest = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFolderScreen(currentPath: currentPath),
      ),
    );
    if (dest == null) return;

    final fileName = item['name'] as String;
    final oldPath = item['path'] as String;
    String newPath = dest.isEmpty ? fileName : '$dest/$fileName';
    newPath = await _getUniqueFileName(newPath);

    if (newPath == oldPath) {
      _show('File đã ở trong thư mục này');
      return;
    }

    final ok = await _withLoading(() => storage.renameItem(oldPath, newPath));
    _show(ok ? 'Di chuyển thành công' : 'Di chuyển thất bại');
    if (ok) await _load();
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final file = await _withLoading(() => storage.downloadFile(item['path'] as String));
    if (file != null) {
      _show("Đã tải về: ${file.path}");
    } else {
      _show("Tải xuống thất bại");
    }
  }

  void _openFolder(Map<String, dynamic> item) {
    final newPath = item['path'] as String;
    setState(() => currentPath = newPath);
    _load(path: newPath);
  }

  void _goBack() {
    if (currentPath.isEmpty) return;
    final idx = currentPath.lastIndexOf('/');
    final newPath = idx >= 0 ? currentPath.substring(0, idx) : '';
    setState(() {
      currentPath = newPath;
    });
    _load(path: newPath);
  }

  void _openTrashScreen() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrashScreen(trashService: trashService),
      ),
    );

    if (changed == true) {
      _load();
    }
  }

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _handleAction(Map<String, dynamic> item, String action) {
    if (action == 'rename') _rename(item);
    if (action == 'delete') _delete(item);
    if (action == 'move') _move(item);
    if (action == 'download') _download(item);
    if (action == 'preview') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            fileUrl: item['url'],
            fileName: item['name'],
          ),
        ),
      );
    }
    if (action == 'details') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FileDetailsScreen(
            file: item,
            onAction: _handleAction,
          ),
        ),
      );
    }
  }

  Widget _buildBreadcrumb() {
    final parts = currentPath.isEmpty ? [] : currentPath.split('/');
    final widgets = <Widget>[];

    widgets.add(
      InkWell(
        onTap: () {
          setState(() => currentPath = '');
          _load(path: '');
        },
        child: const Text("Root",
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
      ),
    );

    String cumulativePath = '';
    for (int i = 0; i < parts.length; i++) {
      cumulativePath += (cumulativePath.isEmpty ? '' : '/') + parts[i];
      widgets.add(const Text(" > "));
      widgets.add(
        InkWell(
          onTap: () {
            setState(() => currentPath = cumulativePath);
            _load(path: cumulativePath);
          },
          child: Text(parts[i], style: const TextStyle(color: Colors.blue)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderCount =
        filteredItems.where((e) => e['isFolder'] == true).length;
    final fileCount =
        filteredItems.where((e) => e['isFolder'] != true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AppCloud"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _pickAndUpload,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createFolderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      drawer: SidebarMenu(
        onSelect: (type, {query}) async {
          if (type == "search") {
            Navigator.pop(context);
            final Map<String, dynamic>? result =
            await showSearch<Map<String, dynamic>?>(
              context: context,
              delegate: FileSearchDelegate(allItemsRecursive),
            );

            if (result != null) {
              if (result['isFolder'] == true) {
                _openFolder(result);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FileDetailsScreen(
                      file: result,
                      onAction: _handleAction,
                    ),
                  ),
                );
              }
            }
            return;
          } else if (type == "trash") {
            _openTrashScreen();
          } else if (type == "createFolder") {
            _createFolderDialog();
          } else if (type == "uploadFile") {
            _pickAndUpload();
          } else if (type == "refresh") {
            _load();
          } else {
            _updateFilter(type);
          }
          Navigator.pop(context);
        },
        onTrash: _openTrashScreen,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentPath.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: currentPath.isEmpty ? null : _goBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildBreadcrumb()),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Documents ($folderCount folders, $fileCount files)",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: filteredItems.isEmpty
                ? const Center(child: Text('Không có file hoặc thư mục'))
                : FileGrid(
              items: filteredItems,
              onTap: (item) {
                if (item['isFolder'] == true) {
                  _openFolder(item);
                } else {
                  _handleAction(item, 'details');
                }
              },
              onAction: _handleAction,
            ),
          ),
        ],
      ),
    );
  }
}
