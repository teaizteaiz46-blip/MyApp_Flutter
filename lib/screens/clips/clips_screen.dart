import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase
import 'video_clip_player.dart'; // لاستخدام المشغل

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  late Future<List<Map<String, dynamic>>> _clipsFuture;

  @override
  void initState() {
    super.initState();
    _clipsFuture = _fetchClips();
  }

  // دالة جلب الرييلز من Supabase
  Future<List<Map<String, dynamic>>> _fetchClips() {
    return supabase
        .from('clips')
        .select('video_url, product_id') // جلب البيانات المطلوبة فقط
        .order('created_at', ascending: false); // عرض الأحدث أولاً
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // إخفاء شريط العنوان
      appBar: AppBar(toolbarHeight: 0, backgroundColor: Colors.black),
      backgroundColor: Colors.black, // خلفية سوداء
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _clipsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('خطأ في جلب الفيديوهات', style: TextStyle(color: Colors.white)));
          }

          final clips = snapshot.data;
          if (clips == null || clips.isEmpty) {
            return const Center(child: Text('لا توجد فيديوهات حاليًا.', style: TextStyle(color: Colors.white)));
          }

          // --- بناء الواجهة القابلة للتمرير ---
          return PageView.builder(
            scrollDirection: Axis.vertical, // التمرير عمودي
            itemCount: clips.length,
            itemBuilder: (context, index) {
              final clip = clips[index];
              // استخدام الويدجت الذي أنشأناه لكل فيديو
              return VideoClipPlayer(
                videoUrl: clip['video_url'],
                productId: clip['product_id'],
              );
            },
          );
        },
      ),
    );
  }
}