# PAPAHA VPN — Flutter App

Нативное кроссплатформенное приложение (iOS + Android), заменяющее Telegram Mini App.

## Структура проекта

```
lib/
├── main.dart                          # Точка входа
├── core/
│   ├── theme/app_theme.dart           # Цвета, шрифты (Neon Black)
│   ├── router/app_router.dart         # go_router навигация
│   ├── services/
│   │   ├── api_service.dart           # HTTP-клиент → ваш Flask-сервер
│   │   ├── device_service.dart        # DeviceID (первичный ключ)
│   │   └── singbox_service.dart       # Генерация sing-box JSON конфига
│   └── providers/
│       ├── user_provider.dart         # Riverpod: пользователь + устройства
│       └── vpn_provider.dart          # Riverpod: статус VPN, протокол
├── data/models/
│   └── user_model.dart                # UserModel, DeviceModel, TariffModel
└── features/
    ├── onboarding/                    # Первый запуск, привязка Telegram ID
    ├── shell/shell_screen.dart        # Bottom navigation (3 вкладки)
    ├── home/
    │   ├── home_screen.dart           # Главный экран
    │   └── widgets/
    │       ├── mountain_painter.dart  # ⭐ CustomPainter — анимация гор с glow
    │       ├── connect_button.dart    # Кнопка подключения
    │       ├── protocol_tabs.dart     # Reality / xHTTP / Hysteria 2
    │       └── ping_badge.dart        # Индикатор пинга
    ├── profile/                       # Баланс, устройства, ЮKassa, QR
    └── charity/                       # Лента пожертвований (20% от платежей)

backend_additions/
├── charity_routes.py                  # Новые Flask-эндпоинты (добавить в app.py)
└── migration_device_id.sql            # ALTER TABLE для device_id
```

## Быстрый старт

### 1. Установить Flutter
https://docs.flutter.dev/get-started/install

### 2. Настроить API URL
```dart
// lib/core/services/api_service.dart
const String kBaseUrl = 'https://your-papaha-server.com';
```

### 3. Добавить бэкенд-эндпоинты
```bash
# На сервере с ботом:
sqlite3 papaha_vpn.db < backend_additions/migration_device_id.sql
# Скопировать маршруты из backend_additions/charity_routes.py в webapp/app.py
```

### 4. Запустить приложение
```bash
cd papaha_vpn_app
flutter pub get
flutter run
```

## Подключение sing-box (VPN ядро)

Конфиг генерируется автоматически в `SingboxService.buildConfig()`.
Для реального туннеля нужно подключить нативную библиотеку:

**Android:** [sing-box Android library](https://github.com/SagerNet/sing-box)  
**iOS:** [sing-box iOS framework](https://github.com/SagerNet/sing-box)

Или использовать готовый Flutter-плагин:
```yaml
# pubspec.yaml
flutter_v2ray: ^1.1.0
```

Затем в `vpn_provider.dart` раскомментировать:
```dart
// await SingboxPlatform.instance.start(config);
```

## Протоколы

| Вкладка | Ключ из Marzban | sing-box тип |
|---------|-----------------|--------------|
| Reality | `vless_key` (device) | vless + reality TLS |
| xHTTP | `lte_key` (device) | vless + splithttp transport |
| Hysteria 2 | `hysteria2_key` (marzban) | hysteria2 |

## Семейный доступ

- Основной пользователь: показывает QR с `subscription_url` устройства
- Дополнительный пользователь: сканирует QR → получает Sub URL → импортирует в любой клиент
- Лимит: 3 устройства на аккаунт (как в боте)
