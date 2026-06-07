import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_box.dart';

class ConnectionStats extends StatelessWidget {
  final bool isConnected;
  final Duration duration;
  final int uploadSpeed;
  final int downloadSpeed;
  final int? pingMs;
  final VoidCallback? onPingTap;
  final bool highlightPing;
  final bool showHint;
  final VoidCallback? onDismissHint;

  const ConnectionStats({
    super.key,
    required this.isConnected,
    required this.duration,
    required this.uploadSpeed,
    required this.downloadSpeed,
    this.pingMs,
    this.onPingTap,
    this.highlightPing = false,
    this.showHint = false,
    this.onDismissHint,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Время подключения
            Expanded(
              child: GlassBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 18, color: isConnected ? const Color(0xFF888888) : const Color(0xFF444444)),
                    const SizedBox(width: 10),
                    Text(
                      isConnected ? _formatDuration(duration) : '--:--:--',
                      style: TextStyle(
                        color: isConnected ? Colors.white : const Color(0xFF444444),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Пинг
            GestureDetector(
              onTap: onPingTap,
              child: highlightPing
                  ? _GlowPingBox(pingMs: pingMs)
                  : GlassBox(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: _PingContent(pingMs: isConnected ? pingMs : null),
                    ),
            ),
          ],
        ),

        // Подсказка
        if (showHint) ...[
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment(0.85, 0),
            child: Text('↑',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 22)),
          ),
          GlassBox(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Здесь можно выбирать страны, протоколы и обновить конфигурацию',
                    style:
                        TextStyle(color: Color(0xFF4CAF50), fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismissHint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Понятно',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PingContent extends StatelessWidget {
  final int? pingMs;
  const _PingContent({this.pingMs});

  @override
  Widget build(BuildContext context) {
    final Color pingColor = pingMs == null
        ? const Color(0xFF555555)
        : pingMs! < 80
            ? const Color(0xFF69F0AE)
            : pingMs! < 200
                ? const Color(0xFFFFD740)
                : const Color(0xFFFF5252);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.speed, size: 18, color: pingColor),
        const SizedBox(width: 8),
        Text(
          pingMs != null ? '${pingMs}ms' : '--',
          style: TextStyle(
            color: pingMs != null ? Colors.white : const Color(0xFF666666),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, size: 16, color: Color(0xFF555555)),
      ],
    );
  }
}

class _GlowPingBox extends StatelessWidget {
  final int? pingMs;
  const _GlowPingBox({this.pingMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2A0A),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF4CAF50), width: 2.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF4CAF50).withAlpha(120),
              blurRadius: 24,
              spreadRadius: 4),
          BoxShadow(
              color: const Color(0xFF4CAF50).withAlpha(60),
              blurRadius: 48,
              spreadRadius: 8),
        ],
      ),
      child: _PingContent(pingMs: pingMs),
    );
  }
}
