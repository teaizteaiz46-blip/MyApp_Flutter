import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../home/promo_link.dart';

/// شاشة إعلان الافتتاح: صورة كاملة، عدّاد "تخطي"، وزر يفتح العرض.
class SplashAdScreen extends StatefulWidget {
  const SplashAdScreen({
    super.key,
    required this.ad,
    required this.imageFile,
    required this.onClose,
    required this.onOpen,
  });

  final Map<String, dynamic> ad;
  final File imageFile;
  final VoidCallback onClose;
  final ValueChanged<Widget> onOpen;

  @override
  State<SplashAdScreen> createState() => _SplashAdScreenState();
}

class _SplashAdScreenState extends State<SplashAdScreen> with SingleTickerProviderStateMixin {
  late final int _seconds = ((widget.ad['duration_sec'] as num?)?.toInt() ?? 3).clamp(2, 8);
  late final AnimationController _progress = AnimationController(vsync: this, duration: Duration(seconds: _seconds))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onClose();
    })
    ..forward();

  late final Widget? _target = promoTarget(
    '${widget.ad['link_type'] ?? 'none'}',
    widget.ad['link_value']?.toString(),
    source: 'splash',
  );

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final buttonText = '${widget.ad['button_text'] ?? ''}'.trim();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: _target == null ? null : () => widget.onOpen(_target),
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      top: pad.top + 8,
                      left: 16,
                      right: 16,
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (_, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 3,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: pad.top + 20,
                      end: 16,
                      child: Material(
                        color: Colors.black45,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: widget.onClose,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, _) {
                                final left = (_seconds - (_progress.value * _seconds)).ceil().clamp(1, _seconds);
                                return Text(
                                  'تخطي ($left)',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_target != null && buttonText.isNotEmpty)
                      Positioned(
                        left: 28,
                        right: 28,
                        bottom: 24,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                            elevation: 4,
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          onPressed: () => widget.onOpen(_target),
                          child: Text(buttonText),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(16, 16, 16, pad.bottom + 16),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MODO',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.brand, letterSpacing: 2),
                    ),
                    Text('متجر الأناقة', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
