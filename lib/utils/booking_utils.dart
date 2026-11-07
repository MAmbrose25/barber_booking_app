/// 100000 -> 100.000
String formatPrice(int price) {
  final s = price.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// 2026-10-30 -> 30/10/2026
String formatDbDate(String dbDate) {
  final p = dbDate.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// '09:30:00' hoặc '09:30' -> '09:30'
String shortTime(String dbTime) =>
    dbTime.length >= 5 ? dbTime.substring(0, 5) : dbTime;

/// '09:30' -> 570 (số phút tính từ 0h)
int minutesOfDay(String time) {
  final p = time.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Ghép ngày và giờ lấy từ database thành DateTime
DateTime bookingStart(String dbDate, String dbTime) {
  final d = dbDate.split('-');
  final t = dbTime.split(':');
  return DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
      int.parse(t[0]), int.parse(t[1]));
}