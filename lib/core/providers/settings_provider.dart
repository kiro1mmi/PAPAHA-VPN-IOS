import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool animationEnabled;
  final Set<String> excludedPackages; // apps that bypass VPN (Android)
  final bool routingEnabled; // iOS: route only foreign traffic through VPN

  const SettingsState({
    this.animationEnabled = true,
    this.excludedPackages = const {},
    this.routingEnabled = true, // по умолчанию маршрутизация включена
  });

  SettingsState copyWith({
    bool? animationEnabled,
    Set<String>? excludedPackages,
    bool? routingEnabled,
  }) =>
      SettingsState(
        animationEnabled: animationEnabled ?? this.animationEnabled,
        excludedPackages: excludedPackages ?? this.excludedPackages,
        routingEnabled: routingEnabled ?? this.routingEnabled,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  static const _keyAnimation = 'animation_enabled';
  static const _keyExcluded = 'excluded_packages';
  static const _keyRouting = 'routing_enabled';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anim = prefs.getBool(_keyAnimation) ?? true;
      final excluded = prefs.getStringList(_keyExcluded) ?? [];
      final routing = prefs.getBool(_keyRouting) ?? true;
      state = SettingsState(
        animationEnabled: anim,
        excludedPackages: excluded.toSet(),
        routingEnabled: routing,
      );
    } catch (_) {}
  }

  Future<void> setAnimationEnabled(bool value) async {
    state = state.copyWith(animationEnabled: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAnimation, value);
    } catch (_) {}
  }

  Future<void> toggleExcludedPackage(String packageName) async {
    final set = Set<String>.from(state.excludedPackages);
    if (set.contains(packageName)) {
      set.remove(packageName);
    } else {
      set.add(packageName);
    }
    state = state.copyWith(excludedPackages: set);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyExcluded, set.toList());
    } catch (_) {}
  }

  Future<void> setRoutingEnabled(bool value) async {
    state = state.copyWith(routingEnabled: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRouting, value);
    } catch (_) {}
  }

  Set<String> get excludedPackages => state.excludedPackages;
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
