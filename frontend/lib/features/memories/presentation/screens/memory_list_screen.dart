import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/memory_providers.dart';
import '../../providers/memory_state.dart';
import '../widgets/memory_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Our Memories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/memories/create');

          if (!mounted) {
            return;
          }

          if (result != null) {
            await ref.read(memoryNotifierProvider.notifier).loadTimeline();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(MemoryState state) {
    switch (state.status) {
      case MemoryStatus.initial:
      case MemoryStatus.loading:
        if (state.memories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildList(state);

      case MemoryStatus.empty:
        return _buildEmptyState();

      case MemoryStatus.error:
        return _buildErrorState(state.errorMessage);

      case MemoryStatus.loaded:
        return _buildList(state);
    }
  }

  Widget _buildList(MemoryState state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.memories.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.memories.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final memory = state.memories[index];

          return MemoryCard(
            memory: memory,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemoryDetailScreen(memory: memory),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'No memories yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your little moments together '
                      'will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? 'Unable to load memories.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
