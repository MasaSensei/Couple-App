import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_dependencies.dart';
import '../data/repositories/couple_repository.dart';
import 'couple_notifier.dart';
import 'couple_state.dart';

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  return CoupleRepository(ref.watch(apiClientProvider));
});

final coupleNotifierProvider = NotifierProvider<CoupleNotifier, CoupleState>(
  CoupleNotifier.new,
);
