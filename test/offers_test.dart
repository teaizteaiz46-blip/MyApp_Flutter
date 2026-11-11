import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/core/bulk_pricing.dart';
import 'package:myapprun/services/cart_service.dart';
import 'package:myapprun/services/offers_service.dart';

/// نفس حالات اختبار السيرفر (private.cart_price) حتى السعر بالتطبيق يطابق الطلب
void main() {
  Map<String, dynamic> product(int id, double price, {List<Map<String, dynamic>> tiers = const []}) => {
        'id': id,
        'price': price,
        'stock': 50,
        'bulk_tiers': tiers,
      };

  const bundle = Offer(
    id: 1,
    title: 'عرض الشتاء',
    isBundle: true,
    qty: 3,
    price: 20000,
    freeDelivery: true,
    endsAt: null,
    productIds: [10, 11],
  );
  const freeDelivery = Offer(
    id: 2,
    title: 'توصيل مجاني',
    isBundle: false,
    qty: 3,
    price: 0,
    freeDelivery: true,
    endsAt: null,
    productIds: [20, 21],
  );

  setUp(() => OffersService.debugSetOffers(const [bundle, freeDelivery]));

  Map<int, Map<String, dynamic>> catalog() => OffersService.applyAll({
        // 10 عنده عرض كمية خاص؛ العرض يلغيه
        10: product(10, 9000, tiers: [
          {'qty': 2, 'price': 15000},
        ]),
        11: product(11, 8000),
        20: product(20, 6000),
        21: product(21, 7000),
        30: product(30, 5000),
      });

  CartLine line(int id, int q) => CartLine(productId: id, quantity: q);

  test('باقة من موديلين: 2 + 1 = 20,000 وتوصيل مجاني', () {
    final q = quoteCart([line(10, 2), line(11, 1)], catalog());
    expect(q.subtotal, 20000);
    expect(q.freeDelivery, isTrue);
  });

  test('باقة ناقصة: 1 + 1 بالسعر العادي وبدون توصيل مجاني', () {
    final q = quoteCart([line(10, 1), line(11, 1)], catalog());
    expect(q.subtotal, 17000);
    expect(q.freeDelivery, isFalse);
  });

  test('باقتين + قطعة: الأغلى تدخل بالباقات والباقي بسعره (48,000 مثل السيرفر)', () {
    final q = quoteCart([line(10, 4), line(11, 3)], catalog());
    expect(q.subtotal, 48000);
    expect(q.freeDelivery, isTrue);
  });

  test('عرض توصيل مجاني: الأسعار عادية والتوصيل مجاني من يوصل العدد', () {
    final cat = catalog();
    final short = quoteCart([line(20, 1), line(21, 1)], cat);
    expect(short.subtotal, 13000);
    expect(short.freeDelivery, isFalse);

    final full = quoteCart([line(20, 2), line(21, 1), line(30, 1)], cat);
    expect(full.subtotal, 6000 * 2 + 7000 + 5000);
    expect(full.freeDelivery, isTrue);
  });

  test('توصيل مجاني حسب عدد القطع بالطلب كله (مثل store_settings بالسيرفر)', () {
    final cat = catalog();
    final three = quoteCart([line(30, 1), line(11, 1), line(20, 1)], cat, freeDeliveryMinPieces: 4);
    expect(three.freeDelivery, isFalse);
    expect(three.piecesToFreeDelivery, 1);

    final four = quoteCart([line(30, 2), line(11, 1), line(20, 1)], cat, freeDeliveryMinPieces: 4);
    expect(four.freeDelivery, isTrue);
    expect(four.piecesToFreeDelivery, isNull);
    expect(four.subtotal, 5000 * 2 + 8000 + 6000); // الأسعار ما تتغير

    final off = quoteCart([line(30, 9)], cat);
    expect(off.freeDelivery, isFalse);
    expect(off.piecesToFreeDelivery, isNull);
  });

  test('منتج بدون عرض ما يتغير', () {
    final p = product(30, 5000);
    expect(OffersService.apply(p), same(p));
  });

  test('نص القاعدة', () {
    expect(bundle.rule, 'أي 3 قطع من منتجات العرض بـ 20,000 د.ع + توصيل مجاني');
    expect(freeDelivery.rule, 'اجمعوا 3 قطع من منتجات العرض والتوصيل مجاني');
  });
}
