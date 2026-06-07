/// Mock data for development without server.
class MockService {
  static const double _dailyCharge = 4.97;
  static DateTime? _lastChargeDate;

  static void applyDailyChargeIfNeeded() {
    if (_balance <= 0) return;
    final now = DateTime.now();
    if (_lastChargeDate == null ||
        now.difference(_lastChargeDate!).inHours >= 24) {
      _balance = (_balance - _dailyCharge).clamp(0.0, double.infinity);
      _lastChargeDate = now;
    }
  }

  static double _balance = 500.0;

  static Map<String, dynamic> getUser(String deviceId) => {
        'device_id': deviceId,
        'balance': _balance,
        'is_active': _balance > 0,
        'marzban_username': 'papaha_demo',
        'vless_key':
            'vless://demo-uuid@185.100.50.1:443?security=reality&sni=google.com&pbk=demokey&fp=chrome&type=tcp&flow=xtls-rprx-vision#PAPAHA-Reality',
        'xhttp_key':
            'vless://demo-uuid@185.100.50.2:443?security=tls&sni=cdn.papaha.site&type=xhttp&path=/xhttp&fp=chrome#PAPAHA-xHTTP',
        'lte1_key':
            'vless://demo-uuid@185.100.50.3:443?security=reality&sni=yahoo.com&pbk=ltekey1&fp=chrome&type=tcp&flow=xtls-rprx-vision#PAPAHA-LTE1',
        'lte2_key':
            'vless://demo-uuid@185.100.50.4:443?security=reality&sni=bing.com&pbk=ltekey2&fp=chrome&type=tcp&flow=xtls-rprx-vision#PAPAHA-LTE2',
        'youtube_key':
            'vless://demo-uuid@185.100.50.5:443?security=reality&sni=youtube.com&pbk=ytkey&fp=chrome&type=tcp&flow=xtls-rprx-vision#PAPAHA-YouTube',
        'subscription_url': 'https://sub.papaha.site/sub/demo',
      };

  static void addBalance(double amount) {
    _balance += amount;
  }
}
