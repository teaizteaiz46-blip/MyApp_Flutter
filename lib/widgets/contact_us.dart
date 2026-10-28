import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// تواصلي ويانا: حسابات MODO (تنفتح بتطبيق المنصة إذا منصّب، وإلا بالمتصفح)
class ContactUsSection extends StatelessWidget {
  const ContactUsSection({super.key});

  static const _links = [
    (
      'انستغرام',
      '@modo.iraqis',
      'https://www.instagram.com/modo.iraqis/',
      Icons.camera_alt_outlined,
      [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
    ),
    (
      'تيك توك',
      '@iq.modo',
      'https://www.tiktok.com/@iq.modo',
      Icons.tiktok,
      [Color(0xFF111111), Color(0xFF111111)],
    ),
    (
      'فيسبوك',
      'modo.iraqs',
      'https://www.facebook.com/modo.iraqs',
      Icons.facebook,
      [Color(0xFF1877F2), Color(0xFF1877F2)],
    ),
  ];

  static Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تواصلي ويانا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('تابعينا حتى يوصلج الجديد والعروض أول بأول', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _links.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _open(context, _links[i].$3),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(colors: _links[i].$5),
                        ),
                        child: Column(
                          children: [
                            Icon(_links[i].$4, color: Colors.white, size: 26),
                            const SizedBox(height: 4),
                            Text(_links[i].$1,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(_links[i].$2,
                                textDirection: TextDirection.ltr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
