import 'package:flutter/material.dart';

class Buildings {
  static const String ar = 'AR';
  static const String ab = 'AB';
  static const String ab02 = 'AB02';
  static const String lc = 'LC';
  static const String cb = 'CB';
  static const String cr = 'CR';
  static const String other = 'Other';

  static const List<String> all = [ar, ab, ab02, lc, cb, cr, other];

  static const List<String> floors = ['G', '1', '2', '3', '4'];

  static const Map<String, String> floorDisplayNames = {
    'G': 'Ground Floor',
    '1': 'First Floor',
    '2': 'Second Floor',
    '3': 'Third Floor',
    '4': 'Fourth Floor',
  };

  static String getFullName(String code) {
    switch (code) {
      case ar:
        return 'Architecture Block';
      case ab:
        return 'Academic Block 1';
      case ab02:
        return 'Academic Block 2';
      case lc:
        return 'Lab Complex';
      case cb:
        return 'Central Block';
      case cr:
        return 'Online Class';
      case other:
        return 'Other';
      default:
        return 'Unknown Building';
    }
  }

  static Color getColor(String code) {
    switch (code) {
      case ar:
        return Colors.orange;
      case ab:
        return Colors.blue;
      case ab02:
        return Colors.purple;
      case lc:
        return Colors.green;
      case cb:
        return Colors.red;
      case cr:
        return Colors.grey;
      case other:
      default:
        return Colors.teal;
    }
  }
}
