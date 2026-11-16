import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return Scaffold(
      backgroundColor: m.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 100,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 24),
              Text(
                "لا يوجد اتصال بالإنترنت",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: m.pick(Colors.black87, m.ink),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "يرجى التحقق من الاتصال بالشبكة وإعادة المحاولة لتتمكن من تصفح المنتجات.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: m.grey,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    "إعادة المحاولة 🔄",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}