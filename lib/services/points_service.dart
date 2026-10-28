import 'package:flutter/widgets.dart';

import '../main.dart';

/// نقاط MODO: الرصيد، هدية اليوم (سلسلة 7 أيام)، وكود الدعوة. الحساب كله بالسيرفر.
/// النقطة = 10 د.ع.
class PointsState {
  const PointsState({
    required this.balance,
    required this.claimedToday,
    required this.streakDay,
    required this.todayPoints,
    required this.rule,
    required this.referralCode,
    required this.history,
  });

  final int balance;
  final bool claimedToday;

  /// يوم السلسلة (1-7): اليوم المستلم، أو الي راح يستلمه
  final int streakDay;
  final int todayPoints;
  final List<int> rule;
  final String referralCode;
  final List<Map<String, dynamic>> history;

  static const int iqdPerPoint = 10;

  int get balanceIqd => balance * iqdPerPoint;

  factory PointsState.fromJson(Map<String, dynamic> j) => PointsState(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        claimedToday: j['claimed_today'] == true,
        streakDay: (j['streak_day'] as num?)?.toInt() ?? 1,
        todayPoints: (j['today_points'] as num?)?.toInt() ?? 0,
        rule: ((j['rule'] as List?) ?? const [5, 5, 10, 10, 15, 15, 40]).map((e) => (e as num).toInt()).toList(),
        referralCode: (j['referral_code'] ?? '').toString(),
        history: ((j['history'] as List?) ?? const []).cast<Map<String, dynamic>>(),
      );
}

class PointsService {
  PointsService._();
  static final PointsService instance = PointsService._();

  /// null = زائرة (ما مسجلة) أو بعده ما تحمّل
  final ValueNotifier<PointsState?> state = ValueNotifier(null);

  bool get signedIn => supabase.auth.currentUser != null;

  AppLifecycleListener? _lifecycle;

  Future<void> refresh() async {
    // يوم جديد والتطبيق بالخلفية: نحدث لما يرجع (حتى تطلع هدية اليوم)
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
    if (!signedIn) {
      state.value = null;
      return;
    }
    try {
      final res = await supabase.rpc('my_points');
      state.value = PointsState.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('Points refresh failed: $e');
    }
  }

  /// يستلم هدية اليوم ويرجع عدد النقاط
  Future<int> claimDaily() async {
    final res = Map<String, dynamic>.from(await supabase.rpc('claim_daily_points') as Map);
    await refresh();
    return (res['points'] as num?)?.toInt() ?? 0;
  }

  void clear() => state.value = null;
}
