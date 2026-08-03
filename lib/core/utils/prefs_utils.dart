import 'package:shared_preferences/shared_preferences.dart';

/// Reads a bool stored by Flutter [setBool] or native Android (`"true"` / `"false"` strings).
bool readPrefBool(SharedPreferences prefs, String key, {bool defaultValue = false}) {
  try {
    final asBool = prefs.getBool(key);
    if (asBool != null) return asBool;
  } catch (_) {}
  try {
    final asString = prefs.getString(key);
    if (asString != null) return asString == 'true';
  } catch (_) {}
  return defaultValue;
}
