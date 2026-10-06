class PricePoint {
  final DateTime date;
  final double price;

  PricePoint({required this.date, required this.price});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'price': price,
      };

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
        date: DateTime.parse(json['date'] as String),
        price: (json['price'] as num).toDouble(),
      );
}

class Part {
  final String id;
  String name;
  String category;
  String store;
  double currentPrice;
  double targetPrice;
  bool notifyOnDrop;
  List<PricePoint> history;

  Part({
    required this.id,
    required this.name,
    required this.category,
    required this.store,
    required this.currentPrice,
    required this.targetPrice,
    this.notifyOnDrop = true,
    List<PricePoint>? history,
  }) : history = history ?? [];

  /// Variação percentual entre o primeiro preço do histórico e o atual.
  double? get deltaPercent {
    if (history.isEmpty) return null;
    final first = history.first.price;
    if (first == 0) return null;
    return ((currentPrice - first) / first) * 100;
  }

  bool get reachedTarget => currentPrice <= targetPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'store': store,
        'currentPrice': currentPrice,
        'targetPrice': targetPrice,
        'notifyOnDrop': notifyOnDrop,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory Part.fromJson(Map<String, dynamic> json) => Part(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        store: json['store'] as String,
        currentPrice: (json['currentPrice'] as num).toDouble(),
        targetPrice: (json['targetPrice'] as num).toDouble(),
        notifyOnDrop: json['notifyOnDrop'] as bool? ?? true,
        history: (json['history'] as List<dynamic>? ?? [])
            .map((h) => PricePoint.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}
