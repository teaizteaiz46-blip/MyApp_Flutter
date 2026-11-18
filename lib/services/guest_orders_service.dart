import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show supabase;
import 'order_confirm_service.dart';

/// "طلباتي" للزبون بدون حساب: لكل طلب ياخذ التطبيق مفتاح سري من السيرفر (بس إذا الرقم مطابق،
/// public.guest_order_ticket) ويحفظه بالموبايل. بالمفاتيح تنعرض طلباته (public.guest_orders)،
/// ومن يسوي حساب أو يسجل دخول تنتقل لحسابه (public.claim_guest_orders).
class GuestOrdersService {
  GuestOrdersService._();

  static const String _ticketsKey = 'guest_order_tickets_v1'; // [{id, token}]
  static const String _pendingKey = 'guest_order_pending_v1'; // [{id, phone}] إذا ما وصل المفتاح (ماكو نت)
  static const int _max = 50;

  /// عدد الطلبات المحفوظة بهذا الموبايل (لسطر "طلباتي" بصفحة الحساب)
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static Future<List<Map<String, dynamic>>> _read(SharedPreferences prefs, String key) async {
    try {
      return (jsonDecode(prefs.getString(key) ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(SharedPreferences prefs, String key, List<Map<String, dynamic>> list) =>
      prefs.setString(key, jsonEncode(list.take(_max).toList()));

  static Future<List<String>> tokens() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _read(prefs, _ticketsKey)).map((t) => '${t['token']}').where((t) => t.isNotEmpty).toList();
  }

  /// فتح التطبيق: يعيد المفاتيح الناقصة، ويجيب مفاتيح آخر طلبات قبل هذي النسخة (من تأكيد الطلب)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tickets = await _read(prefs, _ticketsKey);
      count.value = tickets.length;
      if (supabase.auth.currentUser != null) return; // المسجّل طلباته بحسابه
      final pending = await _read(prefs, _pendingKey);
      final known = {for (final t in tickets) t['id']};
      for (final r in await OrderConfirmService.recentRefs()) {
        if (!known.contains(r.id) && !pending.any((p) => p['id'] == r.id)) pending.add({'id': r.id, 'phone': r.phone});
      }
      if (pending.isEmpty) return;
      final left = <Map<String, dynamic>>[];
      for (final p in pending) {
        final id = (p['id'] as num?)?.toInt();
        final phone = '${p['phone'] ?? ''}';
        if (id == null || phone.isEmpty || known.contains(id)) continue;
        final ok = await _fetchTicket(prefs, id, phone);
        if (ok == null) left.add(p); // ماكو نت: نحاول بعدين
      }
      await _write(prefs, _pendingKey, left);
    } catch (e) {
      debugPrint('GuestOrders.init: $e');
    }
  }

  /// بعد طلب الضيف مباشرة
  static Future<void> remember(int orderId, String phone) async {
    if (supabase.auth.currentUser != null) return;
    final prefs = await SharedPreferences.getInstance();
    final ok = await _fetchTicket(prefs, orderId, phone);
    if (ok == null) {
      final pending = await _read(prefs, _pendingKey);
      pending.insert(0, {'id': orderId, 'phone': phone});
      await _write(prefs, _pendingKey, pending);
    }
  }

  /// true = انحفظ، false = السيرفر رفض (رقم غلط أو طلب قديم)، null = ماكو نت
  static Future<bool?> _fetchTicket(SharedPreferences prefs, int orderId, String phone) async {
    try {
      final token = await supabase.rpc('guest_order_ticket', params: {'p_order_id': orderId, 'p_phone': phone});
      if (token is! String || token.isEmpty) return false;
      final tickets = await _read(prefs, _ticketsKey);
      tickets.removeWhere((t) => t['id'] == orderId);
      tickets.insert(0, {'id': orderId, 'token': token});
      await _write(prefs, _ticketsKey, tickets);
      count.value = tickets.length;
      return true;
    } catch (e) {
      debugPrint('GuestOrders.ticket: $e');
      return null;
    }
  }

  /// طلبات هذا الموبايل (نفس شكل طلبات الحساب)
  static Future<List<Map<String, dynamic>>> load() async {
    final list = await tokens();
    if (list.isEmpty) return const [];
    final res = await supabase.rpc('guest_orders', params: {'p_tokens': list});
    return ((res as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// بعد تسجيل الدخول: طلبات الموبايل تنتقل للحساب. يرجع عدد اللي انتقلت.
  static Future<int> claimToAccount() async {
    final list = await tokens();
    if (list.isEmpty || supabase.auth.currentUser == null) return 0;
    try {
      final n = await supabase.rpc('claim_guest_orders', params: {'p_tokens': list});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ticketsKey);
      await prefs.remove(_pendingKey);
      count.value = 0;
      return (n as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('GuestOrders.claim: $e');
      return 0;
    }
  }
}
