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

  /// Shared duration format used by app UI and Android widget.
  /// Examples: `5 min`, `1 hr`, `1 hr 5 min`, `2 hr 30 min`
  static String formatDuration(int totalMinutes) {
    final minutes = totalMinutes.abs();
    if (minutes <= 0) return '0 min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '$hours hr $mins min';
    if (hours > 0) return '$hours hr';
    return '$mins min';
  }

  static String formatCountdown(int minutesUntilStartOrNegativeUntilEnd) {
    if (minutesUntilStartOrNegativeUntilEnd > 0) {
      return 'Starts in ${formatDuration(minutesUntilStartOrNegativeUntilEnd)}';
    }
    return 'Ends in ${formatDuration(-minutesUntilStartOrNegativeUntilEnd)}';
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
