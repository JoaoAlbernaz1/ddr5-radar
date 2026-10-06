import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/part.dart';
import '../models/price_alert.dart';
import '../models/build_config.dart';

/// Fonte única de dados do app: peças monitoradas + alertas.
/// Persiste localmente via SharedPreferences (JSON simples).
///
/// TODO (próximo passo real): trocar `simulatePriceCheck` por uma busca de
/// verdade (scraper/API por loja) rodando em background, mantendo a mesma
/// lógica de comparação preço atual x preço alvo pra gerar os PriceAlert.
class PartsRepository extends ChangeNotifier {
  static const _partsKey = 'partwatch_parts';
  static const _alertsKey = 'partwatch_alerts';
  static const _buildsKey = 'partwatch_builds';
  final _uuid = const Uuid();

  List<Part> _parts = [];
  List<PriceAlert> _alerts = [];
  List<BuildConfig> _builds = [];
  bool _loaded = false;

  List<Part> get parts => List.unmodifiable(_parts);
  List<BuildConfig> get builds => List.unmodifiable(_builds);

  List<PriceAlert> get alerts {
    final sorted = [..._alerts]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  bool get isLoaded => _loaded;

  Part? partById(String id) {
    for (final p in _parts) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final partsRaw = prefs.getString(_partsKey);

    if (partsRaw == null) {
      _parts = _seedParts();
      _alerts = _seedAlerts(_parts);
      _builds = _seedBuilds();
      await _persist();
    } else {
      final list = jsonDecode(partsRaw) as List<dynamic>;
      _parts = list.map((e) => Part.fromJson(e as Map<String, dynamic>)).toList();

      final alertsRaw = prefs.getString(_alertsKey);
      if (alertsRaw != null) {
        final alertList = jsonDecode(alertsRaw) as List<dynamic>;
        _alerts = alertList.map((e) => PriceAlert.fromJson(e as Map<String, dynamic>)).toList();
      }

      final buildsRaw = prefs.getString(_buildsKey);
      _builds = buildsRaw != null
          ? (jsonDecode(buildsRaw) as List<dynamic>).map((e) => BuildConfig.fromJson(e as Map<String, dynamic>)).toList()
          : _seedBuilds();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_partsKey, jsonEncode(_parts.map((p) => p.toJson()).toList()));
    await prefs.setString(_alertsKey, jsonEncode(_alerts.map((a) => a.toJson()).toList()));
    await prefs.setString(_buildsKey, jsonEncode(_builds.map((b) => b.toJson()).toList()));
  }

  Future<void> addBuild(String name) async {
    _builds.add(BuildConfig(id: _uuid.v4(), name: name, price: 0, pieces: 0));
    await _persist();
    notifyListeners();
  }

  Future<void> addPart({
    required String name,
    required String category,
    required String store,
    required double currentPrice,
    required double targetPrice,
  }) async {
    final part = Part(
      id: _uuid.v4(),
      name: name,
      category: category,
      store: store,
      currentPrice: currentPrice,
      targetPrice: targetPrice,
      history: [PricePoint(date: DateTime.now(), price: currentPrice)],
    );
    _parts.insert(0, part);
    await _persist();
    notifyListeners();
  }

  Future<void> updatePart(Part updated) async {
    final index = _parts.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    _parts[index] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> removePart(String id) async {
    _parts.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  /// Simula uma nova leitura de preço pra essa peça. Se cair, gera um
  /// PriceAlert (e se atingir o preço alvo, avisa isso especificamente).
  /// Usado hoje pelo botão de teste na tela de Detalhe; no futuro é aqui
  /// que entra o resultado de um scraper/API real.
  Future<void> simulatePriceCheck(String partId, double newPrice) async {
    final index = _parts.indexWhere((p) => p.id == partId);
    if (index == -1) return;

    final part = _parts[index];
    final previousPrice = part.currentPrice;
    part.currentPrice = newPrice;
    part.history.add(PricePoint(date: DateTime.now(), price: newPrice));

    if (part.notifyOnDrop && newPrice < previousPrice) {
      final pct = (((newPrice - previousPrice) / previousPrice) * 100).toStringAsFixed(0);
      final reachedTarget = newPrice <= part.targetPrice;
      _alerts.insert(
        0,
        PriceAlert(
          id: _uuid.v4(),
          partId: part.id,
          message: reachedTarget
              ? '${part.name} atingiu seu preço alvo! Agora por R\$ ${newPrice.toStringAsFixed(2)}'
              : '${part.name} caiu para R\$ ${newPrice.toStringAsFixed(2)} ($pct%)',
          date: DateTime.now(),
        ),
      );
    }

    await _persist();
    notifyListeners();
  }

  List<Part> _seedParts() {
    DateTime d(int daysAgo) => DateTime.now().subtract(Duration(days: daysAgo));
    return [
      Part(
        id: _uuid.v4(),
        name: 'RTX 4070 Super',
        category: 'GPU',
        store: 'KaBuM',
        currentPrice: 2899,
        targetPrice: 2500,
        history: [
          PricePoint(date: d(42), price: 3150),
          PricePoint(date: d(35), price: 3080),
          PricePoint(date: d(28), price: 3020),
          PricePoint(date: d(21), price: 2990),
          PricePoint(date: d(14), price: 2950),
          PricePoint(date: d(7), price: 2899),
        ],
      ),
      Part(
        id: _uuid.v4(),
        name: 'Ryzen 7 7800X3D',
        category: 'CPU',
        store: 'Pichau',
        currentPrice: 1750,
        targetPrice: 1600,
        history: [
          PricePoint(date: d(28), price: 1820),
          PricePoint(date: d(14), price: 1790),
          PricePoint(date: d(0), price: 1750),
        ],
      ),
      Part(
        id: _uuid.v4(),
        name: 'Kit DDR5 32GB 6000MHz',
        category: 'RAM',
        store: 'Terabyte',
        currentPrice: 699,
        targetPrice: 600,
        history: [
          PricePoint(date: d(14), price: 685),
          PricePoint(date: d(0), price: 699),
        ],
      ),
      Part(
        id: _uuid.v4(),
        name: 'SSD NVMe 2TB',
        category: 'SSD',
        store: 'Amazon',
        currentPrice: 599,
        targetPrice: 550,
        history: [
          PricePoint(date: d(21), price: 705),
          PricePoint(date: d(7), price: 650),
          PricePoint(date: d(0), price: 599),
        ],
      ),
    ];
  }

  List<BuildConfig> _seedBuilds() {
    return [
      BuildConfig(id: _uuid.v4(), name: 'Setup 1440p Ultra', price: 9489.6, pieces: 7),
      BuildConfig(id: _uuid.v4(), name: 'Workstation AM5', price: 12320.9, pieces: 9, hasCompatibilityWarning: true),
      BuildConfig(id: _uuid.v4(), name: 'PC Custo-benefício', price: 4279.5, pieces: 6),
    ];
  }

  List<PriceAlert> _seedAlerts(List<Part> parts) {
    return [
      PriceAlert(
        id: _uuid.v4(),
        partId: parts[0].id,
        message: '${parts[0].name} caiu para R\$ ${parts[0].currentPrice.toStringAsFixed(2)} (-8%)',
        date: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      PriceAlert(
        id: _uuid.v4(),
        partId: parts[2].id,
        message: '${parts[2].name} voltou ao estoque na Terabyte',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
      PriceAlert(
        id: _uuid.v4(),
        partId: parts[3].id,
        message: '${parts[3].name} atingiu seu preço alvo!',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 10)),
      ),
      PriceAlert(
        id: _uuid.v4(),
        partId: parts[1].id,
        message: '${parts[1].name} caiu 3% essa semana',
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}
