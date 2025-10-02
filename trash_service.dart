// lib/trash_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class TrashService {
  final SupabaseClient _client;
  final String bucket = "files";
  final String trashFolder = "Trash";
  final String indexFile = "Trash/index.json";

  final ValueNotifier<List<Map<String, dynamic>>> trashFilesNotifier =
  ValueNotifier<List<Map<String, dynamic>>>([]);

  TrashService({SupabaseClient? supabase})
      : _client = supabase ?? Supabase.instance.client {
    _refreshTrash(); // load lần đầu
  }

  Future<Map<String, dynamic>> _loadIndex() async {
    try {
      final bytes = await _client.storage.from(bucket).download(indexFile);
      final content = utf8.decode(bytes);
      final Map<String, dynamic> js =
      jsonDecode(content) as Map<String, dynamic>;
      if (!js.containsKey('files')) js['files'] = [];
      return js;
    } catch (e) {
      return {"files": []};
    }
  }

  Future<void> _saveIndex(Map<String, dynamic> index) async {
    final encoded = utf8.encode(jsonEncode(index));
    try {
      await _client.storage.from(bucket).uploadBinary(
        indexFile,
        Uint8List.fromList(encoded),
        fileOptions: const FileOptions(upsert: true),
      );
    } catch (e) {
      final tmp = File(
          '${Directory.systemTemp.path}/index_${DateTime.now().microsecondsSinceEpoch}.json');
      await tmp.writeAsBytes(encoded);
      try {
        await _client.storage.from(bucket).upload(
          indexFile,
          tmp,
          fileOptions: const FileOptions(upsert: true),
        );
      } finally {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _refreshTrash() async {
    await getTrashFiles();
  }

  /// 🚀 Di chuyển file hoặc folder vào Trash
  Future<String?> moveToTrash(String filePath) async {
    final fileName = p.basename(filePath);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final bucketRef = _client.storage.from(bucket);

    try {
      // check nếu đây là file hay folder
      try {
        final Uint8List bytes = await bucketRef.download(filePath);
        // === FILE ===
        final trashPath = "$trashFolder/$fileName";
        await bucketRef.uploadBinary(
          trashPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: "application/octet-stream",
            metadata: {"orig": filePath}, // ✅ lưu đường dẫn gốc
          ),
        );
        await bucketRef.remove([filePath]);

        final entry = {
          "id": id,
          "type": "file",
          "fileName": fileName,
          "originalPath": filePath, // ✅ luôn có
          "trashPath": trashPath,
          "deletedAt": DateTime.now().toIso8601String(),
        };

        // update UI ngay
        trashFilesNotifier.value = [...trashFilesNotifier.value, entry];

        final index = await _loadIndex();
        (index["files"] as List).add(entry);
        await _saveIndex(index);
        return id;
      } catch (_) {
        // === FOLDER ===
        Future<void> moveFolderRecursively(String folderPath,
            String trashBasePath, List<Map<String, dynamic>> children) async {
          final items = await bucketRef.list(path: folderPath);

          for (var f in items) {
            final childPath = "$folderPath/${f.name}";
            final trashChildPath = "$trashBasePath/${f.name}";

            if ((f.metadata ?? {}).isEmpty) {
              // Folder con
              final subChildren = <Map<String, dynamic>>[];
              await moveFolderRecursively(
                  childPath, trashChildPath, subChildren);
              children.add({
                "type": "folder",
                "fileName": f.name,
                "originalPath": childPath,
                "trashPath": trashChildPath,
                "children": subChildren,
              });
            } else {
              // File
              final Uint8List bytes = await bucketRef.download(childPath);
              await bucketRef.uploadBinary(
                trashChildPath,
                bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: "application/octet-stream",
                  metadata: {"orig": childPath}, // ✅ lưu đường dẫn gốc
                ),
              );
              await bucketRef.remove([childPath]);

              children.add({
                "type": "file",
                "fileName": f.name,
                "originalPath": childPath,
                "trashPath": trashChildPath,
              });
            }
          }
        }

        final children = <Map<String, dynamic>>[];
        await moveFolderRecursively(filePath, "$trashFolder/$fileName", children);

        final entry = {
          "id": id,
          "type": "folder",
          "fileName": fileName,
          "originalPath": filePath,
          "trashPath": "$trashFolder/$fileName",
          "deletedAt": DateTime.now().toIso8601String(),
          "children": children,
        };

        // update UI ngay
        trashFilesNotifier.value = [...trashFilesNotifier.value, entry];

        final index = await _loadIndex();
        (index["files"] as List).add(entry);
        await _saveIndex(index);
        return id;
      }
    } catch (e, st) {
      debugPrint("moveToTrash ERROR: $e\n$st");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTrashFiles() async {
    final index = await _loadIndex();
    final List files = index["files"] ?? [];
    trashFilesNotifier.value =
        files.map((f) => Map<String, dynamic>.from(f as Map)).toList();
    return trashFilesNotifier.value;
  }

  /// ✅ Khôi phục file/folder
  Future<String?> restoreFile(String id) async {
    final index = await _loadIndex();
    final List files = index['files'] as List;
    final idx = files.indexWhere((f) => (f as Map)['id'] == id);
    if (idx == -1) return null;

    final entry = Map<String, dynamic>.from(files[idx] as Map);

    Future<void> restoreRecursively(Map<String, dynamic> e) async {
      if (e["type"] == "file") {
        final orig = e["originalPath"] as String?;
        final trash = e["trashPath"] as String?;
        if (orig == null || orig.isEmpty || trash == null) {
          throw Exception("Invalid metadata: trash=$trash, orig=$orig");
        }

        final bytes = await _client.storage.from(bucket).download(trash);
        await _client.storage.from(bucket).uploadBinary(
          orig,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
        await _client.storage.from(bucket).remove([trash]);
      } else if (e["type"] == "folder") {
        final children = (e["children"] as List?) ?? [];
        for (var c in children) {
          await restoreRecursively(Map<String, dynamic>.from(c));
        }
      }
    }

    await restoreRecursively(entry);

    // ✅ Xoá ngay trên notifier (UI mất tức thì)
    final current = List<Map<String, dynamic>>.from(trashFilesNotifier.value);
    current.removeWhere((f) => f["id"] == id);
    trashFilesNotifier.value = current;

    // Sau đó cập nhật index.json
    files.removeAt(idx);
    index['files'] = files;
    await _saveIndex(index);

    return entry["originalPath"];
  }

  /// Xoá vĩnh viễn
  Future<bool> deleteFileForever(String id) async {
    final index = await _loadIndex();
    final List files = index['files'] as List;
    final idx = files.indexWhere((f) => (f as Map)['id'] == id);
    if (idx == -1) return false;

    final entry = Map<String, dynamic>.from(files[idx] as Map);

    Future<void> deleteRecursively(Map<String, dynamic> e) async {
      if (e["type"] == "file") {
        try {
          await _client.storage.from(bucket).remove([e["trashPath"]]);
        } catch (_) {}
      } else if (e["type"] == "folder") {
        final children = (e["children"] as List?) ?? [];
        for (var c in children) {
          await deleteRecursively(Map<String, dynamic>.from(c));
        }
      }
    }

    await deleteRecursively(entry);

    // ✅ Cập nhật ngay notifier (UI biến mất lập tức)
    final current = List<Map<String, dynamic>>.from(trashFilesNotifier.value);
    current.removeWhere((f) => f["id"] == id);
    trashFilesNotifier.value = current;

    // Cập nhật index.json trên Supabase
    files.removeAt(idx);
    index['files'] = files;
    await _saveIndex(index);

    return true;
  }

  /// Dọn thùng rác sau 30 ngày
  Future<void> autoCleanTrash() async {
    final index = await _loadIndex();
    final now = DateTime.now();
    final List files = index['files'] as List;
    final toKeep = <dynamic>[];

    for (var f in files) {
      final Map ff = Map<String, dynamic>.from(f as Map);
      try {
        final deletedAt = DateTime.parse(ff['deletedAt']);
        if (now.difference(deletedAt).inDays >= 30) {
          await deleteFileForever(ff['id']);
        } else {
          toKeep.add(ff);
        }
      } catch (_) {
        toKeep.add(ff);
      }
    }

    index['files'] = toKeep;
    await _saveIndex(index);
    await _refreshTrash();
  }
}
