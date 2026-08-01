class TimeUtils {
  static String formatTime(int hour, int minute) {
    final ampm = hour >= 12 ? 'PM' : 'AM';
    var h = hour > 12 ? hour - 12 : hour;
    if (h == 0) h = 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  static String formatTimeRange(int startH, int startM, int endH, int endM) {
    return '${formatTime(startH, startM)} – ${formatTime(endH, endM)}';
  }

  static String formatCountdown(int minutes) {
    if (minutes > 0) {
      return 'Starts in $minutes minutes';
    } else {
      return 'Ends in ${-minutes} minutes';
    }
  }

  static int totalMinutes(int hour, int minute) {
    return hour * 60 + minute;
  }

  static bool isTimeBetween(DateTime now, int startH, int startM, int endH, int endM) {
    final nowMins = totalMinutes(now.hour, now.minute);
    final startMins = totalMinutes(startH, startM);
    final endMins = totalMinutes(endH, endM);
    return nowMins >= startMins && nowMins <= endMins;
  }
}
