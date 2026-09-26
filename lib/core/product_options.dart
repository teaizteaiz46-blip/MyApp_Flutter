// خيارات المنتج (عمود colors) ممكن تكون ألوان، أو قياسات، أو موديل + قياس مثل "ورد وردي – M".
// هنا نحدد العنوان المناسب حتى الزبون ما يشوف "اللون: M".

enum OptionKind { color, size, colorAndSize, modelAndSize }

// أسماء ألوان شائعة (مع اختلاف الكتابة) حتى "أبيض – L" يطلع "اللون والقياس" مو "الموديل والقياس"
const Set<String> _colorWords = {
  'ابيض', 'أبيض', 'اسود', 'أسود', 'وردي', 'بنفسجي', 'ليلكي', 'احمر', 'أحمر', 'ازرق', 'أزرق', 'نيلي',
  'اخضر', 'أخضر', 'زيتي', 'اصفر', 'أصفر', 'برتقالي', 'بيج', 'رمادي', 'رصاصي', 'جوزي', 'بني', 'نهدي',
  'كحلي', 'سمائي', 'فيروزي', 'عنابي', 'خمري', 'ذهبي', 'فضي', 'كريمي', 'حليبي', 'سكري', 'موف', 'فوشي',
};

final RegExp _size = RegExp(
  r'^(XXS|XS|S|M|L|XL|XXL|XXXL|[2-6]XL|\d{2,3}|FREE ?SIZE|فري ?سايز)$',
  caseSensitive: false,
);
final RegExp _modelAndSize = RegExp(r'^(.+?)\s*[–—\-/]\s*(\S+)$');

bool _isSize(String v) => _size.hasMatch(v.trim());

bool _isModelAndSize(String v) {
  final m = _modelAndSize.firstMatch(v.trim());
  return m != null && _isSize(m.group(2)!);
}

bool _isColorAndSize(String v) {
  final m = _modelAndSize.firstMatch(v.trim());
  return m != null && _isSize(m.group(2)!) && _colorWords.contains(m.group(1)!.trim());
}

OptionKind optionKindOf(List<String> options) {
  final list = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) return OptionKind.color;
  if (list.every(_isSize)) return OptionKind.size;
  if (list.every((v) => _isSize(v) || _isModelAndSize(v))) {
    return list.where((v) => !_isSize(v)).every(_isColorAndSize) ? OptionKind.colorAndSize : OptionKind.modelAndSize;
  }
  return OptionKind.color;
}

/// "اللون" / "القياس" / "اللون والقياس" / "الموديل والقياس"
String optionTitle(List<String> options) => switch (optionKindOf(options)) {
      OptionKind.color => 'اللون',
      OptionKind.size => 'القياس',
      OptionKind.colorAndSize => 'اللون والقياس',
      OptionKind.modelAndSize => 'الموديل والقياس',
    };

List<String> optionsOf(Map<String, dynamic>? product) =>
    ((product?['colors'] as List?) ?? const []).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
