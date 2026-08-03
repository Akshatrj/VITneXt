import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/utils/prefs_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('readPrefBool handles bool and string storage', () async {
    SharedPreferences.setMockInitialValues({
      'bool_true': true,
      'bool_false': false,
      'string_true': 'true',
      'string_false': 'false',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(readPrefBool(prefs, 'bool_true'), isTrue);
    expect(readPrefBool(prefs, 'bool_false'), isFalse);
    expect(readPrefBool(prefs, 'string_true'), isTrue);
    expect(readPrefBool(prefs, 'string_false'), isFalse);
    expect(readPrefBool(prefs, 'missing'), isFalse);
    expect(readPrefBool(prefs, 'missing', defaultValue: true), isTrue);
  });
}
