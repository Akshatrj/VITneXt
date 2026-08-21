/// Tracks on-disk JSON layout for [LocalStorage] data files.
///
/// Bump [currentVersion] when a new migration step is added in
/// [StorageMigrationRunner]. Never delete user data during migration — only
/// normalize or transform records in place (with `.bak` copies).
class StorageSchema {
  StorageSchema._();

  /// Latest schema version understood by this app build.
  static const int currentVersion = 1;

  /// SharedPreferences key (also mirrored in native widget prefs namespace).
  static const String prefsKey = 'storage_schema_version';

  static const String semestersFile = 'semesters.json';
  static const String coursesFile = 'courses.json';
  static const String overridesFile = 'overrides.json';
  static const String holidaysFile = 'holidays.json';

  static List<String> dataFiles = [
    semestersFile,
    coursesFile,
    overridesFile,
    holidaysFile,
  ];
}
