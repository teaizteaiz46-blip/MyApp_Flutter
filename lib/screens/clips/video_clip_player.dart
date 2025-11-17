import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // الحزمة موجودة بالفعل
import '../details/details_screen.dart'; // شاشة التفاصيل

class VideoClipPlayer extends StatefulWidget {
  final String videoUrl;
  final int productId;

  const VideoClipPlayer({
    super.key,
    required this.videoUrl,
    required this.productId,
  });

  @override
  State<VideoClipPlayer> createState() => _VideoClipPlayerState();
}

class _VideoClipPlayerState extends State<VideoClipPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // تهيئة متحكم الفيديو
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        // التأكد من أن الإطار الأول قد تم عرضه
        setState(() {
          _isInitialized = true;
        });
        // تشغيل الفيديو وتكراره
        _controller.play();
        _controller.setLooping(true);
        _controller.setVolume(1.0); // يمكنك ضبط الصوت
      });
  }

  @override
  void dispose() {
    // التخلص من المتحكم عند مغادرة الصفحة
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // استخدام Stack لوضع الزر فوق الفيديو
    return Stack(
      fit: StackFit.expand, // لجعل الفيديو والزر يملآن الشاشة
      children: [
        // --- 1. مشغل الفيديو ---
        if (_isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          )
        else
          const Center(child: CircularProgressIndicator()), // علامة تحميل

        // --- 2. زر "الذهاب إلى المنتج" ---
        Positioned(
          bottom: 100, // يمكنك تعديل المكان
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('الذهاب إلى المنتج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // الانتقال إلى شاشة تفاصيل المنتج
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsScreen(productId: widget.productId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}