import 'package:flutter/material.dart';

class TariffSheet extends StatelessWidget {
  final Future<void> Function(double amount, String name) onPay;

  const TariffSheet({super.key, required this.onPay});

  static const _tariffs = [
    (name: '1 месяц', days: 30, amount: 149.0),
    (name: '3 месяца', days: 90, amount: 399.0),
    (name: '6 месяцев', days: 180, amount: 749.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Пополнить баланс',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Оплата через ЮKassa',
            style: TextStyle(color: Color(0xFF444444), fontSize: 13),
          ),
          const SizedBox(height: 24),
          ..._tariffs.map((t) => _TariffTile(
                name: t.name,
                days: t.days,
                amount: t.amount,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  onPay(t.amount, t.name);
                },
              )),
        ],
      ),
    );
  }
}

class _TariffTile extends StatelessWidget {
  final String name;
  final int days;
  final double amount;
  final VoidCallback onTap;

  const _TariffTile({
    required this.name,
    required this.days,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E1E1E)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$days дней',
                      style: const TextStyle(
                          color: Color(0xFF444444), fontSize: 12)),
                ],
              ),
            ),
            Text(
              '${amount.toStringAsFixed(0)} \u20BD',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF2A2A2A), size: 13),
          ],
        ),
      ),
    );
  }
}
