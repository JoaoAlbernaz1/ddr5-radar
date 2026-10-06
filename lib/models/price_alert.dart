class PriceAlert {
  final String id;
  final String partId;
  final String message;
  final DateTime date;

  PriceAlert({
    required this.id,
    required this.partId,
    required this.message,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'partId': partId,
        'message': message,
        'date': date.toIso8601String(),
      };

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        partId: json['partId'] as String,
        message: json['message'] as String,
        date: DateTime.parse(json['date'] as String),
      );
}
