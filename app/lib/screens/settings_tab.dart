import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/email_utils.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final auth = context.watch<AuthProvider>();
    final themes = context.read<ThemeController>();
    final user = auth.user;
    if (user == null) return const SizedBox();

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (context.mounted) showSnack(context, e.toString());
      }
    }

    final initial = user.name.isEmpty ? '?' : user.name.substring(0, 1).toUpperCase();
    final emailTypo = checkEmailTypo(user.email);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
          children: [
            const ScreenHeader(title: 'Settings', subtitle: 'Make it yours'),

            // Official User Profile Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [p.button, p.accent]),
                          boxShadow: [
                            BoxShadow(color: p.accent.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Text(initial, style: TextStyle(color: p.onButton, fontSize: 23, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (emailTypo != null) ? Colors.amber.withOpacity(0.18) : Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (emailTypo != null) ? Colors.amber.withOpacity(0.5) : Colors.green.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        (emailTypo != null) ? Icons.warning_amber_rounded : Icons.verified,
                                        size: 12,
                                        color: (emailTypo != null) ? Colors.amber : Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (emailTypo != null) ? 'Typo Detected' : 'Official Verified',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: (emailTypo != null) ? Colors.amber : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(user.email, style: TextStyle(color: p.muted, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Prominent 1-Click Typo Fix Banner if email is mistyped
                  if (emailTypo != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withOpacity(0.45)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_fix_high, color: Colors.amber, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Email domain typo detected',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.amber),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Your current email "${user.email}" has a typo. Did you mean "$emailTypo"?',
                                  style: TextStyle(fontSize: 12, color: p.text),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              try {
                                await auth.updateProfile(email: emailTypo);
                                if (context.mounted) showSnack(context, 'Email successfully corrected to $emailTypo!');
                              } catch (e) {
                                if (context.mounted) showSnack(context, e.toString());
                              }
                            },
                            child: Text('Auto-Fix to $emailTypo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Theme Selector
            SectionCard(
              title: 'App theme',
              icon: Icons.palette_outlined,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kPalettes
                    .map((pal) => _PaletteCard(
                          palette: pal,
                          selected: pal.id == p.id,
                          onTap: () => themes.select(pal),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Language Selector
            SectionCard(
              title: 'My language',
              icon: Icons.translate,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kLanguages
                    .map((l) => ChoicePill(
                          label: l['name']!,
                          selected: user.preferredLang == l['code'],
                          onTap: () => run(() => auth.updatePrefs(lang: l['code'])),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Explanation Style
            SectionCard(
              title: 'Explanation style',
              icon: Icons.chrome_reader_mode_outlined,
              child: PillSelector<String>(
                options: const [
                  MapEntry('verySimple', 'Very simple'),
                  MapEntry('simple', 'Simple'),
                  MapEntry('detailed', 'Detailed'),
                ],
                selected: user.readingLevel,
                onChanged: (v) => run(() => auth.updatePrefs(level: v)),
              ),
            ),
            const SizedBox(height: 14),

            // Server
            SectionCard(
              title: 'Server',
              icon: Icons.dns_outlined,
              child: Text(Api.I.baseUrl, style: TextStyle(color: p.muted)),
            ),
            const SizedBox(height: 14),

            // Log Out Button
            OutlinedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Log out of Official Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.text,
                side: BorderSide(color: p.line),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'NoticeBridge gives simplified explanations and is not legal or financial advice. '
              'Always check the original notice for important decisions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small preview of one colour combination.
class _PaletteCard extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteCard({required this.palette, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget dot(Color c) => Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: alpha(palette.text, 0.25))),
        );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? p.accent : p.line, width: selected ? 2.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            dot(palette.bg),
            dot(palette.card),
            dot(palette.accent),
            dot(palette.text),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, size: 18, color: palette.accent),
          ]),
          const SizedBox(height: 10),
          Text(palette.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(palette.feel, style: TextStyle(color: alpha(palette.text, 0.65), fontSize: 11)),
        ]),
      ),
    );
  }
}
