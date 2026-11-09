import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

/// رسالة بالمحادثة: من الزبون، أو رد فريق MODO (نص أو كارت منتج)
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.productId,
    required this.imageIndex,
    required this.createdAt,
  });

  final int id;
  final bool mine;
  final String body;
  final int? productId;
  final int imageIndex;
  final DateTime createdAt;

  /// كارت منتج من الفريق (بدون نص)
  bool get isProductCard => !mine && productId != null && body.isEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        mine: j['sender'] == 'customer',
        body: (j['body'] ?? '').toString(),
        productId: (j['product_id'] as num?)?.toInt(),
        imageIndex: (j['image_index'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// دردشة الزبون ويه فريق MODO (بدون تسجيل).
/// المحادثة مربوطة بمفتاح عشوائي محفوظ بالجهاز، والرسائل توصل للفريق على تيليگرام.
class ChatService {
  ChatService._();

  static const _tokenKey = 'chat_token_v1';
  static const _startedKey = 'chat_started_v1';

  /// عدد ردود الفريق اللي الزبون ما شافها (للزر بالرئيسية)
  static final ValueNotifier<int> unread = ValueNotifier(0);

  /// شاشة المحادثة مفتوحة: الإشعار يحدّثها بدل ما يزيد العداد
  static bool screenOpen = false;
  static final StreamController<void> _refresh = StreamController<void>.broadcast();
  static Stream<void> get refreshes => _refresh.stream;

  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    var t = prefs.getString(_tokenKey);
    if (t == null || t.length < 32) {
      final rnd = Random.secure();
      t = base64Url.encode(List<int>.generate(32, (_) => rnd.nextInt(256))).replaceAll('=', '');
      await prefs.setString(_tokenKey, t);
    }
    return t;
  }

  static Future<bool> started() async =>
      (await SharedPreferences.getInstance()).getBool(_startedKey) ?? false;

  static Future<String?> _pushToken() async {
    try {
      return await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  static Future<ChatMessage> send(String body, {int? productId}) async {
    final res = Map<String, dynamic>.from(await supabase.rpc('chat_send', params: {
      'p_token': await _token(),
      'p_body': body,
      'p_product_id': productId,
      'p_fcm': await _pushToken(),
      'p_platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    }) as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startedKey, true);
    return ChatMessage.fromJson(Map<String, dynamic>.from(res['message'] as Map));
  }

  static Future<List<ChatMessage>> history({int after = 0}) async {
    if (!await started()) return const [];
    final res = Map<String, dynamic>.from(await supabase.rpc('chat_history', params: {
      'p_token': await _token(),
      'p_after': after,
      'p_mark_read': true,
    }) as Map);
    unread.value = 0;
    return ((res['messages'] as List?) ?? const [])
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> refreshUnread() async {
    try {
      if (screenOpen || !await started()) return;
      final n = await supabase.rpc('chat_unread', params: {'p_token': await _token()});
      unread.value = (n as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  static Future<void> report(String reason) async {
    await supabase.rpc('chat_report', params: {'p_token': await _token(), 'p_reason': reason});
  }

  /// يمسح المحادثة من السيرفر، والمرة الجاية تبدي محادثة جديدة بمفتاح جديد
  static Future<void> deleteConversation() async {
    await supabase.rpc('chat_delete', params: {'p_token': await _token()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_startedKey);
    unread.value = 0;
  }

  /// وصل إشعار رد من الفريق
  static void onPush() {
    if (screenOpen) {
      _refresh.add(null);
    } else {
      unread.value = unread.value + 1;
    }
  }
}
