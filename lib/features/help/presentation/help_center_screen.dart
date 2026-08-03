import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Help Center — how-to guides, an FAQ, and a route into the feedback form.
/// Content is bundled (works offline) and bilingual via the string helper.
class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final so = ref.watch(stringsProvider).isSo;

    final guides = <(IconData, String, String)>[
      (Symbols.dashboard,
          so ? 'Dashboard-ka' : 'Dashboard',
          so
              ? 'Beertaada hal eegmo — faa’iido, dalagyada firfircoon iyo dhaqdhaqaaqa dhow.'
              : 'Your farm at a glance — profit, active crops and recent activity.'),
      (Symbols.receipt_long,
          so ? 'Diiwaannada' : 'Records',
          so
              ? 'Qor kharashyada, goosashada iyo iibka; tirooyinku waxay u socdaan dashboard-ka.'
              : 'Log expenses, harvests and sales; the numbers flow to the dashboard.'),
      (Symbols.groups,
          so ? 'Shaqaalaha & Hawlaha' : 'Workers & Tasks',
          so
              ? 'U qoondee hawlo, la soco imaanshaha oo diiwaangeli mushaharka.'
              : 'Assign work, track attendance and record pay.'),
      (Symbols.psychiatry,
          so ? 'Dhakhtarka Dhirta (AI)' : 'AI Plant Doctor',
          so
              ? 'Sawir caleen buka; hel cudurka iyo talooyin daawo.'
              : 'Photograph a sick leaf; get the disease and treatment advice.'),
      (Symbols.partly_cloudy_day,
          so ? 'Cimilada' : 'Weather',
          so
              ? 'Mar keliya dej goobta beerta si aad u hesho saadaal iyo digniin.'
              : 'Set your farm location once for a local forecast and advisories.'),
      (Symbols.cloud_off,
          so ? 'Shaqeeya offline' : 'Works offline',
          so
              ? 'Qor xogta iyadoon shabakad jirin — way is-waafajisaa markaad ku soo noqoto.'
              : 'Record data with no signal — it syncs when you reconnect.'),
    ];

    final faqs = <(String, String)>[
      (
        so ? 'Sideen ugu daraa beer cusub?' : 'How do I add a farm?',
        so
            ? 'Tag Farms > “Add farm”. Waxaad markaa ku dari kartaa qaybo (plots) iyo dalagyo.'
            : 'Go to Farms > “Add farm”. You can then add plots and crops inside it.',
      ),
      (
        so ? 'Maxay “AI credits” yihiin?' : 'What are AI credits?',
        so
            ? 'Qorshe kastaa wuxuu bixiyaa tiro bishii ah oo baaritaanno AI ah. Markay dhammaadaan sug bisha xigta ama kordhi qorshahaaga.'
            : 'Each plan grants a monthly number of AI actions. When they run out, wait for next month or upgrade your plan.',
      ),
      (
        so ? 'Sideen u beddelaa furaha (password)?' : 'How do I reset my password?',
        so
            ? 'Bogga gelitaanka riix “Forgot password?”, geli emailkaaga, kadibna raac linkiga lagu soo diray.'
            : 'On the sign-in screen tap “Forgot password?”, enter your email, then follow the emailed link.',
      ),
      (
        so ? 'Xogtaydu ma badbaado?' : 'Is my data safe?',
        so
            ? 'Haa. Xogta beertaadu waa gaar kuu ah oo lagama arki karo akoonno kale.'
            : 'Yes. Your farm data is private to you and isn’t visible to other accounts.',
      ),
      (
        so ? 'Sideen u noqdaa khabiir?' : 'How do I become an expert?',
        so
            ? 'Profile > “Become an Expert”, sheeg khibradaada — admin ayaa dib u eegi doona.'
            : 'Profile > “Become an Expert”, describe your background — an admin reviews it.',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(so ? 'Caawimaad' : 'Help Center'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact / feedback CTA.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Symbols.support_agent, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    so
                        ? 'Su’aal ma qabtaa ama dhibaato? Noo soo dir.'
                        : 'Have a question or a problem? Send us a message.',
                    style: AppText.bodyMd),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/feedback'),
            icon: const Icon(Symbols.feedback),
            label: Text(so ? 'Dir jawaab-celin' : 'Contact support / feedback'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 24),
          Text(so ? 'Hagitaan' : 'Guides',
              style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final g in guides) _GuideRow(icon: g.$1, title: g.$2, body: g.$3),
          const SizedBox(height: 24),
          Text('FAQ',
              style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final f in faqs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(f.$1, style: AppText.bodyMd),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(f.$2,
                        style: AppText.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: Text('Somali Farm',
                style: AppText.labelSm.copyWith(color: AppColors.outline)),
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                Text(body,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
