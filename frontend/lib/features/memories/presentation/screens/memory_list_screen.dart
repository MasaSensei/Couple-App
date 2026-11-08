import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../../photo_booth/presentation/open_photo_booth.dart';
import '../../data/models/memory_model.dart';
import '../../providers/memory_providers.dart';
import '../../providers/memory_state.dart';
import '../widgets/memory_card.dart';
import '../widgets/memory_protection_card.dart';
import 'memory_detail_screen.dart';

import 'package:go_router/go_router.dart';

class MemoryListScreen extends ConsumerStatefulWidget {
  const MemoryListScreen({super.key});

  @override
  ConsumerState<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends ConsumerState<MemoryListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    Future.microtask(
      () => ref.read(memoryNotifierProvider.notifier).loadTimeline(),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();

    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  void _loadNextPage() {
    final state = ref.read(memoryNotifierProvider);

    if (state.status == MemoryStatus.loading) {
      return;
    }

    if (!state.hasMore) {
      return;
    }

    ref
        .read(memoryNotifierProvider.notifier)
        .loadTimeline(page: state.currentPage + 1);
  }

  Future<void> _refresh() async {
    await ref.read(memoryNotifierProvider.notifier).loadTimeline();
  }

  Future<void> _create() async {
    final result = await context.push('/memories/create');
    if (!mounted) return;
    if (result != null) {
      await ref.read(memoryNotifierProvider.notifier).loadTimeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryNotifierProvider);

    return AppScaffold(
      decorated: true,
      padded: false,
      appBar: AppBar(
        title: const Text('Our memories'),
        actions: [
          IconButton(
            tooltip: 'Photo Booth',
            icon: const Icon(Icons.photo_camera_back_outlined),
            onPressed: () => openPhotoBooth(context, ref),
          ),
          IconButton(
            tooltip: 'Memory protection',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => showMemoryProtectionSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New memory'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(MemoryState state) {
    switch (state.status) {
      case MemoryStatus.initial:
      case MemoryStatus.loading:
        if (state.memories.isEmpty) return const AppStateView.loading();
        return _buildList(state);

      case MemoryStatus.empty:
        return RefreshIndicator(
          onRefresh: _refresh,
          child: AppStateView.empty(
            title: 'No memories yet',
            message: 'Your little moments together will appear here.',
            actionLabel: 'Add your first memory',
            onAction: _create,
            illustration: SpotKind.camera,
            scrollable: true,
          ),
        );

      case MemoryStatus.error:
        if (state.memories.isNotEmpty) return _buildList(state);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: AppStateView.error(
            message: state.errorMessage ?? 'We could not load your memories.',
            onAction: _refresh,
            scrollable: true,
          ),
        );

      case MemoryStatus.loaded:
        return _buildList(state);
    }
  }

  /// Flat item list: month headers interleaved with memories, so the list
  /// stays lazily built (only visible covers are decrypted).
  List<Object> _items(List<MemoryModel> memories) {
    final items = <Object>[];
    String? month;
    for (final m in memories) {
      final label = AppFormatters.monthYear(m.memoryDate);
      if (label != month) {
        items.add(label);
        month = label;
      }
      items.add(m);
    }
    return items;
  }

  Widget _buildList(MemoryState state) {
    final t = context.tokens;
    final items = _items(state.memories);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          96,
        ),
        itemCount: items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: AppLoading(size: 24)),
            );
          }

          final item = items[index];
          if (item is String) {
            final parts = item.split(' ');
            return Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? AppSpacing.sm : AppSpacing.xl,
                bottom: AppSpacing.md,
              ),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: parts.first,
                              style: t.title.copyWith(fontSize: 24),
                            ),
                            TextSpan(text: '  ${parts.last}', style: t.caption),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(child: Divider(color: t.border)),
                  ],
                ),
              ),
            );
          }

          final memory = item as MemoryModel;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: MemoryCard(
              memory: memory,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemoryDetailScreen(memory: memory),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
