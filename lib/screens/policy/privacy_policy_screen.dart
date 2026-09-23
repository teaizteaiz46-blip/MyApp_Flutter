import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('سياسة الخصوصية', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Container(
          width: 900, // لتنسيق النص بشكل أنيق على شاشات الويب العريضة
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: SingleChildScrollView(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: SelectionArea( // يتيح تحديد ونسخ النص على الويب
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سياسة الخصوصية لتطبيق مودو (Modo)',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'تاريخ آخر تحديث: 24 أيلول 2026',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Divider(height: 32),

                      _SectionBody(
                          'أهلاً بك في تطبيق مودو - MODO ("التطبيق"). نلتزم بحماية خصوصيتك. توضح هذه السياسة المعلومات التي نجمعها، وكيف نستخدمها ونحميها، وخياراتك بخصوصها. استخدامك للتطبيق يعني موافقتك على ما ورد فيها.'
                      ),

                      _SectionTitle('1. البيانات التي نجمعها'),
                      _SectionBody(
                          '• معلومات الحساب (إذا سجّلت، والتسجيل اختياري): البريد الإلكتروني وكلمة المرور ومعرّف المستخدم.\n'
                              '• معلومات الطلب (عند الشراء كزائر أو مستخدم مسجّل): الاسم ورقم الهاتف والمحافظة وعنوان التوصيل والمنتجات المطلوبة وكود الخصم إن وُجد.\n'
                              '• سلة التسوق والبيانات المحفوظة على جهازك: السلة، ومعلومات التوصيل التي أدخلتها سابقاً لتسهيل الطلب القادم، ونسخة مؤقتة من صور ومعلومات المنتجات لتسريع فتح التطبيق. تبقى هذه البيانات على جهازك.\n'
                              '• بيانات الاستخدام والأحداث: مثل مشاهدة منتج، أو الإضافة إلى السلة، أو بدء الطلب، أو إتمام الشراء، مع رقم المنتج والسعر.\n'
                              '• معلومات الجهاز: نوع الجهاز ونظام التشغيل وإصدار التطبيق وعنوان IP، ومعرّف الإعلانات (Advertising ID على أندرويد و IDFA على آيفون) فقط إذا سمحت بذلك.\n'
                              '• رمز الإشعارات: لإرسال إشعارات العروض والطلبات إذا وافقت على الإشعارات.'
                      ),

                      _SectionTitle('2. كيف نستخدم بياناتك'),
                      _SectionBody(
                          '• معالجة طلباتك وتوصيلها والتواصل معك بخصوصها.\n'
                              '• إنشاء حسابك وإدارته وحفظ سلتك.\n'
                              '• إرسال إشعارات عن الطلبات والعروض (يمكنك إيقافها من إعدادات جهازك).\n'
                              '• قياس أداء إعلاناتنا وتحسينها، وعرض منتجات قد تهمك على منصات مثل فيسبوك وانستغرام وتيك توك.\n'
                              '• تحسين التطبيق وحمايته من الاحتيال والاستخدام غير المشروع.'
                      ),

                      _SectionTitle('3. الخدمات الخارجية ومشاركة البيانات'),
                      _SectionBody(
                          'نحن لا نبيع بياناتك الشخصية. نشارك البيانات فقط مع الجهات التالية وللأغراض المذكورة:\n'
                              '• Supabase: استضافة قاعدة البيانات والحسابات والطلبات.\n'
                              '• Meta (فيسبوك وانستغرام): عبر أداة Meta SDK نرسل أحداث الاستخدام المذكورة أعلاه مع معلومات الجهاز، لقياس الإعلانات وعرض منتجات مناسبة لك.\n'
                              '• TikTok: عبر أداة TikTok Events SDK للغرض نفسه.\n'
                              '• Google Firebase: لإرسال الإشعارات.\n'
                              '• شركات التوصيل: الاسم والهاتف والعنوان فقط، لتوصيل طلبك.\n'
                              '• الجهات الرسمية: إذا طُلب منا ذلك بموجب القانون.'
                      ),

                      _SectionTitle('4. التتبع وخياراتك'),
                      _SectionBody(
                          '• على آيفون: يطلب التطبيق إذنك قبل استخدام معرّف الإعلانات (App Tracking Transparency). إذا رفضت، لا نستخدم المعرّف للتتبع، ويبقى التطبيق يعمل بشكل كامل. يمكنك تغيير اختيارك من: الإعدادات ← الخصوصية والأمان ← التتبع.\n'
                              '• على أندرويد: يمكنك حذف أو إيقاف معرّف الإعلانات من: الإعدادات ← Google ← الإعلانات.\n'
                              '• الإشعارات: يمكنك إيقافها في أي وقت من إعدادات التطبيق في جهازك.'
                      ),

                      _SectionTitle('5. تخزين البيانات وأمانها'),
                      _SectionBody(
                          'تُخزَّن بيانات الحسابات والطلبات على خوادم Supabase المؤمّنة، ويُتاح الوصول إليها لفريق MODO فقط لإدارة الطلبات. نحتفظ ببيانات الطلبات للمدة اللازمة لإتمامها ولأغراض المحاسبة وخدمة الزبائن.'
                      ),

                      _SectionTitle('6. حقوقك وحذف بياناتك'),
                      _SectionBody(
                          '• تعديل معلومات حسابك من داخل التطبيق.\n'
                              '• حذف حسابك وبياناتك نهائياً من: حسابي ← حذف الحساب نهائياً. وإذا طلبت كزائر بدون حساب، راسلنا على البريد أدناه ونحذف بياناتك خلال 30 يوماً.\n'
                              '• مسح السلة والبيانات المحفوظة على جهازك بحذف التطبيق أو مسح بياناته من إعدادات الجهاز.'
                      ),

                      _SectionTitle('7. خصوصية الأطفال'),
                      _SectionBody(
                          'التطبيق غير موجّه للأطفال دون 13 عاماً، ولا نجمع عن قصد معلومات شخصية منهم.'
                      ),

                      _SectionTitle('8. التغييرات على هذه السياسة'),
                      _SectionBody(
                          'قد نحدّث هذه السياسة من وقت لآخر، ونعدّل تاريخ التحديث أعلاه عند أي تغيير.'
                      ),

                      _SectionTitle('9. التواصل معنا'),
                      _SectionBody(
                          'لأي سؤال عن خصوصيتك أو بياناتك:\n'
                              'velin.iraq@gmail.com\n\n'
                              'النسخة الكاملة على الويب:\n'
                              'teaizteaiz46-blip.github.io/Modo-orders/privacy.html'
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
    );
  }
}