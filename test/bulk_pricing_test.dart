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

  group('مجموعات العرض (نفس private.cart_price)', () {
    Map<String, dynamic> bra(String? g) => {
          'price': 8000,
          'stock': 50,
          'offer_group': g,
          'bulk_tiers': [
            {'qty': 2, 'price': 16000, 'free_delivery': true},
          ],
        };

    test('قطعة من كل موديل بنفس المجموعة = 16000 وتوصيل مجاني', () {
      final q = quoteCart(
        const [CartLine(productId: 863, quantity: 1), CartLine(productId: 864, quantity: 1)],
        {863: bra('برا 8 آلاف'), 864: bra('برا 8 آلاف')},
      );
      expect(q.subtotal, 16000);
      expect(q.freeDelivery, isTrue);
      expect(q.byProduct[863]!.total, 8000);
      expect(q.byProduct[864]!.total, 8000);
      expect(q.groupQtyFor(863), 2);
    });

    test('بدون مجموعة: كل منتج لحاله، ماكو توصيل مجاني', () {
      final q = quoteCart(
        const [CartLine(productId: 863, quantity: 1), CartLine(productId: 864, quantity: 1)],
        {863: bra(null), 864: bra('')},
      );
      expect(q.subtotal, 16000);
      expect(q.freeDelivery, isFalse);
    });

    test('3 قطع بالمجموعة = باقة + قطعة', () {
      final q = quoteCart(
        const [CartLine(productId: 863, quantity: 2), CartLine(productId: 864, quantity: 1)],
        {863: bra('x'), 864: bra('x')},
      );
      expect(q.subtotal, 24000);
      expect(q.freeDelivery, isTrue);
    });

    test('أسعار مختلفة: الباقة تاخذ الأغلى أول والتوزيع حسب السعر', () {
      final cheap = {...bra('x'), 'price': 6000};
      final q = quoteCart(
        const [CartLine(productId: 1, quantity: 1), CartLine(productId: 2, quantity: 2)],
        {1: bra('x'), 2: cheap}, // درجات المجموعة من أصغر id (1): قطعتين بـ 16000
      );
      // الباقة: قطعة 8000 + قطعة 6000 (الأغلى أول) = 16000، والباقي قطعة 6000
      expect(q.subtotal, 22000);
      expect(q.byProduct[1]!.total + q.byProduct[2]!.total, 22000);
      // نفس أرقام private.cart_price بالسيرفر لنفس الحالة
      expect(q.byProduct[1]!.total, 9143);
      expect(q.byProduct[2]!.total, 12857);
    });
  });

  test('تلميح أقرب درجة', () {
    final hint = nextBulkHintForProduct(product, 1);
    expect(hint?.missing, 1);
    expect(hint?.tier.qty, 2);
    expect(nextBulkHintForProduct(product, 2)?.tier.qty, 3);
  });
}
