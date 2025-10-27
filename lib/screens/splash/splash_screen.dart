import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../home/home_screen.dart'; // للانتقال إلى الشاشة الرئيسية

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    // 1. تهيئة متحكم الفيديو
    // تأكد من أن مسار الفيديو صحيح (نفس المسار في pubspec.yaml)
    _controller = VideoPlayerController.asset('assets/videos/splash_video.mp4')
      ..initialize().then((_) {
        // التأكد من أن الإطار الأول قد تم عرضه قبل التشغيل
        setState(() {});
        // تشغيل الفيديو
        _controller.play();
        // كتم الصوت (اختياري)
        _controller.setVolume(0.0);
      });

    // 2. الانتقال إلى الشاشة الرئيسية بعد مدة معينة
    _navigateToHome();
  }

  void _navigateToHome() async {
    // انتظر لمدة 5 ثوانٍ (أو مدة الفيديو الخاص بك)
    await Future.delayed(const Duration(seconds: 5));

    // الانتقال إلى الشاشة الرئيسية مع تأثير تلاشي جميل
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.pause(); // <-- أضف هذا السطر لإيقاف الفيديو
    // 3. تأكد من التخلص من المتحكم لتجنب تسريب الذاكرة
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // لون الخلفية أثناء تحميل الفيديو
      body: Center(
        child: _controller.value.isInitialized
            ?
        // 4. جعل الفيديو يملأ الشاشة بالكامل
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        )
            : Container(), // إظهار حاوية فارغة أثناء تهيئة الفيديو
      ),
    );
  }
}
