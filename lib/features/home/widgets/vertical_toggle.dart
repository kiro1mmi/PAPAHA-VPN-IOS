import 'package:flutter/material.dart';

/// Large vertical toggle switch.
class VerticalToggle extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final bool canConnect;
  final VoidCallback? onTap;

  const VerticalToggle({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.canConnect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double w = 94;
    const double h = 182;
    const double r = 46;
    const double thumbSize = 70;
    const double thumbLeft = 11;
    const double thumbTopOn = 10;
    const double thumbTopOff = 100;

    // Цвет всего тумблера-контейнера — чёрный как фон
    final Color containerColor = Colors.black;

    // Кружок: зелёный при включении, белый при выключении
    final Color thumbColor = isConnected
        ? const Color(0xFF00E676)
        : canConnect
            ? Colors.white
            : const Color(0xFF444444);

    return GestureDetector(
      onTap: (isConnecting || !canConnect) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          color: containerColor,
          border: Border.all(
            color: Colors.white.withAlpha(60),
            width: 1.2,
          ),
          // Белое мягкое свечение ВОКРУГ всего тумблера
          boxShadow: isConnected
              ? [
                  BoxShadow(
                    color: Colors.white.withAlpha(100),
                    blurRadius: 25,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withAlpha(60),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              left: thumbLeft,
              top: isConnected ? thumbTopOn : thumbTopOff,
              child: isConnecting
                  ? SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: thumbColor,
                      ),
                      child: Icon(
                        Icons.power_settings_new,
                        color: isConnected
                            ? Colors.white
                            : canConnect
                                ? const Color(0xFF555555)
                                : const Color(0xFF333333),
                        size: 32,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
