import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/chat.dart';
import '../data/chat_repository.dart';
import 'chat_thread_screen.dart';

/// Pick a farmer to start a new conversation with.
class FindFarmersScreen extends ConsumerStatefulWidget {
  const FindFarmersScreen({super.key});

  @override
  ConsumerState<FindFarmersScreen> createState() => _FindFarmersScreenState();
}

class _FindFarmersScreenState extends ConsumerState<FindFarmersScreen> {
  final _search = TextEditingController();
  late Future<List<Farmer>> _future;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(chatRepositoryProvider).searchFarmers('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _query(String q) {
    setState(() => _future = ref.read(chatRepositoryProvider).searchFarmers(q));
  }

  Future<void> _start(Farmer f) async {
    if (_starting) return;
    setState(() => _starting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final threadId = await ref.read(chatRepositoryProvider).startChat(f.id);
      if (!mounted) return;
      navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          threadId: threadId,
          otherName: f.name,
          otherAvatar: f.avatar,
        ),
      ));
    } catch (e) {
      setState(() => _starting = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: _query,
              decoration: InputDecoration(
                hintText: 'Search farmers by name…',
                prefixIcon: const Icon(Symbols.search),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Farmer>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load farmers.', style: AppText.labelSm),
                    ),
                  );
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Symbols.person_search,
                              size: 48, color: AppColors.outline),
                          const SizedBox(height: 10),
                          Text('No other farmers found', style: AppText.labelMd),
                          const SizedBox(height: 4),
                          Text('Once more farmers join, they\'ll show up here.',
                              textAlign: TextAlign.center,
                              style: AppText.labelSm),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = list[i];
                    return ListTile(
                      leading: _Avatar(name: f.name, url: f.avatar),
                      title: Row(
                        children: [
                          Flexible(
                              child: Text(f.name,
                                  style: AppText.labelMd,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (f.isExpert) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Expert',
                                  style: AppText.labelSm.copyWith(
                                      color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(Symbols.chat, size: 20),
                      onTap: () => _start(f),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.startsWith('http')) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(url!));
    }
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryContainer,
      child: Text(initials.toUpperCase(),
          style: AppText.labelMd.copyWith(color: Colors.white)),
    );
  }
}
