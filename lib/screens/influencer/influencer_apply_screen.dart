import 'package:flutter/material.dart';

import '../../core/shop_api.dart';
import '../../services/influencer_service.dart';
import '../../theme/app_theme.dart';

/// فورم "انضموا كمؤثرين": ينرسل للأدمن ويراجعه. يرجع true إذا انرسل.
class InfluencerApplyScreen extends StatefulWidget {
  const InfluencerApplyScreen({super.key});

  @override
  State<InfluencerApplyScreen> createState() => _InfluencerApplyScreenState();
}

class _InfluencerApplyScreenState extends State<InfluencerApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _social = TextEditingController();
  final _followers = TextEditingController();
  final _note = TextEditingController();
  bool _agree = false;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _social, _followers, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      _snack('وافقوا على شروط البرنامج أول');
      return;
    }
    setState(() => _sending = true);
    try {
      await InfluencerService.apply(
        name: _name.text,
        phone: ShopApi.normalizePhone(_phone.text) ?? _phone.text,
        socialUrl: _social.text,
        followers: int.tryParse(_followers.text.replaceAll(RegExp(r'[^0-9]'), '')),
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(ShopApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('انضموا كمؤثرين')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Text(
              'شاركوا كودكم ويه متابعينكم: الزبونة تاخذ خصم على أول طلب، وإنتو تاخذون عمولة على كل زبونة جديدة يكتمل طلبها.',
              style: TextStyle(fontSize: 14, height: 1.6, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: _dec('الاسم'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').trim().length < 2 ? 'اكتبوا الاسم' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: _dec('رقم الهاتف', hint: '07XXXXXXXXX'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) => ShopApi.normalizePhone(v ?? '') == null ? 'رقم الهاتف غير صحيح' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _social,
              decoration: _dec('رابط حسابكم (انستغرام أو تيك توك)', hint: 'https://instagram.com/...'),
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').trim().length < 5 ? 'اكتبوا رابط الحساب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _followers,
              decoration: _dec('عدد المتابعين تقريباً'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: _dec('ملاحظة (اختياري)'),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
              child: Text(
                'شروط البرنامج:\n'
                '• العمولة على أول طلب مكتمل لكل زبونة جديدة استعملت كودكم، ومو على طلبات رقمكم.\n'
                '• الطلب الملغي ما تنحسب عمولته.\n'
                '• نسلّمكم الرصيد المتوفر يدوياً، ونگدر نوقف الكود إذا صار استعمال غير صحيح.\n'
                '• لازم يكون العمر 18 سنة أو أكثر.',
                style: TextStyle(fontSize: 12.5, height: 1.7, color: cs.onSurfaceVariant),
              ),
            ),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.brand,
              title: const Text('أوافق على شروط البرنامج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand, minimumSize: const Size.fromHeight(50)),
              child: Text(_sending ? 'جاري الإرسال...' : 'أرسلوا الطلب', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
