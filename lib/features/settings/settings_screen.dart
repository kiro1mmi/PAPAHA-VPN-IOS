import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/settings_provider.dart';
import '../home/widgets/glass_box.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // settings читается только для split tunnel
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Настройки',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ─── Split tunneling / Routing ───────────────────────────────────────
          _SectionHeader('Выборочный обход VPN'),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Выберите приложения, которые будут работать напрямую без VPN, даже когда туннель включён',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          GlassBox(
            padding: EdgeInsets.zero,
            child: _SplitTunnelTile(settings: settings, ref: ref),
          ),

          // ─── iOS Routing toggle ──────────────────────────────────────────
          if (!kIsWeb && Platform.isIOS) ...[
            const SizedBox(height: 24),
            _SectionHeader('Маршрутизация (iOS)'),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'При включении — российский трафик идёт напрямую, зарубежный через VPN. Как в Happ.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            GlassBox(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                title: const Text('Раздельная маршрутизация',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  settings.routingEnabled
                      ? 'Только зарубежный трафик через VPN'
                      : 'Весь трафик через VPN',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: settings.routingEnabled,
                activeColor: const Color(0xFF4CAF50),
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setRoutingEnabled(v),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ─── Troubleshooting ─────────────────────────────────────────────
          _SectionHeader('Помощь'),
          GlassBox(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white70),
              title: const Text('Что делать если VPN не работает',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => _showTroubleshoot(context),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showTroubleshoot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const _TroubleshootSheet(),
    );
  }
}

// ─── Split tunnel tile ────────────────────────────────────────────────────────

class _SplitTunnelTile extends StatelessWidget {
  final SettingsState settings;
  final WidgetRef ref;
  const _SplitTunnelTile({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final excluded = settings.excludedPackages;
    final label = excluded.isEmpty
        ? 'Все приложения через VPN'
        : '${excluded.length} прил. без VPN';

    return ListTile(
      leading: const Icon(Icons.phonelink_setup, color: Colors.white70),
      title: const Text('Приложения без VPN',
          style: TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: () => _openAppSelector(context),
    );
  }

  void _openAppSelector(BuildContext context) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: const Text('Недоступно', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Выборочная маршрутизация доступна только на Android.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          child: _AppListScreen(
            excludedPackages: ref.read(settingsProvider).excludedPackages,
            onToggle: (pkg) =>
                ref.read(settingsProvider.notifier).toggleExcludedPackage(pkg),
          ),
        ),
      ),
    );
  }
}

// ─── App list screen (Android) ────────────────────────────────────────────────

class _AppInfo {
  final String packageName;
  final String label;
  _AppInfo({required this.packageName, required this.label});
}

class _AppListScreen extends StatefulWidget {
  final Set<String> excludedPackages;
  final void Function(String) onToggle;

  const _AppListScreen({
    required this.excludedPackages,
    required this.onToggle,
  });

  @override
  State<_AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<_AppListScreen> {
  List<_AppInfo> _apps = [];
  bool _loading = true;
  late Set<String> _excluded;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _excluded = Set.from(widget.excludedPackages);
    _loadApps();
  }

  Future<void> _loadApps() async {
    List<_AppInfo> apps = [];
    try {
      const ch = MethodChannel('com.example.papaha_vpn/apps');
      final List result = await ch.invokeMethod('getInstalledApps');
      apps = result
          .map((e) => _AppInfo(
                packageName: e['packageName'] as String,
                label: e['label'] as String,
              ))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));
    } catch (_) {
      // На не-Android или если канал недоступен — пустой список
      apps = [];
    }

    if (mounted) setState(() { _apps = apps; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _apps
        : _apps
            .where((a) =>
                a.label.toLowerCase().contains(_query.toLowerCase()) ||
                a.packageName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Приложения без VPN',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск приложений...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Colors.white38)),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFF1F1F1F), indent: 16),
                itemBuilder: (_, i) {
                  final app = filtered[i];
                  final excluded = _excluded.contains(app.packageName);
                  return ListTile(
                    title: Text(app.label,
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(app.packageName,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    trailing: excluded
                        ? const Icon(Icons.check_circle,
                            color: Colors.white70, size: 22)
                        : const Icon(Icons.circle_outlined,
                            color: Colors.white24, size: 22),
                    onTap: () {
                      setState(() {
                        if (_excluded.contains(app.packageName)) {
                          _excluded.remove(app.packageName);
                        } else {
                          _excluded.add(app.packageName);
                        }
                      });
                      widget.onToggle(app.packageName);
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

// ─── Troubleshoot sheet ───────────────────────────────────────────────────────

class _TroubleshootSheet extends StatelessWidget {
  const _TroubleshootSheet();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('1', 'Обновите конфигурации', 'Нажмите на пинг → "Обновить конфигурацию" на главном экране'),
      ('2', 'Перезапустите приложение', 'Полностью закройте приложение и откройте заново'),
      ('3', 'Перезагрузите телефон', 'Выключите и включите устройство'),
      ('4', 'Проверьте интернет', 'Убедитесь что интернет работает без VPN — зайдите на любой сайт'),
      ('5', 'Напишите в поддержку', 'Нажмите ··· на главном экране и выберите "Поддержка"'),
    ];

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: bottomPad + 100,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Если VPN не работает',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Выполните шаги по порядку:',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),
          ...steps.map((s) => _Step(number: s.$1, title: s.$2, desc: s.$3)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  const _Step({required this.number, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
