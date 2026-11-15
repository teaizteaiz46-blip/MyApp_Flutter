import '../main.dart' show supabase;

/// حالة حساب المستخدم ببرنامج المؤثرين (public.my_influencer_wallet).
class InfluencerStatus {
  const InfluencerStatus({required this.isInfluencer, this.wallet, this.applicationStatus, this.reviewedAt});

  final bool isInfluencer;

  /// للمؤثر: نفس influencer_dashboard + balance (بدون أي معلومات عن الزبائن)
  final Map<String, dynamic>? wallet;

  /// لغير المؤثر: pending / approved / rejected أو null إذا ما قدّم
  final String? applicationStatus;
  final DateTime? reviewedAt;

  /// بعد الرفض يگدر يقدم مرة ثانية بعد أسبوع (نفس شرط السيرفر)
  bool get canReapply =>
      applicationStatus == 'rejected' &&
      (reviewedAt == null || DateTime.now().difference(reviewedAt!) > const Duration(days: 7));
}

class InfluencerService {
  InfluencerService._();

  /// رابط التطبيق للمؤثر (نفس رابط صفحة الأدمن و inf.html، حتى الزيارات تنحسب له)
  static String shareLink(String code) =>
      'https://teaizteaiz46-blip.github.io/Modo-orders/app.html?utm_source=influencer&utm_campaign=inf_${code.toLowerCase()}';

  static Future<InfluencerStatus?> status() async {
    final res = await supabase.rpc('my_influencer_wallet');
    if (res is! Map) return null;
    final map = Map<String, dynamic>.from(res);
    if (map['is_influencer'] == true) return InfluencerStatus(isInfluencer: true, wallet: map);
    final app = map['application'] is Map ? Map<String, dynamic>.from(map['application'] as Map) : null;
    return InfluencerStatus(
      isInfluencer: false,
      applicationStatus: app?['status']?.toString(),
      reviewedAt: DateTime.tryParse('${app?['reviewed_at'] ?? ''}')?.toLocal(),
    );
  }

  static Future<void> apply({
    required String name,
    required String phone,
    required String socialUrl,
    int? followers,
    String? note,
  }) async {
    await supabase.rpc('submit_influencer_application', params: {
      'p_name': name.trim(),
      'p_phone': phone.trim(),
      'p_social_url': socialUrl.trim(),
      'p_followers': followers,
      'p_note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    });
  }
}
