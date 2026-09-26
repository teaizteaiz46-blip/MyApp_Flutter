// خيارات المنتج (عمود colors) ممكن تكون ألوان، أو قياسات، أو موديل + قياس مثل "ورد وردي – M".
// هنا نحدد العنوان المناسب حتى الزبون ما يشوف "اللون: M".

enum OptionKind { color, size, modelAndSize }

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

OptionKind optionKindOf(List<String> options) {
  final list = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) return OptionKind.color;
  if (list.every(_isSize)) return OptionKind.size;
  if (list.every((v) => _isSize(v) || _isModelAndSize(v))) return OptionKind.modelAndSize;
  return OptionKind.color;
}

/// "اللون" / "القياس" / "الموديل والقياس"
String optionTitle(List<String> options) => switch (optionKindOf(options)) {
      OptionKind.color => 'اللون',
      OptionKind.size => 'القياس',
      OptionKind.modelAndSize => 'الموديل والقياس',
    };

List<String> optionsOf(Map<String, dynamic>? product) =>
    ((product?['colors'] as List?) ?? const []).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
