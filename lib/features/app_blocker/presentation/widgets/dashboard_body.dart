import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';
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
    final colors = context.colors;
    final text = context.text;
    final activeCount = profiles.where((p) => p.isActive).length;

    return ContentGutter(
      builder: (context, gutter) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: colors.accent,
                      size: AppSizes.iconXl,
                    ),
                    Gap.hSm,
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          s.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.screenTitle,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: s.settings,
                      onPressed: () => showSettingsSheet(context),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ],
                ),
                Gap.vMd,
                const AuthorizationBanner(),
                SummaryCard(
                  totalProfiles: profiles.length,
                  activeCount: activeCount,
                ),
                Gap.vXl,
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          s.profilesSectionTitle,
                          style: text.heading,
                        ),
                      ),
                    ),
                    Text(
                      '${profiles.length}',
                      style: text.body.tone(colors.textSecondary),
                    ),
                  ],
                ),
                Gap.vMd,
              ],
            ),
          ),
          if (profiles.isEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: gutter,
                vertical: AppSpacing.xxxl,
              ),
              sliver: const SliverToBoxAdapter(child: _EmptyState()),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.separated(
                itemCount: profiles.length,
                separatorBuilder: (_, _) => Gap.vMd,
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
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSizes.floatingButtonClearance),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Column(
      children: [
        Icon(
          Icons.add_circle_outline_rounded,
          color: colors.border,
          size: AppSizes.iconIllustration,
        ),
        Gap.vLg,
        Text(
          S.current.noProfilesYet,
          textAlign: TextAlign.center,
          style: text.subheading.tone(colors.textSecondary),
        ),
        Gap.vXs,
        Text(
          S.current.noProfilesTapPlus,
          textAlign: TextAlign.center,
          style: text.bodySmall.tone(colors.textSecondary),
        ),
      ],
    );
  }
}
