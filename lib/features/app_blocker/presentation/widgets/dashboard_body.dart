import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/content_width.dart';
import 'package:unspend/shared/providers/locale_provider.dart';

import '../../domain/entities/blocker_profile.dart';
import '../profile_actions.dart';
import 'authorization_banner.dart';
import 'profile_card.dart';
import 'settings_sheet.dart';
import 'summary_card.dart';

/// The dashboard's scrolling content: header, permission banner, summary
/// and the list of profiles.
class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, required this.profiles});

  final List<BlockerProfile> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Strings are read from a global; rebuild when the language changes.
    ref.watch(localeProvider);
    final s = S.current;
    final activeCount = profiles.where((p) => p.isActive).length;

    return ContentGutter(
      builder: (context, gutter) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: kAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          s.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: kTextPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: s.settings,
                      onPressed: () => showSettingsSheet(context),
                      icon: Icon(
                        Icons.settings_rounded,
                        color: kTextSecondary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const AuthorizationBanner(),
                SummaryCard(
                  totalProfiles: profiles.length,
                  activeCount: activeCount,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          s.profilesSectionTitle,
                          style: TextStyle(
                            color: kTextPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${profiles.length}',
                      style: TextStyle(color: kTextSecondary, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (profiles.isEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 32),
              sliver: const SliverToBoxAdapter(child: _EmptyState()),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.separated(
                itemCount: profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return ProfileCard(
                    key: ValueKey(profile.id),
                    profile: profile,
                    onTap: () => context.push(AppRoutes.profile(profile.id)),
                    onToggle: () => profile.isActive
                        ? deactivateWithGate(context, ref, profile.id)
                        : activateWithFeedback(context, ref, profile),
                  );
                },
              ),
            ),
          // Room for the floating "new profile" button.
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.add_circle_outline_rounded, color: kBorder, size: 64),
        const SizedBox(height: 16),
        Text(
          S.current.noProfilesYet,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kTextSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.current.noProfilesTapPlus,
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
