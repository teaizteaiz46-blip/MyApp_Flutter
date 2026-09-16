import 'dart:convert';
import 'package:http/http.dart' as http;

class TryOnService {
  // 🔑 المفتاح الخاص بك من Replicate
  static const String _apiKey = '';

  static Future<String?> processVirtualTryOn({
    required String userImageUrl,
    required String garmentImageUrl,
  }) async {
    // 📍 استخدام المسار المباشر للنموذج yisol/idm-vton
    final url = Uri.parse('https://api.replicate.com/v1/models/yisol/idm-vton/predictions');

    try {
      // 1. بدء عملية المعالجة بدون إرسال حقل version
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'input': {
            'human_img': userImageUrl,
            'garm_img': garmentImageUrl,
            'category': 'upper_body', // الحجاب والقطع العلوية
            'garment_des': 'Hijab headscarf and modest clothing', // توجيه الذكاء الاصطناعي
            'crop': false,
            'seed': 42,
          },
        }),
      );

      // استجابة البدء تكون عادةً 201 أو 200
      if (response.statusCode != 201 && response.statusCode != 200) {
        print("❌ Error starting Try-On: ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);

      // في حال اكتمال المعالجة فوراً
      if (data['status'] == 'succeeded' && data['output'] != null) {
        print("✅ Success generating image!");
        return data['output'] is List ? data['output'][0] : data['output'];
      }

      // جلب رابط التتبع
      String? getUrl = data['urls']?['get'];
      if (getUrl == null) {
        print("❌ Failed to get status URL");
        return null;
      }

      // 2. حلقة التكرار لمتابعة جاهزية الصورة (Polling)
      while (true) {
        await Future.delayed(const Duration(seconds: 4)); // انتظار 4 ثوانٍ لتفادي Rate Limit

        final checkResponse = await http.get(
          Uri.parse(getUrl),
          headers: {
            'Authorization': 'Token $_apiKey',
          },
        );

        final checkData = jsonDecode(checkResponse.body);
        String status = checkData['status'];

        if (status == 'succeeded') {
          print("✅ Success generating image!");
          if (checkData['output'] is List) {
            return checkData['output'][0];
          }
          return checkData['output'];
        } else if (status == 'failed' || status == 'canceled') {
          print("❌ Processing failed or canceled: ${checkData['error']}");
          return null;
        }
      }
    } catch (e) {
      print("❌ Exception processing Try-On: $e");
      return null;
    }
  }
}