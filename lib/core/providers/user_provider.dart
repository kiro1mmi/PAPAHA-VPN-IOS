import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/mock_service.dart';
import '../services/device_service.dart';
import '../../data/models/user_model.dart';

// Switch: true = mock (dev without server), false = real API
// Set to false when papaha.site:8443 backend is running
const bool kUseMock = false;

final telegramIdProvider = StateProvider<int?>((ref) => null);

final userRefreshProvider = StateProvider<int>((ref) => 0);

final userAsyncProvider = FutureProvider<UserModel>((ref) async {
  ref.watch(userRefreshProvider);

  if (kUseMock) {
    MockService.applyDailyChargeIfNeeded();
    final data = MockService.getUser(DeviceService.deviceId);
    return UserModel.fromJson(data);
  }

  final api = ref.read(apiServiceProvider);
  final data = await api.getOrCreateUser();
  return UserModel.fromJson(data);
});

void refreshUser(WidgetRef ref) {
  ref.read(userRefreshProvider.notifier).state++;
}

Future<void> saveTelegramId(int id) async {
  // Save to shared prefs or API
}
