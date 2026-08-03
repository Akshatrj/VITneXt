import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/utils/location_formatter.dart';

void main() {
  setUp(LocationFormatter.clearCacheForTesting);

  group('LocationFormatter.formatFromParts', () {
    test('Academic Block 1 first floor room 05', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.ab, floor: '1', room: '05'),
        'AB-1 105',
      );
    });

    test('Academic Block 2 second floor room 18', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.ab02, floor: '2', room: '18'),
        'AB-2 218',
      );
    });

    test('Architecture Block ground floor room 12', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.ar, floor: 'G', room: '12'),
        'AR 012',
      );
    });

    test('Lab Complex third floor room 27', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.lc, floor: '3', room: '27'),
        'LC 327',
      );
    });

    test('Online class', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.cr, floor: '1', room: 'Online'),
        'CR',
      );
    });

    test('Central block uses building code prefix', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.cb, floor: '2', room: '201'),
        'CB 2201',
      );
    });

    test('Other building returns room text', () {
      expect(
        LocationFormatter.formatFromParts(building: Buildings.other, floor: '1', room: 'Auditorium'),
        'Auditorium',
      );
    });
  });

  group('LocationFormatter.formatFromFullText', () {
    test('parses comma-separated VIT format', () {
      expect(
        LocationFormatter.formatFromFullText(
          'Academic Block -1, 1st Floor, Room No. 05',
        ),
        'AB-1 105',
      );
    });

    test('parses spaced format without commas', () {
      expect(
        LocationFormatter.formatFromFullText(
          'Academic Block -2 2nd Floor Room No. 18',
        ),
        'AB-2 218',
      );
    });

    test('parses architecture block', () {
      expect(
        LocationFormatter.formatFromFullText(
          'Architecture Block Ground Floor Room No. 12',
        ),
        'AR 012',
      );
    });

    test('parses lab complex case-insensitive', () {
      expect(
        LocationFormatter.formatFromFullText('LAB COMPLEX 3rd Floor Room 07'),
        'LC 307',
      );
    });

    test('parses online class', () {
      expect(LocationFormatter.formatFromFullText('Online Class'), 'CR');
    });

    test('returns original text when parsing fails', () {
      expect(
        LocationFormatter.formatFromFullText('Custom Venue Hall B'),
        'Custom Venue Hall B',
      );
    });

    test('tolerates academic block hyphen variants', () {
      expect(
        LocationFormatter.formatFromFullText('Academic Block-1 1st Floor Room 05'),
        'AB-1 105',
      );
      expect(
        LocationFormatter.formatFromFullText('Academic Block - 1 1st Floor Room 05'),
        'AB-1 105',
      );
    });
  });

  group('LocationFormatter cache', () {
    test('returns cached string for identical inputs', () {
      final a = LocationFormatter.formatFromParts(building: Buildings.ab, floor: '1', room: '05');
      final b = LocationFormatter.formatFromParts(building: Buildings.ab, floor: '1', room: '05');
      expect(identical(a, b), isTrue);
      expect(a, 'AB-1 105');
    });
  });
}
