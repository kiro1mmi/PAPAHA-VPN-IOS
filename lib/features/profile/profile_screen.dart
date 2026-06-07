import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/device_service.dart';
import '../../core/services/mock_service.dart';
import 'widgets/balance_card.dart';
import 'widgets/tariff_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userAsyncProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // Balance card - prominent
            BalanceCard(
              balance: user.balance,
              daysRemaining: user.daysRemaining,
              onTopUp: () => _openTopUp(context, ref),
            ),
            const SizedBox(height: 12),

            // Promocode
            _ActionButton(
              icon: Icons.confirmation_number_outlined,
              title: 'Ввести промокод',
              onTap: () => _showPromocodeDialog(context, ref),
            ),
            const SizedBox(height: 24),

            // Share section
            const _SectionTitle('Поделиться с другом'),
            const SizedBox(height: 6),
            const Text(
              'Поделитесь своим ID — до 3 устройств могут подключиться к вашей подписке',
              style: TextStyle(color: Color(0xFF444444), fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.share_outlined,
              title: 'Поделиться ID',
              onTap: () => _showShareDialog(context),
            ),
            const SizedBox(height: 12),

            // Join by ID
            _ActionButton(
              icon: Icons.group_add_outlined,
              title: 'Доступ по ID',
              subtitle: 'Подключиться к подписке друга',
              onTap: () => _showJoinDialog(context, ref),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Нет соединения',
                  style: TextStyle(color: Color(0xFF555555))),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => refreshUser(ref),
                child: const Text('Повторить',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTopUp(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => TariffSheet(
        onPay: (amount, name) async {
          if (kUseMock) {
            MockService.addBalance(amount);
            refreshUser(ref);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Баланс пополнен на ${amount.toStringAsFixed(0)} руб'),
                backgroundColor: const Color(0xFF1A2A1A),
              ));
            }
            return;
          }
          try {
            final api = ref.read(apiServiceProvider);
            final paymentUrl = await api.createPayment(
              amount: amount,
              tariffName: name,
            );
            final uri = Uri.parse(paymentUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: ${e.toString().replaceAll('Exception:', '').trim()}'),
                  backgroundColor: const Color(0xFF2A1A1A),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ваш ID',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Отправьте этот ID другу для подключения к вашей подписке',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DeviceService.shortId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: DeviceService.shortId));
              Navigator.of(context, rootNavigator: true).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID скопирован'),
                  backgroundColor: Color(0xFF1A1A1A),
                ),
              );
            },
            child: const Text('Скопировать',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Закрыть',
                style: TextStyle(color: Color(0xFF444444))),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Доступ по ID',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Введите ID друга для подключения к его подписке',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, letterSpacing: 2),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'ID друга',
                hintStyle: const TextStyle(color: Color(0xFF333333)),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Отмена',
                style: TextStyle(color: Color(0xFF444444))),
          ),
          TextButton(
            onPressed: () async {
              final id = ctrl.text.trim().toUpperCase();
              Navigator.of(context, rootNavigator: true).pop();
              if (id.isEmpty) return;
              try {
                if (kUseMock) {
                  await Future.delayed(const Duration(milliseconds: 500));
                  refreshUser(ref);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Подключено к подписке друга'),
                      backgroundColor: Color(0xFF1A2A1A),
                    ),
                  );
                } else {
                  final api = ref.read(apiServiceProvider);
                  await api.familyJoin(id);
                  refreshUser(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Подключено к подписке друга'),
                        backgroundColor: Color(0xFF1A2A1A),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: ${e.toString().replaceAll('Exception:', '').trim()}'),
                      backgroundColor: const Color(0xFF2A1A1A),
                    ),
                  );
                }
              }
            },
            child: const Text('Подключиться',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPromocodeDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Промокод',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'Введите код',
            hintStyle: const TextStyle(color: Color(0xFF333333)),
            filled: true,
            fillColor: const Color(0xFF0A0A0A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Отмена',
                style: TextStyle(color: Color(0xFF444444))),
          ),
          TextButton(
            onPressed: () async {
              final code = ctrl.text.trim().toUpperCase();
              Navigator.of(context, rootNavigator: true).pop();
              if (code.isEmpty) return;
              try {
                final api = ref.read(apiServiceProvider);
                final result = await api.applyPromocode(code);
                final amount = (result['amount'] as num).toDouble();
                refreshUser(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('+${amount.toStringAsFixed(0)} руб'),
                    backgroundColor: const Color(0xFF1A2A1A),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Ошибка: ${e.toString().replaceAll('Exception:', '').trim()}'),
                    backgroundColor: const Color(0xFF2A1A1A),
                  ));
                }
              }
            },
            child: const Text('Применить',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E1E1E)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF555555), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(color: Color(0xFF444444), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF2A2A2A), size: 13),
          ],
        ),
      ),
    );
  }
}
