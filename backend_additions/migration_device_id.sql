-- Добавить колонку device_id в таблицу users
-- Запустить один раз на сервере

ALTER TABLE users ADD COLUMN device_id TEXT;
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);
