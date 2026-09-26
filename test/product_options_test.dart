import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/core/product_options.dart';

void main() {
  test('ألوان', () {
    expect(optionTitle(['أسود', 'بيج', 'وردي']), 'اللون');
    // أرقام ألوان من رقم واحد (1، 2) مو قياسات
    expect(optionTitle(['1', '2', '12']), 'اللون');
  });

  test('قياسات', () {
    expect(optionTitle(['M', 'L', 'XL', '2XL']), 'القياس');
    expect(optionTitle(['s', 'm', 'xxl']), 'القياس');
    expect(optionTitle(['38', '40', '42']), 'القياس');
  });

  test('موديل وقياس', () {
    expect(optionTitle(['ورد وردي – M', 'كاروهات أزرق – 2XL', 'فيونكات ليلكي - L']), 'الموديل والقياس');
  });

  test('خليط غير واضح يبقى لون', () {
    expect(optionTitle(['أسود', 'M']), 'اللون');
    expect(optionTitle(const []), 'اللون');
  });
}
