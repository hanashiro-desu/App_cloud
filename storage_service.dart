// lib/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';


class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final String bucket = 'files';

  SupabaseClient get supabase => _client;

  String _nameFrom(dynamic f) {
    try {
      return (f as dynamic).name as String;
    } catch (_) {
      if (f is Map && f.containsKey('name')) return f['name'] as String;
      return f.toString();
    }
  }

  bool _hasMetadata(dynamic f) {
    try {
      final meta = (f as dynamic).metadata;
      return meta != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exists(String path) async {
    try {
      final idx = path.lastIndexOf('/');
      final parent = idx >= 0 ? path.substring(0, idx) : '';
      final name = idx >= 0 ? path.substring(idx + 1) : path;

      final List listed = await _client.storage.from(bucket).list(path: parent);
      for (var f in listed) {
        final rawName = _nameFrom(f).trim();
        if (rawName == name || rawName == '$name/') return true;
      }
      return false;
    } catch (e) {
      print('exists error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listFiles({String path = ''}) async {
    try {
      final List response = await _client.storage.from(bucket).list(path: path);

      final Map<String, Map<String, dynamic>> items = {};

      for (var f in response) {
        final rawName = _nameFrom(f).trim();
        if (rawName.isEmpty) continue;
        if (rawName == '.keep') continue; // ẩn marker

        bool isFolder = false;
        DateTime? createdAt;
        int? size;

        try {
          final meta = (f as dynamic).metadata;
          if (meta == null) {
            isFolder = true;
          } else {
            createdAt = meta['lastModified'] != null
                ? DateTime.parse(meta['lastModified'])
                : null;
            size = meta['size'] is int ? meta['size'] as int : null;
          }
        } catch (_) {
          if (rawName.endsWith('/')) isFolder = true;
        }

        if (path.isEmpty) {
          if (!isFolder && rawName.contains('/')) {
            final folder = rawName.split('/')[0];
            if (!items.containsKey(folder)) {
              items[folder] = {
                'name': folder,
                'path': folder,
                'isFolder': true,
                'createdAt': null,
                'size': null,
              };
            }
          } else if (isFolder || rawName.endsWith('/')) {
            final folderName = rawName.replaceAll('/', '');
            if (!items.containsKey(folderName)) {
              items[folderName] = {
                'name': folderName,
                'path': folderName,
                'isFolder': true,
                'createdAt': null,
                'size': null,
              };
            }
          } else {
            items[rawName] = {
              'name': rawName,
              'path': rawName,
              'isFolder': false,
              'createdAt': createdAt,
              'size': size,
            };
          }
        } else {
          if (!isFolder && rawName.contains('/')) {
            final subFolder = rawName.split('/')[0];
            final folderPath = '$path/$subFolder';
            if (!items.containsKey(folderPath)) {
              items[folderPath] = {
                'name': subFolder,
                'path': folderPath,
                'isFolder': true,
                'createdAt': null,
                'size': null,
              };
            }
          } else if (isFolder || rawName.endsWith('/')) {
            final folderName = rawName.replaceAll('/', '');
            final folderPath = '$path/$folderName';
            if (!items.containsKey(folderPath)) {
              items[folderPath] = {
                'name': folderName,
                'path': folderPath,
                'isFolder': true,
                'createdAt': null,
                'size': null,
              };
            }
          } else {
            final filePath = '$path/$rawName';
            items[filePath] = {
              'name': rawName,
              'path': filePath,
              'isFolder': false,
              'createdAt': createdAt,
              'size': size,
            };
          }
        }
      }

      return items.values.map((e) {
        if (e['isFolder'] == false) {
          e['url'] = getPublicUrl(e['path']); // thêm url cho file
        }
        return e;
      }).toList();
    } catch (e, st) {
      print('listFiles error: $e\n$st');
      return [];
    }
  }

  Future<bool> uploadFile(File file, String destPath) async {
    try {
      // Thử upload file lên Supabase Storage
      try {
        await _client.storage.from(bucket).upload(destPath, file);
      } catch (_) {
        // Nếu file đã tồn tại, xóa rồi upload lại
        try {
          await _client.storage.from(bucket).remove([destPath]);
        } catch (_) {}
        await _client.storage.from(bucket).upload(destPath, file);
      }

      // === Ghi metadata vào bảng "files" ===
      final fileName = p.basename(destPath);
      final fileSize = await file.length();

      await _client.from('files').insert({
        'name': fileName,
        'path': destPath,
        'size': fileSize,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ File uploaded and metadata saved: $fileName');
      return true;
    } catch (e) {
      print('uploadFile error: $e');
      return false;
    }
  }

  Future<bool> createFolder(String parentPath, String folderName) async {
    try {
      final folderPath =
      parentPath.isEmpty ? folderName : '$parentPath/$folderName';
      final markerPath = '$folderPath/.keep';

      // 1️⃣ Tạo file .keep trong Storage
      final tmp = File(
          '${Directory.systemTemp.path}/.keep_${DateTime.now().millisecondsSinceEpoch}');
      await tmp.writeAsBytes(Uint8List(0));
      final ok = await uploadFile(tmp, markerPath);
      try {
        await tmp.delete();
      } catch (_) {}

      if (!ok) return false;

      // 2️⃣ Ghi thông tin thư mục vào database
      final folderNameOnly = folderName.trim();

      try {
        await SupabaseManager.supabase.from('folders').insert({
          'name': folderNameOnly,
          'parent_id': null, // có thể thay bằng id thư mục cha nếu cần
          'is_deleted': false,
        });
        print('✅ Folder "$folderNameOnly" created successfully in DB');
      } catch (error) {
        print('insert folder error: $error');
        return false;
      }

      return true;
    } catch (e) {
      print('createFolder error: $e');
      return false;
    }
  }

  Future<bool> _isFolder(String path) async {
    try {
      final listed = await _client.storage.from(bucket).list(path: path);
      return listed.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> renameItem(String oldPath, String newPath) async {
    try {
      final bucketRef = _client.storage.from(bucket);
      final isFolder = await _isFolder(oldPath);

      if (!isFolder) {
        // ---- Trường hợp file ----
        final Uint8List bytes = await bucketRef.download(oldPath);
        final tmp = File(
            '${Directory.systemTemp.path}/${p.basename(newPath)}_${DateTime.now().millisecondsSinceEpoch}');
        await tmp.writeAsBytes(bytes);

        final ok = await uploadFile(tmp, newPath);
        try {
          await tmp.delete();
        } catch (_) {}

        if (!ok) return false;

        await bucketRef.remove([oldPath]);
        return true;
      } else {
        // ---- Trường hợp folder ----
        // lấy toàn bộ file/folder con
        Future<List<String>> _listRecursively(String path) async {
          final result = <String>[];
          final children = await bucketRef.list(path: path);
          for (var f in children) {
            final childName = _nameFrom(f);
            if (childName.isEmpty) continue;
            final childPath = '$path/$childName';
            result.add(childPath);

            final childIsFolder = await _isFolder(childPath);
            if (childIsFolder) {
              final sub = await _listRecursively(childPath);
              result.addAll(sub);
            }
          }
          return result;
        }

        final allChildren = await _listRecursively(oldPath);

        // copy từng file sang newPath
        for (var child in allChildren) {
          if (child.endsWith('/.keep')) continue; // bỏ .keep cũ

          final relative = child.substring(oldPath.length + 1);
          final newChildPath = '$newPath/$relative';

          final childIsFolder = await _isFolder(child);
          if (childIsFolder) {
            // bỏ qua folder, chỉ cần copy file
            continue;
          } else {
            final Uint8List bytes = await bucketRef.download(child);
            final tmp = File(
                '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_${p.basename(child)}');
            await tmp.writeAsBytes(bytes);

            final ok = await uploadFile(tmp, newChildPath);
            try {
              await tmp.delete();
            } catch (_) {}

            if (!ok) return false;
            await bucketRef.remove([child]);
          }
        }

        // xử lý .keep mới cho folder
        final markerPath = '$newPath/.keep';
        final tmpMarker = File(
            '${Directory.systemTemp.path}/.keep_${DateTime.now().millisecondsSinceEpoch}');
        await tmpMarker.writeAsBytes(Uint8List(0));
        await uploadFile(tmpMarker, markerPath);
        try {
          await tmpMarker.delete();
        } catch (_) {}

        // xoá .keep cũ
        try {
          await bucketRef.remove(['$oldPath/.keep']);
        } catch (_) {}

        return true;
      }
    } catch (e, st) {
      print('renameItem error: $e\n$st');
      return false;
    }
  }


  Future<bool> deleteItem(String path) async {
    try {
      final bucketRef = _client.storage.from(bucket);
      final isFolder = await _isFolder(path);

      if (!isFolder) {
        await bucketRef.remove([path]);
        return true;
      } else {
        final children = await bucketRef.list(path: path);
        final List<String> toRemove = [];
        for (var f in children) {
          final childName = _nameFrom(f);
          if (childName.isEmpty || childName == '.keep') continue;
          final childPath = '$path/$childName';
          final childIsFolder = await _isFolder(childPath);
          if (childIsFolder) {
            final ok = await deleteItem(childPath);
            if (!ok) return false;
          } else {
            toRemove.add(childPath);
          }
        }
        if (toRemove.isNotEmpty) {
          await bucketRef.remove(toRemove);
        }
        try {
          await bucketRef.remove(['$path/.keep']);
        } catch (_) {}
        return true;
      }
    } catch (e, st) {
      print('deleteItem error: $e\n$st');
      return false;
    }
  }

  Future<bool> moveFileToParent(String filePath) async {
    try {
      final bucketRef = _client.storage.from(bucket);

      if (!filePath.contains('/')) {
        print('File is already in root, cannot move to parent.');
        return false;
      }

      final segments = filePath.split('/');
      final fileName = segments.removeLast();
      final parentPath = segments.join('/');

      final grandParentSegments = [...segments];
      if (grandParentSegments.isNotEmpty) {
        grandParentSegments.removeLast();
      }
      final grandParentPath = grandParentSegments.join('/');

      final newPath = grandParentPath.isEmpty ? fileName : '$grandParentPath/$fileName';

      final Uint8List bytes = await bucketRef.download(filePath);
      final tmp = File('${Directory.systemTemp.path}/$fileName');
      await tmp.writeAsBytes(bytes);

      final ok = await uploadFile(tmp, newPath);
      try {
        await tmp.delete();
      } catch (_) {}

      if (!ok) return false;

      await bucketRef.remove([filePath]);
      return true;
    } catch (e, st) {
      print('moveFileToParent error: $e\n$st');
      return false;
    }
  }

  Future<File?> downloadFile(String path) async {
    try {
      final bucketRef = _client.storage.from(bucket);
      final Uint8List bytes = await bucketRef.download(path);

      final fileName = p.basename(path);

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
        if (!await dir.exists()) {
          dir = Directory("/sdcard/Download");
        }
      } else {
        dir = Directory.systemTemp; // fallback iOS/web
      }

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(bytes);

      print("File đã tải về: ${file.path}");
      return file;
    } catch (e, st) {
      print('downloadFile error: $e\n$st');
      return null;
    }
  }

  String getPublicUrl(String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<Uint8List> downloadBytes(String path) async {
    final bucketRef = _client.storage.from(bucket);
    final Uint8List bytes = await bucketRef.download(path);
    return bytes;
  }

}
