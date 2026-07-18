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
                child: SelectionArea( // يتيح تحديد وتحديد النصوص لمستخدمي الويب
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سياسة الخصوصية لتطبيق جي جي (GG)',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'تاريخ آخر تحديث: 22 أكتوبر 2025',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Divider(height: 32),

                      _SectionTitle('1. مقدمة'),
                      _SectionBody(
                          'أهلاً بك في تطبيق جي جي - GG ("التطبيق"). نحن نقدر ثقتك بنا ونلتزم بحماية خصوصيتك. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية المعلومات التي قد تقدمها أثناء استخدامك للتطبيق. استخدامك للتطبيق يعني موافقتك على الممارسات الموضحة في هذه السياسة.'
                      ),

                      _SectionTitle('2. البيانات التي نجمعها'),
                      _SectionBody(
                          'نقوم بجمع الأنواع التالية من المعلومات:\n\n'
                              '• معلومات الحساب (عند التسجيل الاختياري):\n'
                              '  - البريد الإلكتروني.\n'
                              '  - كلمة المرور .\n'
                              '  - معرف المستخدم الفريد (User ID) المقدم من Supabase.\n\n'
                              '• معلومات الطلب (عند إتمام الشراء كزائر أو مستخدم مسجل):\n'
                              '  - الاسم الكامل ورقم الهاتف وعنوان التوصيل وتفاصيل المنتجات.\n\n'
                              '• معلومات السلة:\n'
                              '  - للزوار: يتم تخزينها محلياً على جهازك بواسطة shared_preferences.\n'
                              '  - للمستخدمين المسجلين: يتم تخزينها في قاعدة بيانات Supabase.\n\n'
                              '• بيانات الاستخدام:\n'
                              '  - قد تقوم Supabase بجمع بيانات تشغيلية أساسية (عنوان IP، سجلات الخادم) لأغراض الأمان وتحليل الأداء.'
                      ),

                      _SectionTitle('3. كيف نستخدم بياناتك'),
                      _SectionBody(
                          '• إنشاء وإدارة حسابك.\n'
                              '• معالجة طلبات الشراء وتوصيل المنتجات إليك.\n'
                              '• إدارة وحفظ محتويات سلة التسوق الخاصة بك.\n'
                              '• التواصل معك بشأن طلباتك أو استفساراتك.\n'
                              '• تحسين تجربة استخدام التطبيق والخدمات المقدمة.'
                      ),

                      _SectionTitle('4. مشاركة البيانات'),
                      _SectionBody(
                          'نحن لا نبيع بياناتك الشخصية لأطراف ثالثة. تتم مشاركة بياناتك فقط في الحالات التالية:\n'
                              '• مع Supabase كمزود للبنية التحتية.\n'
                              '• مع شركات التوصيل لغرض توصيل طلبك بنجاح.\n'
                              '• الامتثال القانوني إذا طُلب منا ذلك بموجب القانون.'
                      ),

                      _SectionTitle('5. تخزين وأمان البيانات'),
                      _SectionBody(
                          'نحن نتخذ الإجراءات اللازمة لحماية بياناتك. يتم تخزين بيانات المستخدمين والطلبات على خوادم Supabase المؤمنة. بيانات سلة الزائر يتم تخزينها محلياً على جهازك.'
                      ),

                      _SectionTitle('6. حقوق المستخدم'),
                      _SectionBody(
                          '• الوصول والتعديل: يمكنك تعديل معلومات حسابك من خلال التطبيق.\n'
                              '• الحذف: يمكنك طلب حذف حسابك وبياناتك عبر التواصل معنا على البريد الإلكتروني.\n'
                              '• إدارة بيانات السلة المحلية: يمكنك مسحها من إعدادات جهازك.'
                      ),

                      _SectionTitle('7. خصوصية الأطفال'),
                      _SectionBody(
                          'تطبيق جي جي (GG) غير موجه للأطفال دون سن 13 عاماً. نحن لا نجمع عن قصد أي معلومات شخصية من الأطفال.'
                      ),

                      _SectionTitle('8. التغييرات على سياسة الخصوصية'),
                      _SectionBody(
                          'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سيتم نشر أي تغييرات على هذه الصفحة مع تحديث تاريخ التحديث.'
                      ),

                      _SectionTitle('9. معلومات الاتصال'),
                      _SectionBody(
                          'إذا كانت لديك أي أسئلة أو استفسارات، يرجى التواصل معنا عبر البريد الإلكتروني:\n'
                              'velin.iraq@gmail.com'
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