import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class DeviceService {
  static String _deviceId = '';
  static bool _hasCompletedOnboarding = false;
  static late SharedPreferences _prefs;

  static String get deviceId => _deviceId;
  static bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = _prefs.getBool('onboarding_done') ?? false;

    final stored = _prefs.getString('device_id');
    if (stored != null && stored.isNotEmpty) {
      _deviceId = stored;
      return;
    }
    _deviceId = await _resolveDeviceId();
    await _prefs.setString('device_id', _deviceId);
  }

  static Future<void> markOnboardingDone() async {
    _hasCompletedOnboarding = true;
    await _prefs.setBool('onboarding_done', true);
  }

  static Future<void> savePolicyAccepted() async {
    await _prefs.setBool('policy_accepted', true);
  }

  static bool get isPolicyAccepted => _prefs.getBool('policy_accepted') ?? false;

  static Future<String> _resolveDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        return _generateUuid();
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final uid = android.serialNumber.isNotEmpty && android.serialNumber != 'unknown'
            ? android.serialNumber
            : android.fingerprint.isNotEmpty
                ? android.fingerprint.hashCode.abs().toRadixString(16)
                : _generateUuid();
        return 'android_${uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').substring(0, uid.length > 20 ? 20 : uid.length)}';
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return 'ios_${ios.identifierForVendor ?? _generateUuid()}';
      }
    } catch (_) {}
    return _generateUuid();
  }

  static String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = now ^ (now >> 16);
    return 'papaha_${rand.toRadixString(16)}';
  }

  /// Short ID for sharing (last 10 chars uppercase)
  static String get shortId {
    if (_deviceId.length > 10) {
      return _deviceId.substring(_deviceId.length - 10).toUpperCase();
    }
    return _deviceId.toUpperCase();
  }
}
