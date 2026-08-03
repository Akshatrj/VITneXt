import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Persistent NDJSON app logger for reliability diagnostics.
///
/// Writes to app documents `vitnext_debug.log` (rotated when large).
class AppLog {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const _fileName = 'vitnext_debug.log';
  static const _maxBytes = 1.5 * 1024 * 1024; // ~1.5 MB
  static const _keepTailBytes = 512 * 1024;

  final _controller = StreamController<String>.broadcast();
  final List<String> _memory = [];
  static const _memoryCap = 400;

  File? _file;
  bool _ready = false;
  final Map<String, String> _keys = {};
  final _writeQueue = <String>[];
  bool _flushing = false;

  Stream<String> get stream => _controller.stream;
  Map<String, String> get customKeys => Map.unmodifiable(_keys);

  Future<void> init() async {
    if (_ready) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/$_fileName');
      if (!await _file!.exists()) {
        await _file!.create(recursive: true);
      }
      await _rotateIfNeeded();
      _ready = true;
      info('system', 'AppLog ready', data: {
        'path': _file!.path,
        'debug': kDebugMode,
      });
    } catch (e, st) {
      debugPrint('AppLog init failed: $e\n$st');
    }
  }

  void setKey(String key, String value) {
    _keys[key] = value;
  }

  void setKeys(Map<String, String> keys) {
    _keys.addAll(keys);
  }

  void info(String category, String message, {Map<String, Object?>? data}) =>
      _log('INFO', category, message, data: data);

  void warn(String category, String message, {Map<String, Object?>? data}) =>
      _log('WARN', category, message, data: data);

  void error(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    _log(
      'ERROR',
      category,
      message,
      data: {
        ...?data,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
      },
    );
  }

  void _log(
    String level,
    String category,
    String message, {
    Map<String, Object?>? data,
  }) {
    final entry = <String, Object?>{
      'ts': DateTime.now().toIso8601String(),
      'level': level,
      'cat': category,
      'msg': message,
      if (data != null && data.isNotEmpty) 'data': data,
      if (_keys.isNotEmpty) 'keys': _keys,
    };
    final line = jsonEncode(entry);
    _memory.add(line);
    if (_memory.length > _memoryCap) {
      _memory.removeRange(0, _memory.length - _memoryCap);
    }
    if (_controller.hasListener) {
      _controller.add(line);
    }
    debugPrint('[VITneXt/$level/$category] $message');
    _writeQueue.add(line);
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await init();
      final file = _file;
      if (file == null) return;
      while (_writeQueue.isNotEmpty) {
        final batch = List<String>.from(_writeQueue);
        _writeQueue.clear();
        await file.writeAsString(
          '${batch.join('\n')}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
      await _rotateIfNeeded();
    } catch (e) {
      debugPrint('AppLog flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  Future<void> _rotateIfNeeded() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    final len = await file.length();
    if (len <= _maxBytes) return;
    final bytes = await file.readAsBytes();
    final start = (bytes.length - _keepTailBytes).clamp(0, bytes.length);
    // Align to next newline to avoid partial JSON lines.
    var cut = start;
    while (cut < bytes.length && bytes[cut] != 0x0A) {
      cut++;
    }
    if (cut < bytes.length) cut++;
    await file.writeAsBytes(bytes.sublist(cut), flush: true);
    info('system', 'Log rotated', data: {'fromBytes': len, 'toBytes': bytes.length - cut});
  }

  Future<String> readAll() async {
    await init();
    final file = _file;
    if (file == null || !await file.exists()) {
      return _memory.join('\n');
    }
    try {
      final disk = await file.readAsString();
      if (disk.trim().isEmpty) return _memory.join('\n');
      return disk;
    } catch (_) {
      return _memory.join('\n');
    }
  }

  List<String> recentMemory({int limit = 200}) {
    if (_memory.length <= limit) return List.unmodifiable(_memory);
    return List.unmodifiable(_memory.sublist(_memory.length - limit));
  }

  Future<void> clear() async {
    await init();
    _memory.clear();
    final file = _file;
    if (file != null && await file.exists()) {
      await file.writeAsString('', flush: true);
    }
    info('system', 'Logs cleared');
  }

  Future<void> share() async {
    await _flush();
    final content = await readAll();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final out = File('${dir.path}/VITneXt_logs_$stamp.txt');
    final header = StringBuffer()
      ..writeln('VITneXt debug logs')
      ..writeln('generated=${DateTime.now().toIso8601String()}')
      ..writeln('keys=${jsonEncode(_keys)}')
      ..writeln('---');
    await out.writeAsString('$header\n$content');
    await Share.shareXFiles(
      [XFile(out.path)],
      subject: 'VITneXt debug logs',
      text: 'VITneXt diagnostic logs',
    );
    info('system', 'Logs shared');
  }
}
