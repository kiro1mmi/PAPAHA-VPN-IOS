import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/device_service.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'PAPAHA VPN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пользовательское соглашение',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E1E1E)),
                  ),
                  child: const SingleChildScrollView(
                    child: Text(
                      _policyText,
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await DeviceService.savePolicyAccepted();
                    if (context.mounted) context.go('/tutorial');
                  },
                  child: const Text(
                    'Согласиться',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF555555),
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  child: const Text(
                    'Отказаться',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

const _policyText = '''Используя PAPAHA VPN, вы соглашаетесь с условиями предоставления услуг.

Сервис предоставляет доступ к защищённому VPN-соединению по протоколам VLESS, Reality и другим.

Запрещено использовать сервис для незаконной деятельности, распространения вредоносного ПО, DDoS-атак и нарушения авторских прав.

Сервис придерживается политики No-Logs. Мы не собираем и не храним данные о посещаемых вами ресурсах.

20% от чистой прибыли направляется на благотворительность.

Возврат средств возможен только при технической невозможности предоставления услуги более 72 часов подряд.

Полный текст оферты доступен в разделе поддержки.''';
