/// Uma montagem (conjunto de peças) salva pelo usuário — ex: "Setup 1440p
/// Ultra". Nome `BuildConfig` pra não colidir com a classe `Build` do SDK.
class BuildConfig {
  final String id;
  String name;
  double price;
  int pieces;
  bool hasCompatibilityWarning;

  BuildConfig({
    required this.id,
    required this.name,
    required this.price,
    required this.pieces,
    this.hasCompatibilityWarning = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'pieces': pieces,
        'hasCompatibilityWarning': hasCompatibilityWarning,
      };

  factory BuildConfig.fromJson(Map<String, dynamic> json) => BuildConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        pieces: json['pieces'] as int,
        hasCompatibilityWarning: json['hasCompatibilityWarning'] as bool? ?? false,
      );
}
