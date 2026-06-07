import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/vpn_provider.dart';
import '../../core/providers/user_provider.dart';
import 'widgets/hills_background.dart';
import 'widgets/vertical_toggle.dart';
import 'widgets/connection_stats.dart';
import 'widgets/menu_button.dart';
import 'widgets/server_selector.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _hintEverShown = false;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    // Одноразово обновляем данные пользователя при открытии экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshUser(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vpnState = ref.watch(vpnProvider);
    final userAsync = ref.watch(userAsyncProvider);
    final isConnected = vpnState.status == VpnStatus.connected;
    final isConnecting = vpnState.status == VpnStatus.connecting;

    if (isConnected && !_hintEverShown && !_showHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hintEverShown) setState(() => _showHint = true);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Фон — жидкая сетка
          const Positioned.fill(child: HillsBackground()),

          SafeArea(
            child: Column(
              children: [
                // ── Логотип по центру, большой ────────────────────────────
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: Image.asset(
                        'assets/images/logov2.jpeg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF111111),
                          child: const Center(
                            child: Text(
                              'PAPAHA VPN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Баланс + меню — поверх логотипа, справа сверху, в одну строку
                    Positioned(
                      top: 12,
                      right: 12,
                      child: userAsync.when(
                        data: (user) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (user.balance > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(120),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.white.withAlpha(40)),
                                ),
                                child: Text(
                                  '${user.balance.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const MenuButton(),
                          ],
                        ),
                        loading: () => const MenuButton(),
                        error: (_, __) => const MenuButton(),
                      ),
                    ),
                  ],
                ),

                // ── Статистика ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Opacity(
                    opacity: _showHint ? 0.0 : 1.0,
                    child: ConnectionStats(
                      isConnected: isConnected,
                      duration: vpnState.connectionDuration,
                      uploadSpeed: vpnState.uploadSpeed,
                      downloadSpeed: vpnState.downloadSpeed,
                      pingMs: vpnState.pingMs,
                      onPingTap: () {
                        final user = userAsync.valueOrNull;
                        if (user != null) {
                          showServerSelector(context, ref, user.allKeys);
                        }
                      },
                      highlightPing: false,
                      showHint: false,
                      onDismissHint: null,
                    ),
                  ),
                ),

                // ── Тумблер (центр) ────────────────────────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        userAsync.when(
                          data: (user) {
                            return VerticalToggle(
                              isConnected: isConnected,
                              isConnecting: isConnecting,
                              canConnect: user.canConnect,
                              onTap: () {
                                if (!user.canConnect) return;
                                ref
                                    .read(vpnProvider.notifier)
                                    .toggle(keys: user.allKeys);
                              },
                            );
                          },
                          loading: () => const VerticalToggle(
                            isConnected: false,
                            isConnecting: true,
                            canConnect: false,
                            onTap: null,
                          ),
                          error: (_, __) => const VerticalToggle(
                            isConnected: false,
                            isConnecting: false,
                            canConnect: false,
                            onTap: null,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _StatusLabel(
                          status: vpnState.status,
                          canConnect:
                              userAsync.valueOrNull?.canConnect ?? false,
                          errorMessage: vpnState.errorMessage,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Hint overlay ─────────────────────────────────────────────────
          if (_showHint) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _hintEverShown = true;
                  setState(() => _showHint = false);
                },
                child: Container(color: Colors.black.withAlpha(170)),
              ),
            ),
            // Статистика поверх затемнения с highlight
            Positioned(
              top: MediaQuery.of(context).padding.top + 200 + 20,
              left: 16,
              right: 16,
              child: ConnectionStats(
                isConnected: isConnected,
                duration: vpnState.connectionDuration,
                uploadSpeed: vpnState.uploadSpeed,
                downloadSpeed: vpnState.downloadSpeed,
                pingMs: vpnState.pingMs,
                onPingTap: () {
                  _hintEverShown = true;
                  setState(() => _showHint = false);
                  final user = userAsync.valueOrNull;
                  if (user != null) {
                    Future.microtask(() {
                      if (mounted) {
                        showServerSelector(context, ref, user.allKeys);
                      }
                    });
                  }
                },
                highlightPing: true,
                showHint: true,
                onDismissHint: () {
                  _hintEverShown = true;
                  setState(() => _showHint = false);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final VpnStatus status;
  final bool canConnect;
  final String? errorMessage;

  const _StatusLabel({
    required this.status,
    required this.canConnect,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!canConnect) {
      return const Text(
        'ПОПОЛНИТЕ БАЛАНС',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF444444),
          letterSpacing: 1.5,
        ),
      );
    }

    if (status == VpnStatus.error && errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFFF5252),
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final (text, color) = switch (status) {
      VpnStatus.connected    => ('ЗАЩИЩЕНО',               const Color(0xFF4CAF50)),
      VpnStatus.connecting   => ('ПОДКЛЮЧЕНИЕ',             const Color(0xFF888888)),
      VpnStatus.error        => ('ОШИБКА',                  const Color(0xFFFF5252)),
      VpnStatus.disconnected => ('НАЖМИТЕ ДЛЯ ПОДКЛЮЧЕНИЯ', const Color(0xFF444444)),
    };

    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 1.5,
      ),
    );
  }
}
