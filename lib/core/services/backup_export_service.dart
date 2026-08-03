import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';

/// Exports timetable backup JSON to the public Downloads folder when possible.
class BackupExportService {
  BackupExportService(this._storage);

  final LocalStorage _storage;

  Future<String> exportToDownloads() async {
    final data = await _storage.exportAll();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'vit_nextclass_backup_$stamp.json';

    final downloadsDir = await _resolveDownloadsDirectory();
    final file = File('${downloadsDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(jsonString);
    return file.path;
  }

  /// Opens the system share sheet so the user can save/share the backup.
  Future<void> shareBackup() async {
    final data = await _storage.exportAll();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'vit_nextclass_backup_$stamp.json';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(jsonString);
    await Share.shareXFiles([XFile(file.path)], subject: 'VITneXt backup');
  }

  Future<Directory> _resolveDownloadsDirectory() async {
    // Prefer platform Downloads when available (Android app-specific Downloads).
    final platformDownloads = await getDownloadsDirectory();
    if (platformDownloads != null) {
      if (!await platformDownloads.exists()) {
        await platformDownloads.create(recursive: true);
      }
      return platformDownloads;
    }

    if (Platform.isAndroid) {
      // Ask for legacy storage access on older Android when writing public Download.
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (await publicDownload.exists()) {
          return publicDownload;
        }
      }
    }

    // Fallback: documents directory (always writable).
    final docs = await getApplicationDocumentsDirectory();
    final fallback = Directory('${docs.path}${Platform.pathSeparator}Downloads');
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback;
  }
}
