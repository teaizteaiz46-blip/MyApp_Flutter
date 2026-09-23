import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cart_service.dart';

/// الأعمدة المسموح للتطبيق يقراها من جدول المنتجات.
/// لا تستخدم `.select()` بدون أعمدة، حتى ما تنسحب كلفة المنتج (product_cost).
const String kProductBaseColumns =
    'id, name, price, old_price, image_url, rating, sales_count, stock, '
    'colors, description, is_offer, category_id, promo_tag, brand, created_at';

/// bulk_tiers: درجات عروض الكمية (jsonb)، شوف core/bulk_pricing.dart.
const String kProductColumns = '$kProductBaseColumns, bulk_tiers';

const double kDefaultDeliveryCost = 3000;

const List<String> kIraqGovernorates = [
  'بغداد', 'كربلاء', 'الأنبار', 'الحلة - بابل', 'البصرة', 'دهوك', 'ديالى',
  'أربيل', 'كركوك', 'العمارة - ميسان', 'السماوة - المثنى', 'النجف', 'نينوى',
  'ديوانية - القادسية', 'صلاح الدين', 'السليمانية', 'الناصرية - ذي قار',
  'الكوت - واسط', 'حلبجة',
];

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

class OrderResult {
  const OrderResult({
    required this.orderId,
    required this.subtotal,
    required this.delivery,
    required this.discount,
    required this.total,
  });

  final int orderId;
  final double subtotal;
  final double delivery;
  final double discount;
  final double total;

  factory OrderResult.fromJson(Map<String, dynamic> json) => OrderResult(
        orderId: (json['order_id'] as num).toInt(),
        subtotal: _toDouble(json['subtotal']),
        delivery: _toDouble(json['delivery']),
        discount: _toDouble(json['discount']),
        total: _toDouble(json['total']),
      );
}

class CouponCheck {
  const CouponCheck({required this.valid, required this.discount, required this.message});

  final bool valid;
  final double discount;
  final String message;
}

class ShopApi {
  ShopApi._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// يحوّل الرقم لصيغة 07XXXXXXXXX (يقبل أرقام عربية، مسافات، و +964).
  /// يرجع null إذا الرقم غير صحيح. نفس المنطق موجود بالسيرفر.
  static String? normalizePhone(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      if (a >= 0) {
        buffer.write(a);
      } else if (p >= 0) {
        buffer.write(p);
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    var digits = buffer.toString();
    if (digits.startsWith('00964')) {
      digits = '0${digits.substring(5)}';
    } else if (digits.startsWith('964')) {
      digits = '0${digits.substring(3)}';
    } else if (RegExp(r'^7\d{9}$').hasMatch(digits)) {
      digits = '0$digits';
    }
    return RegExp(r'^07\d{9}$').hasMatch(digits) ? digits : null;
  }

  static Future<Map<int, Map<String, dynamic>>> fetchProductsByIds(Iterable<int> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _db.from('products').select(kProductColumns).inFilter('id', list);
    return {for (final row in rows) (row['id'] as num).toInt(): row};
  }

  static Future<Map<String, double>> fetchDeliveryCosts() async {
    try {
      final rows = await _db.from('delivery').select('governorate, delivery_cost');
      return {
        for (final row in rows)
          if (row['governorate'] != null && row['delivery_cost'] != null)
            (row['governorate'] as String).trim(): _toDouble(row['delivery_cost']),
      };
    } catch (e) {
      debugPrint('fetchDeliveryCosts: $e');
      return {};
    }
  }

  static double deliveryFor(String? governorate, Map<String, double> costs) {
    if (governorate == null) return kDefaultDeliveryCost;
    return costs[governorate.trim()] ?? kDefaultDeliveryCost;
  }

  static Future<CouponCheck> validateCoupon(String code, {String? phone}) async {
    final res = await _db.rpc('validate_coupon', params: {
      'p_code': code.trim(),
      'p_phone': phone,
    });
    final map = Map<String, dynamic>.from(res as Map);
    return CouponCheck(
      valid: map['valid'] == true,
      discount: _toDouble(map['discount']),
      message: (map['message'] ?? '').toString(),
    );
  }

  /// ينشئ الطلب بالكامل بالسيرفر: السعر والتوصيل والخصم والمخزون كلها تنحسب هناك.
  static Future<OrderResult> placeOrder({
    required List<CartLine> lines,
    required String customerName,
    required String customerPhone,
    required String governorate,
    required String address,
    String? couponCode,
  }) async {
    final code = couponCode?.trim();
    final res = await _db.rpc('place_order', params: {
      'p_items': [
        for (final line in lines)
          {'product_id': line.productId, 'quantity': line.quantity, 'color': line.color},
      ],
      'p_customer_name': customerName.trim(),
      'p_customer_phone': customerPhone.trim(),
      'p_governorate': governorate,
      'p_address': address.trim(),
      'p_coupon_code': (code == null || code.isEmpty) ? null : code,
    });
    return OrderResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// يحوّل أي خطأ لرسالة عربية مفهومة للزبون.
  static String friendlyError(Object error) {
    if (error is PostgrestException) {
      // الرسائل الي نرفعها بالسيرفر (raise exception) تجي بكود P0001 وهي عربية جاهزة.
      if (error.code == 'P0001' && error.message.trim().isNotEmpty) {
        return error.message;
      }
      debugPrint('PostgrestException ${error.code}: ${error.message}');
      return 'حدث خطأ بالخادم، حاول مرة ثانية';
    }
    if (error is AuthException) return authMessage(error);

    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException') ||
        text.contains('TimeoutException')) {
      return 'تعذر الاتصال بالإنترنت، تحقق من الشبكة وحاول مرة ثانية';
    }
    debugPrint('Unexpected error: $error');
    return 'حدث خطأ غير متوقع، حاول مرة ثانية';
  }

  static String authMessage(AuthException error) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'هذا البريد مسجّل مسبقاً، سجّل الدخول بدلاً من ذلك';
    }
    if (m.contains('email not confirmed')) {
      return 'البريد غير مفعّل بعد، افتح رسالة التفعيل ببريدك';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'محاولات كثيرة، انتظر قليلاً وحاول مرة ثانية';
    }
    if (m.contains('password')) return 'كلمة المرور ضعيفة أو غير صالحة، جرّب كلمة أقوى';
    return 'تعذر إكمال العملية: ${error.message}';
  }
}
