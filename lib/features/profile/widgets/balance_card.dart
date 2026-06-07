import 'package:flutter/material.dart';

/// Prominent balance card with accented border and glow.
class BalanceCard extends StatelessWidget {
  final double balance;
  final int daysRemaining;
  final VoidCallback onTopUp;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.daysRemaining,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final hasBalance = balance > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBalance
              ? Colors.white.withOpacity(0.25)
              : const Color(0xFFFF5252).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          if (hasBalance)
            BoxShadow(
              color: Colors.white.withOpacity(0.04),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Баланс',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w500,
                  )),
              const Spacer(),
              if (hasBalance)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '$daysRemaining дн.',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF5252).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Неактивен',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(2)} \u20BD',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTopUp,
              child: const Text('Пополнить',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
