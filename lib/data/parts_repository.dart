import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/build_config.dart';
import '../models/part.dart';
import '../models/price_alert.dart';

/// The source of truth is the dedicated PartWatch Supabase project.
///
/// The public client operates under the signed-in user's RLS policies.
/// Prices, history and alerts can only be changed by the trusted worker.
class PartsRepository extends ChangeNotifier {
  PartsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  List<Part> _parts = [];
  List<BuildConfig> _builds = [];
  List<PriceAlert> _alerts = [];
  bool _loaded = false;
  String? _error;
  int _generation = 0;

  bool get isLoaded => _loaded;
  String? get error => _error;
  List<Part> get parts => List.unmodifiable(_parts);
  List<BuildConfig> get builds => List.unmodifiable(_builds);

  List<PriceAlert> get alerts {
    final sorted = [..._alerts]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  Part? partById(String id) {
    for (final part in _parts) {
      if (part.id == id) return part;
    }
    return null;
  }

  void clear() {
    _generation++;
    _parts = [];
    _builds = [];
    _alerts = [];
    _error = null;
    _loaded = false;
    notifyListeners();
  }

  /// Fetch data visible to the signed-in user. No demo seed data is uploaded.
  Future<void> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      clear();
      return;
    }

    final generation = ++_generation;
    _parts = [];
    _builds = [];
    _alerts = [];
    _loaded = false;
    _error = null;
    notifyListeners();

    try {
      final partRows = await _client
          .from('parts')
          .select(
            'id,name,category,store,current_price,target_price,notify_on_drop',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final historyRows = await _client
          .from('price_history')
          .select('part_id,price,created_at')
          .order('created_at', ascending: true);
      final alertRows = await _client
          .from('alerts')
          .select('id,part_id,message,created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final buildRows = await _client
          .from('builds')
          .select('id,name,price,pieces,has_compatibility_warning')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (generation != _generation ||
          _client.auth.currentUser?.id != user.id) {
        return;
      }

      final histories = <String, List<PricePoint>>{};
      for (final row in historyRows) {
        final id = row['part_id'] as String;
        histories.putIfAbsent(id, () => []).add(
              PricePoint(
                date: DateTime.parse(row['created_at'] as String),
                price: _price(row['price']),
              ),
            );
      }

      _parts = [
        for (final row in partRows)
          partFromRow(row, history: histories[row['id'] as String] ?? []),
      ];
      _alerts = [
        for (final row in alertRows)
          PriceAlert(
            id: row['id'] as String,
            partId: row['part_id'] as String,
            message: row['message'] as String,
            date: DateTime.parse(row['created_at'] as String),
          ),
      ];
      _builds = [
        for (final row in buildRows)
          BuildConfig(
            id: row['id'] as String,
            name: row['name'] as String,
            price: _price(row['price']),
            pieces: row['pieces'] as int,
            hasCompatibilityWarning:
                row['has_compatibility_warning'] as bool? ?? false,
          ),
      ];
      _loaded = true;
      notifyListeners();
    } catch (e) {
      if (generation == _generation) {
        _error = 'Não foi possível carregar seus dados: ' + e.toString();
        _loaded = true;
        notifyListeners();
      }
    }
  }

  @visibleForTesting
  static Part partFromRow(
    Map<String, dynamic> row, {
    List<PricePoint> history = const [],
  }) {
    return Part(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      store: row['store'] as String,
      currentPrice: _price(row['current_price']),
      targetPrice: _price(row['target_price']),
      notifyOnDrop: row['notify_on_drop'] as bool? ?? true,
      history: history,
    );
  }

  static double _price(dynamic value) {
    if (value is num) return value.toDouble();
    return double.parse(value.toString());
  }

  Future<void> addPart({
    required String name,
    required String category,
    required String store,
    required double currentPrice,
    required double targetPrice,
  }) async {
    _requireUser();
    await _client.from('parts').insert({
      'name': name,
      'category': category,
      'store': store,
      'current_price': currentPrice,
      'target_price': targetPrice,
    });
    await load();
  }

  Future<void> updatePart(Part updated) async {
    _requireUser();
    // Never write current_price from the app: only the server may collect it.
    await _client.from('parts').update({
      'name': updated.name,
      'category': updated.category,
      'store': updated.store,
      'target_price': updated.targetPrice,
      'notify_on_drop': updated.notifyOnDrop,
    }).eq('id', updated.id);
    await load();
  }

  Future<void> removePart(String id) async {
    _requireUser();
    await _client.from('parts').delete().eq('id', id);
    await load();
  }

  Future<void> addBuild(String name) async {
    _requireUser();
    await _client.from('builds').insert({'name': name});
    await load();
  }

  String _requireUser() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Entre na sua conta para sincronizar o PartWatch.');
    }
    return id;
  }
}
