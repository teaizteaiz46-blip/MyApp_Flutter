import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // <-- 1. استيراد الحزمة الجديدة
import '../../main.dart'; // لاستخدام supabase
import 'video_clip_player.dart'; // لاستخدام المشغل

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  final List<Map<String, dynamic>> _clips = [];
  final PageController _pageController = PageController();

  // <-- 2. إنشاء "بذرة" عشوائية فريدة لهذه الجلسة
  final String _sessionSeed = Uuid().v4();

  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 2; // عدد المقاطع في كل دفعة

  @override
  void initState() {
    super.initState();
    _fetchMoreClips();

    _pageController.addListener(() {
      if (_pageController.page != null &&
          _pageController.page! >= (_clips.length - 3) &&
          !_isLoading &&
          _hasMore) {
        //print(
        //    "Reached clip ${_pageController.page!.round() + 1}, fetching more...");
        _fetchMoreClips();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 3. دالة جلب البيانات (المعدلة لاستخدام الـ RPC)
  Future<void> _fetchMoreClips() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // حساب الـ offset
      final int offset = _currentPage * _pageSize;

      // <-- 4. استدعاء الدالة الجديدة (RPC) بدلاً من .select()
      final response = await supabase.rpc(
        'get_shuffled_clips', // <-- !! اسم الدالة الجديدة
        params: {
          'seed_text': _sessionSeed,   // <-- تمرير البذرة العشوائية
          'limit_count': _pageSize,
          'offset_count': offset,
        },
      );

      // الكود الباقي لتحويل البيانات وتحديث الحالة يبقى كما هو
      final List<Map<String, dynamic>> newClips = (response as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();

      setState(() {
        _isLoading = false;
        _clips.addAll(newClips);
        _currentPage++;

        if (newClips.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (error) {
      //print('SUPABASE ERROR: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 5. بناء الواجهة (يبقى كما هو، بدون FutureBuilder)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0, backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_clips.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clips.isEmpty && !_hasMore) {
      return const Center(
          child:
          Text('لا توجد مقاطع لعرضها', style: TextStyle(color: Colors.white)));
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _clips.length,
      itemBuilder: (context, index) {
        final clip = _clips[index];

        final videoUrl = clip['video_url'];
        final productId = clip['product_id'];

        return VideoClipPlayer(
          // استخدام videoUrl كمفتاح يضمن إعادة بناء الودجت
          // عند التمرير السريع (أكثر استقراراً)
          key: ValueKey(videoUrl),
          videoUrl: videoUrl,
          productId: productId,
        );
      },
    );
  }
}