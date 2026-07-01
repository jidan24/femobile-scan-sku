class ScanEntry {
  final String id;
  final String barcode;
  final String format;
  final DateTime timestamp;
  ScanStatus status;
  String? note;
  String? errorMessage;

  ScanEntry({
    required this.id,
    required this.barcode,
    required this.format,
    required this.timestamp,
    this.status = ScanStatus.pending,
    this.note,
    this.errorMessage,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedDate {
    final d = timestamp.day.toString().padLeft(2, '0');
    final mo = timestamp.month.toString().padLeft(2, '0');
    final y = timestamp.year;
    return '$d/$mo/$y';
  }
}

enum ScanStatus { pending, syncing, success, failed }
