import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'add_notice_screen.dart';
import 'notice_detail_screen.dart';
import 'notices_tab.dart';
import 'settings_tab.dart';
import 'tasks_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _version = 0; // bump to make the tabs reload their data

  void _refresh() => setState(() => _version++);

  Future<void> _addNotice() async {
    final newId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AddNoticeScreen()),
    );
    if (newId != null && mounted) {
      _refresh();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(noticeId: newId)),
      );
      if (mounted) _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: IndexedStack(
                    index: _index,
                    children: [
                      NoticesTab(
                        key: ValueKey('n$_version'),
                        onChanged: _refresh,
                        onGoToTasks: () => setState(() => _index = 1),
                      ),
                      TasksTab(key: ValueKey('t$_version')),
                      const SettingsTab(),
                    ],
                  ),
                ),
                if (_index == 0)
                  Positioned(
                    right: 20,
                    bottom: 104,
                    child: GlowButton(label: 'Add notice', icon: Icons.add_a_photo_outlined, onPressed: _addNotice),
                  ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _NavBar(
                          index: _index,
                          onSelect: (i) {
                            setState(() => _index = i);
                            if (i != 2) _refresh();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _NavBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.line),
        boxShadow: [BoxShadow(color: alpha(Colors.black, p.dark ? 0.5 : 0.10), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description, label: 'Notices', selected: index == 0, onTap: () => onSelect(0)),
          _NavItem(icon: Icons.event_available_outlined, activeIcon: Icons.event_available, label: 'Deadlines', selected: index == 1, onTap: () => onSelect(1)),
          _NavItem(icon: Icons.tune, activeIcon: Icons.tune, label: 'Settings', selected: index == 2, onTap: () => onSelect(2)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? alpha(p.accent, 0.20) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? alpha(p.accent, 0.6) : Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, size: 22, color: selected ? p.accentText : p.muted),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? p.text : p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
