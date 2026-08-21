import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/database/json_record_normalizers.dart';
import 'package:vit_nextclass/core/database/storage_schema.dart';
import 'package:vit_nextclass/core/services/app_log.dart';

/// Runs incremental storage migrations on app startup before [LocalStorage] reads files.
class StorageMigrationRunner {
  StorageMigrationRunner._();

  static Future<void> run(Directory dataDir) async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(StorageSchema.prefsKey) ?? 0;

    if (storedVersion >= StorageSchema.currentVersion) {
      return;
    }

    AppLog.instance.info(
      'migration',
      'storage migration begin',
      data: {
        'fromVersion': storedVersion,
        'toVersion': StorageSchema.currentVersion,
      },
    );

    var version = storedVersion;
    while (version < StorageSchema.currentVersion) {
      final targetVersion = version + 1;
      try {
        await _runStep(dataDir, targetVersion);
        version = targetVersion;
        await prefs.setInt(StorageSchema.prefsKey, version);
        AppLog.instance.info(
          'migration',
          'storage migration step ok',
          data: {'version': version},
        );
      } catch (e, st) {
        AppLog.instance.error(
          'migration',
          'storage migration step failed',
          data: {'targetVersion': targetVersion},
          error: e,
          stackTrace: st,
        );
        // Do not advance version — retry on next launch.
        break;
      }
    }

    AppLog.instance.info(
      'migration',
      'storage migration end',
      data: {'version': version},
    );
  }

  static Future<void> _runStep(Directory dataDir, int targetVersion) async {
    switch (targetVersion) {
      case 1:
        await _migrateToV1(dataDir);
        return;
      default:
        throw UnsupportedError('No migration defined for version $targetVersion');
    }
  }

  /// v0 → v1: normalize legacy JSON field names and defaults in all data files.
  static Future<void> _migrateToV1(Directory dataDir) async {
    await _normalizeListFile(
      dataDir,
      StorageSchema.semestersFile,
      normalizeSemesterRecord,
    );
    await _normalizeListFile(
      dataDir,
      StorageSchema.coursesFile,
      normalizeCourseRecord,
    );
    await _normalizeListFile(
      dataDir,
      StorageSchema.overridesFile,
      normalizeOverrideRecord,
    );
    await _normalizeListFile(
      dataDir,
      StorageSchema.holidaysFile,
      normalizeHolidayRecord,
    );
  }

  static Future<void> _normalizeListFile(
    Directory dataDir,
    String filename,
    Map<String, dynamic>? Function(Map<String, dynamic>) normalize,
  ) async {
    final file = File('${dataDir.path}/$filename');
    if (!await file.exists()) return;

    final rawList = await _readJsonList(file);
    if (rawList == null) {
      final backup = File('${file.path}.bak');
      if (await backup.exists()) {
        final fromBackup = await _readJsonList(backup);
        if (fromBackup != null) {
          AppLog.instance.warn(
            'migration',
            'restored list from backup during migration',
            data: {'file': filename},
          );
          await _writeJsonList(file, fromBackup);
          return;
        }
      }
      AppLog.instance.warn(
        'migration',
        'skipped unreadable file',
        data: {'file': filename},
      );
      return;
    }

    final normalized = <Map<String, dynamic>>[];
    for (final entry in rawList) {
      final map = normalize(entry);
      if (map != null) normalized.add(map);
    }

    final encoded = jsonEncode(normalized);
    if (await file.exists() && await file.readAsString() == encoded) {
      return;
    }

    await _backupFile(file);
    await file.writeAsString(encoded);
  }

  static Future<List<Map<String, dynamic>>?> _readJsonList(File file) async {
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! List) return null;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeJsonList(File file, List<Map<String, dynamic>> list) async {
    await _backupFile(file);
    await file.writeAsString(jsonEncode(list));
  }

  static Future<void> _backupFile(File file) async {
    if (!await file.exists()) return;
    try {
      await file.copy('${file.path}.bak');
    } catch (_) {
      // Best-effort — migration still attempts the write.
    }
  }
}
