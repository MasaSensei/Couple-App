import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_dependencies.dart';
import '../data/repositories/couple_invitation_repository.dart';
import 'couple_invitation_notifier.dart';
import 'couple_invitation_state.dart';

final coupleInvitationRepositoryProvider = Provider<CoupleInvitationRepository>(
  (ref) {
    return CoupleInvitationRepository(ref.watch(apiClientProvider));
  },
);

final coupleInvitationNotifierProvider =
    NotifierProvider<CoupleInvitationNotifier, CoupleInvitationState>(
      CoupleInvitationNotifier.new,
    );
