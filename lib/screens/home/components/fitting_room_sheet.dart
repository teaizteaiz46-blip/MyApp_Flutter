import 'package:flutter/material.dart';
import '../../../services/try_on_service.dart';

class FittingRoomBottomSheet extends StatefulWidget {
  final String garmentImageUrl;

  const FittingRoomBottomSheet({super.key, required this.garmentImageUrl});

  @override
  State<FittingRoomBottomSheet> createState() => _FittingRoomBottomSheetState();
}

class _FittingRoomBottomSheetState extends State<FittingRoomBottomSheet> {
  // 📍 1. حفظ رابط صورة الموديل الأصلية
  final String basePersonImage = 'https://pajxormplmloivyankji.supabase.co/storage/v1/object/public/hijabat/IMG_2745.JPEG';

  // الصورة المعروضة حالياً (تتغير بعد المعالجة)
  late String currentPersonImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentPersonImage = basePersonImage;
  }

  void _runTryOn() async {
    setState(() => isLoading = true);

    // 📍 2. نرسل دائماً صورة الموديل الأصلية لضمان دقة الذكاء الاصطناعي
    final result = await TryOnService.processVirtualTryOn(
      userImageUrl: basePersonImage,
      garmentImageUrl: widget.garmentImageUrl,
    );

    if (result != null) {
      setState(() {
        currentPersonImage = result;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر معالجة الصورة، حاول مجدداً')),
        );
      }
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "غرفة القياس الافتراضية 👗",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    currentPersonImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                if (isLoading)
                  Container(
                    color: Colors.black54,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepOrange),
                        SizedBox(height: 12),
                        Text(
                          "جاري تجربة الحجاب عليك...",
                          style: TextStyle(color: Colors.white),
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: isLoading ? null : _runTryOn,
            icon: const Icon(Icons.checkroom, color: Colors.white),
            label: const Text(
              "تجربة القطعة الآن",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }
}