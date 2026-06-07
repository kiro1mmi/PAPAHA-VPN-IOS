import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const String _statusKey = 'flutter.widget_vpn_status';
  static const _channel = MethodChannel('com.papaha.vpn/xray');

  static Future<void> updateVpnStatus(bool isConnected) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, isConnected ? 'connected' : 'disconnected');
      // Обновляем виджет через нативный канал
      await _channel.invokeMethod('refreshWidget');
    } catch (e) {
      debugPrint('WidgetService: $e');
    }
  }
}
