import 'package:flutter_test/flutter_test.dart';
import 'package:partwatch/data/parts_repository.dart';
import 'package:partwatch/models/part.dart';

void main() {
  test('Supabase price rows map to domain models without demo data', () {
    final date = DateTime.utc(2026, 11, 18);
    final history = [PricePoint(date: date, price: 920.00)];
    final part = PartsRepository.partFromRow(
      {
        'id': 'e24241ee-ea1f-4f48-b314-5e12b88fe126',
        'name': 'DDR5 32GB',
        'category': 'RAM',
        'store': 'KaBuM',
        'current_price': '899.90',
        'target_price': 820,
        'notify_on_drop': false,
      },
      history: history,
    );

    expect(part.name, 'DDR5 32GB');
    expect(part.currentPrice, 899.90);
    expect(part.targetPrice, 820);
    expect(part.notifyOnDrop, false);
    expect(part.history.single.price, 920.00);
    expect(part.deltaPercent, closeTo(-2.184, 0.002));
    expect(part.reachedTarget, false);
  });

  test('newly created part can have empty history', () {
    final part = PartsRepository.partFromRow({
      'id': '12722d56-bcbc-4e19-86ea-2e41e255a21b',
      'name': 'SSD NVMe',
      'category': 'SSD',
      'store': 'KaBuM',
      'current_price': 500.00,
      'target_price': 600.00,
      'notify_on_drop': true,
    });

    expect(part.history, isEmpty);
    expect(part.deltaPercent, isNull);
    expect(part.reachedTarget, isTrue);
  });
}
