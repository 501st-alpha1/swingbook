/// Formats an ISO-8601 date string (yyyy-MM-dd) to a readable short form
/// like "Jan 5, 2025". Returns the original string on any parse failure.
String formatShortDate(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return isoDate;
  return '${months[month - 1]} ${int.parse(parts[2])}, ${parts[0]}';
}
