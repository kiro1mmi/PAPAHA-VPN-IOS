class UserModel {
  final String deviceId;
  final double balance;
  final bool isActive;
  final String? marzbanUsername;
  final List<String> allKeys;  // Все ключи вместо отдельных полей
  final String? subscriptionUrl;

  const UserModel({
    required this.deviceId,
    required this.balance,
    required this.isActive,
    this.marzbanUsername,
    this.allKeys = const [],
    this.subscriptionUrl,
  });

  bool get canConnect => balance > 0;
  int get daysRemaining => (balance / 4.97).floor();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Собираем все ключи из разных полей в один массив
    final keys = <String>[];
    
    if (json['vless_key'] != null && (json['vless_key'] as String).isNotEmpty) {
      keys.add(json['vless_key'] as String);
    }
    if (json['xhttp_key'] != null && (json['xhttp_key'] as String).isNotEmpty) {
      keys.add(json['xhttp_key'] as String);
    }
    if (json['lte1_key'] != null && (json['lte1_key'] as String).isNotEmpty) {
      keys.add(json['lte1_key'] as String);
    }
    if (json['lte2_key'] != null && (json['lte2_key'] as String).isNotEmpty) {
      keys.add(json['lte2_key'] as String);
    }
    if (json['youtube_key'] != null && (json['youtube_key'] as String).isNotEmpty) {
      keys.add(json['youtube_key'] as String);
    }
    if (json['hysteria2_key'] != null && (json['hysteria2_key'] as String).isNotEmpty) {
      keys.add(json['hysteria2_key'] as String);
    }
    
    // Если есть поле all_keys - используем его
    if (json['all_keys'] != null && json['all_keys'] is List) {
      keys.clear();
      keys.addAll((json['all_keys'] as List).cast<String>());
    }
    
    return UserModel(
      deviceId: json['device_id'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      marzbanUsername: json['marzban_username'] as String?,
      allKeys: keys,
      subscriptionUrl: json['subscription_url'] as String?,
    );
  }
}
