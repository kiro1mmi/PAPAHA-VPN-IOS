-- Таблица пользователей Flutter-приложения
CREATE TABLE IF NOT EXISTS app_users (
    device_id TEXT PRIMARY KEY,
    short_id TEXT UNIQUE NOT NULL,
    balance REAL DEFAULT 0.0,
    is_active INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    last_charge_date TEXT
);

-- Таблица VPN-ключей (один слот на устройство)
CREATE TABLE IF NOT EXISTS app_devices (
    device_id TEXT PRIMARY KEY,
    marzban_username TEXT UNIQUE,
    vless_key TEXT,
    xhttp_key TEXT,
    hysteria2_key TEXT,
    subscription_url TEXT,
    FOREIGN KEY (device_id) REFERENCES app_users(device_id)
);

-- Таблица семейного доступа
CREATE TABLE IF NOT EXISTS app_family (
    owner_device_id TEXT NOT NULL,
    member_device_id TEXT NOT NULL,
    joined_at TEXT NOT NULL,
    PRIMARY KEY (owner_device_id, member_device_id)
);

-- Таблица платежей приложения
CREATE TABLE IF NOT EXISTS app_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    balance_paid REAL NOT NULL,
    tariff TEXT,
    yukassa_id TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_users_short_id ON app_users(short_id);
CREATE INDEX IF NOT EXISTS idx_app_family_owner ON app_family(owner_device_id);
