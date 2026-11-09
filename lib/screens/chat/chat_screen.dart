import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../core/offline_cache.dart';
import '../../core/shop_api.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../details/details_screen.dart';

/// دردشة الزبون ويه فريق MODO.
/// [productId]: إذا انفتحت من صفحة منتج، أول رسالة تنرسل وياها "تسألون عن" هذا المنتج.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.productId});

  final int? productId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static final NumberFormat _money = NumberFormat('#,###');
  static const _quick = ['استفسار عن طلبي', 'أريد أطلب جملة', 'سؤال عن منتج'];

  final _text = TextEditingController();
  final _messages = <ChatMessage>[];
  final _products = <int, Map<String, dynamic>>{};
  Timer? _poll;
  StreamSubscription<void>? _pushSub;
  bool _loading = true;
  bool _sending = false;
  int? _contextProduct;

  @override
  void initState() {
    super.initState();
    _contextProduct = widget.productId;
    if (_contextProduct != null) unawaited(_loadProducts([_contextProduct!]));
    ChatService.screenOpen = true;
    // إشعار "رد من MODO" اللي فتح المحادثة ما يبقى فوقها
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    });
    WidgetsBinding.instance.addObserver(this);
    _pushSub = ChatService.refreshes.listen((_) => _fetch());
    _fetch(first: true);
    _startPolling();
  }

  @override
  void dispose() {
    ChatService.screenOpen = false;
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _pushSub?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetch();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  int get _lastId => _messages.isEmpty ? 0 : _messages.last.id;

  Future<void> _fetch({bool first = false}) async {
    try {
      final fresh = await ChatService.history(after: _lastId);
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      final add = fresh.where((m) => !known.contains(m.id)).toList();
      if (add.isNotEmpty || first) {
        setState(() {
          _messages.addAll(add);
          _messages.sort((a, b) => a.id.compareTo(b.id));
          _loading = false;
        });
        final ids = add.map((m) => m.productId).whereType<int>().where((id) => !_products.containsKey(id));
        if (ids.isNotEmpty) unawaited(_loadProducts(ids));
      }
    } catch (_) {
      if (mounted && first) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts(Iterable<int> ids) async {
    try {
      final rows = await ShopApi.fetchProductsByIds(ids);
      if (mounted) setState(() => _products.addAll(rows));
    } catch (_) {}
  }

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await ChatService.send(body, productId: _contextProduct);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((x) => x.id == m.id)) _messages.add(m);
        _contextProduct = null;
        if (preset == null) _text.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(ShopApi.friendlyError(e)), backgroundColor: AppColors.sale));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('شنو المشكلة؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            for (final r in const ['رسالة مسيئة', 'إزعاج أو رسائل مزعجة', 'مشكلة ثانية'])
              ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ChatService.report(reason);
      messenger.showSnackBar(const SnackBar(content: Text('وصلنا بلاغكم، شكراً إلكم 🙏')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ShopApi.friendlyError(e))));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المحادثة'),
        content: const Text('تنمسح كل رسائل هذه المحادثة من التطبيق ومن عدنا، وما تگدرون ترجعوها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.sale),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ChatService.deleteConversation();
      if (mounted) setState(_messages.clear);
      messenger.showSnackBar(const SnackBar(content: Text('انحذفت المحادثة')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ShopApi.friendlyError(e))));
    }
  }

  void _openProduct(int id) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => DetailsScreen(productId: id, source: 'chat')));

  String? _image(Map<String, dynamic>? p, int index) {
    final list = ((p?['image_url'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return null;
    return list[(index - 1).clamp(0, list.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('راسلونا', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('فريق MODO يرد عليكم هنا', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'report' ? _report() : _delete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('إبلاغ عن مشكلة')),
              PopupMenuItem(value: 'delete', child: Text('حذف المحادثة')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _welcome()
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[_messages.length - 1 - i]),
                      ),
          ),
          if (_contextProduct != null) _contextChip(),
          _input(),
        ],
      ),
    );
  }

  Widget _welcome() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 30),
          const Center(child: Text('👋', style: TextStyle(fontSize: 44))),
          const SizedBox(height: 10),
          const Text('هلا بيكم بـ MODO',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('اكتبوا سؤالكم أو طلبكم، وفريقنا يرد عليكم هنا ويوصلكم إشعار بالرد.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q),
                  onPressed: _sending ? null : () => _send(q),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.line),
                ),
            ],
          ),
        ],
      );

  Widget _contextChip() {
    final p = _products[_contextProduct];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 4, 6),
      decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text('🛍️ '),
          Expanded(
            child: Text('تسألون عن: ${p?['name'] ?? 'منتج #$_contextProduct'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'إزالة',
            onPressed: () => setState(() => _contextProduct = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _input() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          color: AppColors.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'اكتبوا رسالتكم...',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'إرسال',
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white),
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, textDirection: TextDirection.rtl),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(ChatMessage m) {
    final time = TimeOfDay.fromDateTime(m.createdAt).format(context);
    final p = m.productId == null ? null : _products[m.productId];

    if (m.isProductCard) {
      final img = _image(p, m.imageIndex);
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          onTap: () => _openProduct(m.productId!),
          child: Container(
            width: 230,
            margin: const EdgeInsets.symmetric(vertical: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: img == null
                      ? const ColoredBox(color: AppColors.placeholder)
                      : Image(
                          image: cachedImage(img, decodeWidth: decodeWidthFor(context, 230, 230)),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.placeholder),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((p?['name'] ?? '...').toString(),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (p?['price'] != null)
                        Text('${_money.format(p!['price'])} د.ع',
                            style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('شوفوا المنتج', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text(time, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: m.mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: m.mine ? AppColors.brand : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: m.mine ? null : Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.mine && m.productId != null)
                GestureDetector(
                  onTap: () => _openProduct(m.productId!),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('🛍️ عن: ${p?['name'] ?? 'منتج #${m.productId}'}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              Text(m.body, style: TextStyle(color: m.mine ? Colors.white : AppColors.ink, height: 1.45)),
              const SizedBox(height: 2),
              Text(time, style: TextStyle(fontSize: 10.5, color: m.mine ? Colors.white70 : AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
