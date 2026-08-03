/// Short relative time, e.g. "now", "5m", "3h", "2d", or a date past a week.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 6) return '${d.day}/${d.month}';
  if (diff.inDays > 0) return '${diff.inDays}d';
  if (diff.inHours > 0) return '${diff.inHours}h';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m';
  return 'now';
}
