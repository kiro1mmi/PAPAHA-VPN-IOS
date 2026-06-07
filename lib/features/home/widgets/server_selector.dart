import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/vpn_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/api_service.dart';

/// Shows a bottom sheet with available servers for manual selection.
void showServerSelector(BuildContext context, WidgetRef ref, List<String> keys) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final vpnState = ref.watch(vpnProvider);
        return _ServerSelectorSheet(
          keys: keys,
          activeServer: vpnState.activeServer,
        );
      },
    ),
  );
}

class _ServerSelectorSheet extends StatefulWidget {
  final List<String> keys;
  final String? activeServer;

  const _ServerSelectorSheet({
    required this.keys,
    this.activeServer,
  });

  @override
  State<_ServerSelectorSheet> createState() => _ServerSelectorSheetState();
}

class _ServerSelectorSheetState extends State<_ServerSelectorSheet> {
  bool _isRefreshing = false;

  /// Как в Happ: просто тянем свежие ключи с бэкенда, без пересоздания пользователя
  Future<void> _refreshConfig(WidgetRef ref) async {
    setState(() => _isRefreshing = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.refreshConfig();

      // Перезагружаем данные пользователя (all_keys обновятся)
      ref.read(userRefreshProvider.notifier).state++;

      if (mounted) {
        setState(() => _isRefreshing = false);
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        // Показываем ошибку пока bottom sheet ещё открыт
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: const Color(0xFF5E1B1B),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _extractLabel(String key) {
    try {
      final hashIndex = key.indexOf('#');
      if (hashIndex >= 0 && hashIndex < key.length - 1) {
        final fragment = key.substring(hashIndex + 1);
        final safe = fragment.replaceAllMapped(
          RegExp(r'%(?![0-9A-Fa-f]{2})'),
          (_) => '%25',
        );
        return Uri.decodeComponent(safe);
      }
      final uri = Uri.tryParse(key.split('#').first);
      return uri?.host ?? 'Сервер';
    } catch (_) {
      return 'Сервер';
    }
  }

  String _extractHost(String key) {
    try {
      final uri = Uri.tryParse(key.split('#').first);
      if (uri == null) return '';
      return '${uri.host}:${uri.port}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final maxHeight = MediaQuery.of(context).size.height * 0.75;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Выбор сервера',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Выберите сервер для подключения',
                style: TextStyle(color: Color(0xFF555555), fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Список серверов
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.keys.map((key) {
                        final isActive = widget.activeServer == key;
                        return _ServerTile(
                          label: _extractLabel(key),
                          isActive: isActive,
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            ref.read(vpnProvider.notifier).connectToServer(key);
                          },
                        );
                      }),
                      if (widget.keys.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Нет доступных серверов',
                            style: TextStyle(color: Color(0xFF444444)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Кнопка "Обновить протоколы" — как в Happ
              GestureDetector(
                onTap: _isRefreshing ? null : () => _refreshConfig(ref),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A0A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD740).withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRefreshing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFFD740),
                          ),
                        )
                      else
                        const Icon(Icons.refresh, color: Color(0xFFFFD740), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _isRefreshing ? 'Обновление...' : 'Обновить протоколы',
                        style: const TextStyle(
                          color: Color(0xFFFFD740),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerTile extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ServerTile({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0D1A0D) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4CAF50).withAlpha(150)
                : const Color(0xFF1E1E1E),
            width: isActive ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.dns_outlined,
              color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF555555),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF4CAF50) : Colors.white,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isActive)
              const Text(
                'Активен',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
              )
            else
              const Icon(Icons.arrow_forward_ios,
                  color: Color(0xFF333333), size: 12),
          ],
        ),
      ),
    );
  }
}
