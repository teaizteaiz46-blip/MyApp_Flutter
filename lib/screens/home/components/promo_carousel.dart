import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/modo_product_card.dart' show ProductImage;

/// شريحة واحدة من جدول البانرات (active_banners).
class BannerSlide {
  const BannerSlide({required this.image, required this.color, required this.row});

  final String image;
  final Color color;
  final Map<String, dynamic> row;

  String? get linkType => row['link_type']?.toString();
  String? get linkValue => row['link_value']?.toString();
}

Color parseHexColor(String? hex, {Color fallback = AppColors.brandSoft}) {
  final v = (hex ?? '').replaceAll('#', '').trim();
  if (v.length == 6) {
    final n = int.tryParse(v, radix: 16);
    if (n != null) return Color(0xFF000000 | n);
  }
  return fallback;
}

List<BannerSlide> slidesFromRows(List<Map<String, dynamic>> rows) {
  final out = <BannerSlide>[];
  for (final row in rows) {
    final color = parseHexColor(row['bg_color']?.toString());
    for (final key in const ['image_url', 'image2_url']) {
      final url = (row[key] ?? '').toString().trim();
      if (url.isNotEmpty) out.add(BannerSlide(image: url, color: color, row: row));
    }
  }
  return out;
}

/// سلايدر البانرات بعرض الشاشة. يبلّغ الصفحة بلون الشريحة الحالية حتى يتلوّن الرأس.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({
    super.key,
    required this.slides,
    required this.onSlideTap,
    required this.onColorChanged,
  });

  final List<BannerSlide> slides;
  final void Function(BannerSlide slide) onSlideTap;
  final ValueChanged<Color> onColorChanged;

  static const double aspectRatio = 2.1;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides != widget.slides) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (widget.slides.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onColorChanged(widget.slides[_page < widget.slides.length ? _page : 0].color);
      });
    }
    if (widget.slides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage(
          (_page + 1) % widget.slides.length,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: PromoCarousel.aspectRatio,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              widget.onColorChanged(slides[i].color);
            },
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => widget.onSlideTap(slides[i]),
              child: ProductImage(url: slides[i].image),
            ),
          ),
          if (slides.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: i == _page ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
