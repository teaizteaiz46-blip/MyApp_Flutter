import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/services/deep_link_service.dart';

void main() {
  int? id(String link) => DeepLinkService.productIdFrom(Uri.parse(link));

  test('رابط التطبيق', () {
    expect(id('modoiraq://product/861'), 861);
    expect(id('modoiraq://product/861/'), 861);
    // ميتا أحياناً تضيف باراميترات للرابط
    expect(id('modoiraq://product/861?al_applink_data=%7B%7D'), 861);
  });

  test('صفحة المنتج على الويب', () {
    expect(id('https://teaizteaiz46-blip.github.io/Modo-orders/p.html?id=861&fbclid=x'), 861);
  });

  test('روابط غير صالحة', () {
    expect(id('modoiraq://product/'), isNull);
    expect(id('modoiraq://product/abc'), isNull);
    expect(id('modoiraq://cart/5'), isNull);
    expect(id('fb2389635998228651://authorize'), isNull);
    expect(id('https://example.com/?id=861'), isNull);
  });
}
