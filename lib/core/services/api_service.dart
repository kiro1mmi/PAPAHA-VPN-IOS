import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_service.dart';

const String kBaseUrl = 'https://papaha.site:8443';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Device-ID'] = DeviceService.deviceId;
        handler.next(options);
      },
    ));
  }

  Future<Map<String, dynamic>> getOrCreateUser() async {
    final resp = await _dio.post('/api/app/user', data: {
      'device_id': DeviceService.deviceId,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<String> createPayment({
    required double amount,
    required String tariffName,
  }) async {
    final resp = await _dio.post('/api/app/payment', data: {
      'device_id': DeviceService.deviceId,
      'amount': amount,
      'tariff_name': tariffName,
    });
    return (resp.data as Map<String, dynamic>)['payment_url'] as String;
  }

  Future<Map<String, dynamic>> familyJoin(String friendShortId) async {
    final resp = await _dio.post('/api/app/family/join', data: {
      'device_id': DeviceService.deviceId,
      'friend_id': friendShortId,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyPromocode(String code) async {
    final resp = await _dio.post('/api/app/promocode', data: {
      'device_id': DeviceService.deviceId,
      'code': code.trim().toUpperCase(),
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshConfig() async {
    final resp = await _dio.post('/api/app/refresh-config', data: {
      'device_id': DeviceService.deviceId,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<int> ping() async {
    final sw = Stopwatch()..start();
    await _dio.get('/api/ping');
    sw.stop();
    return sw.elapsedMilliseconds;
  }
}
