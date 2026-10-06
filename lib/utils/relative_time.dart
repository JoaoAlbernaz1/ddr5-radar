String formatRelativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  if (diff.inDays <= 0 && now.day == date.day) {
    return 'Hoje, $time';
  }
  if (diff.inDays == 1 || (diff.inHours < 48 && now.day != date.day && diff.inDays < 2)) {
    return 'Ontem, $time';
  }
  return 'há ${diff.inDays} dias';
}
