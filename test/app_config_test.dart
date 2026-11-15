import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/services/app_config.dart';
import 'package:myapprun/services/update_service.dart';

void main() {
  test('القيم الافتراضية تطابق التطبيق الحالي (الكل + الأكثر طلباً، بدون إجبار)', () {
    AppConfig.debugSet(const {});
    expect(AppConfig.homeCategory, 0);
    expect(AppConfig.homeSort, 'bestSelling');
    expect(AppConfig.forceUpdate, isFalse);
    expect(AppConfig.minBuildAndroid, isNull);
    expect(AppConfig.freeDeliveryPieces, isNull);
  });

  test('يقرا قيم store_settings', () {
    AppConfig.debugSet(const {
      'home_default_category': 4,
      'home_default_sort': 'newest',
      'force_update_on': true,
      'min_build_android': 67,
      'free_delivery_pieces_on': true,
      'free_delivery_min_pieces': 4,
    });
    expect(AppConfig.homeCategory, 4);
    expect(AppConfig.homeSort, 'newest');
    expect(AppConfig.forceUpdate, isTrue);
    expect(AppConfig.minBuildAndroid, 67);
    expect(AppConfig.minBuildIos, isNull);
    expect(AppConfig.freeDeliveryPieces, 4);
  });

  test('مقارنة النسخ للتحديث الإجباري', () {
    expect(isNewerVersion('2.0.5', '2.0.4'), isTrue);
    expect(isNewerVersion('2.0.10', '2.0.9'), isTrue);
    expect(isNewerVersion('2.1', '2.0.9'), isTrue);
    expect(isNewerVersion('2.0.4', '2.0.4'), isFalse);
    expect(isNewerVersion('2.0.4', '2.0.5'), isFalse); // مراجع Apple نسخته أحدث: ما ينحبس
    expect(isNewerVersion('', '2.0.4'), isFalse);
  });
}
