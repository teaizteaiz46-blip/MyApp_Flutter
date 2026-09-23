import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/core/bulk_pricing.dart';
import 'package:myapprun/services/cart_service.dart';

void main() {
  final product = <String, dynamic>{
    'price': 5000,
    'stock': 50,
    'bulk_tiers': [
      {'qty': 2, 'price': 9500},
      {'qty': 3, 'price': 14000, 'free_delivery': true},
    ],
  };

  test('باقات: 7 قطع = باقتين من 3 + قطعة عادية', () {
    final q = quoteProduct(product, 7);
    expect(q.total, 14000 * 2 + 5000);
    expect(q.freeDelivery, isTrue);
  });

  test('الدرجة الأصغر تنطبق على الباقي', () {
    final q = quoteProduct(product, 5); // 3 + 2
    expect(q.total, 14000 + 9500);
  });

  test('بدون درجة: السعر العادي وبدون توصيل مجاني', () {
    final q = quoteProduct(product, 1);
    expect(q.total, 5000);
    expect(q.freeDelivery, isFalse);
    expect(q.applied, isFalse);
  });

  test('درجات غير صالحة تنتجاهل مثل السيرفر', () {
    final tiers = BulkTier.parseList([
      {'qty': 1, 'price': 100},
      {'qty': -2, 'price': 100},
      {'qty': 2.5, 'price': 100},
      {'qty': 2, 'price': -5},
      {'qty': '4', 'price': '100'},
      'junk',
    ]);
    expect(tiers.map((t) => t.qty), [4]);
    expect(BulkTier.parseList('[]'), isEmpty);
  });

  test('السلة تجمع الكمية عبر الألوان', () {
    final quote = quoteCart(
      const [
        CartLine(productId: 1, quantity: 2, color: 'أحمر'),
        CartLine(productId: 1, quantity: 1, color: 'أزرق'),
      ],
      {1: product},
    );
    expect(quote.subtotal, 14000);
    expect(quote.freeDelivery, isTrue);
    expect(quote.saving, 1000);
  });

  test('تلميح أقرب درجة', () {
    final hint = nextBulkHintForProduct(product, 1);
    expect(hint?.missing, 1);
    expect(hint?.tier.qty, 2);
    expect(nextBulkHintForProduct(product, 2)?.tier.qty, 3);
  });
}
