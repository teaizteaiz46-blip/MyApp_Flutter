import 'package:flutter/material.dart';

import '../screens/chat/chat_screen.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';

/// زر "راسلونا" بالزاوية، وعليه عدد ردود الفريق الجديدة
class ChatFab extends StatefulWidget {
  const ChatFab({super.key});

  @override
  State<ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<ChatFab> {
  AppLifecycleListener? _life;

  @override
  void initState() {
    super.initState();
    ChatService.refreshUnread();
    _life = AppLifecycleListener(onResume: ChatService.refreshUnread);
  }

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    ChatService.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatService.unread,
      builder: (context, n, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton.extended(
            heroTag: 'home-chat',
            onPressed: _open,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            elevation: 3,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
            icon: const Icon(Icons.chat_bubble_rounded, size: 20),
            label: const Text('راسلونا', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (n > 0)
            PositionedDirectional(
              top: -5,
              end: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sale,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(n > 9 ? '9+' : '$n',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}
