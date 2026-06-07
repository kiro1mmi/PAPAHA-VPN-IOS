"""
Новые Flask-маршруты для Flutter-приложения PAPAHA VPN.
Добавить в конец webapp/app.py перед if __name__ == '__main__':

Также нужно выполнить migration_app.sql на сервере.
"""

import uuid
import time
from datetime import datetime
from flask import jsonify, request

# ── /api/app/user ─────────────────────────────────────────────────────────────

@app.route('/api/app/user', methods=['POST'])
def app_get_or_create_user():
    """
    Регистрация/получение пользователя по device_id.
    Flutter вызывает при каждом запуске.
    """
    try:
        data = request.json
        device_id = data.get('device_id', '').strip()
        if not device_id:
            return jsonify({'error': 'Missing device_id'}), 400

        conn = db_manager.get_connection()

        # Ищем пользователя по device_id
        cursor = conn.execute(
            "SELECT * FROM app_users WHERE device_id = ?", (device_id,)
        )
        user = cursor.fetchone()

        if not user:
            # Создаём нового пользователя
            short_id = device_id[-8:].upper()
            conn.execute(
                """INSERT INTO app_users
                   (device_id, short_id, balance, is_active, created_at, last_charge_date)
                   VALUES (?, ?, 0.0, 0, ?, ?)""",
                (device_id, short_id, datetime.now().isoformat(), datetime.now().isoformat())
            )
            conn.commit()
            cursor = conn.execute(
                "SELECT * FROM app_users WHERE device_id = ?", (device_id,)
            )
            user = cursor.fetchone()

        # Применяем ежедневное списание 4.9₽
        _apply_daily_charge(conn, device_id)

        # Получаем VPN-ключи если есть
        vpn = _get_vpn_keys(conn, device_id)

        return jsonify({
            'device_id': user['device_id'],
            'short_id': user['short_id'],
            'balance': user['balance'],
            'is_active': user['balance'] > 0,
            'vless_key': vpn.get('vless_key'),
            'xhttp_key': vpn.get('xhttp_key'),
            'hysteria2_key': vpn.get('hysteria2_key'),
            'subscription_url': vpn.get('subscription_url'),
            'marzban_username': vpn.get('marzban_username'),
        })

    except Exception as e:
        logger.error(f"app_get_or_create_user error: {e}")
        return jsonify({'error': str(e)}), 500


def _apply_daily_charge(conn, device_id):
    """Списывает 4.9₽ если прошло 24+ часа с последнего списания."""
    try:
        cursor = conn.execute(
            "SELECT balance, last_charge_date FROM app_users WHERE device_id = ?",
            (device_id,)
        )
        row = cursor.fetchone()
        if not row or row['balance'] <= 0:
            return

        last = row['last_charge_date']
        if last:
            last_dt = datetime.fromisoformat(last)
            if (datetime.now() - last_dt).total_seconds() < 86400:
                return  # Ещё не прошло 24 часа

        new_balance = max(0.0, row['balance'] - 4.9)
        conn.execute(
            "UPDATE app_users SET balance = ?, last_charge_date = ? WHERE device_id = ?",
            (new_balance, datetime.now().isoformat(), device_id)
        )
        conn.commit()
        logger.info(f"Daily charge applied for {device_id}: -{4.9}, new balance: {new_balance}")
    except Exception as e:
        logger.error(f"Daily charge error: {e}")


def _get_vpn_keys(conn, device_id):
    """Получает VPN-ключи пользователя из app_devices."""
    try:
        cursor = conn.execute(
            """SELECT marzban_username, vless_key, xhttp_key, hysteria2_key, subscription_url
               FROM app_devices WHERE device_id = ? LIMIT 1""",
            (device_id,)
        )
        row = cursor.fetchone()
        return dict(row) if row else {}
    except Exception:
        return {}


# ── /api/app/vpn-keys/<device_id> ────────────────────────────────────────────

@app.route('/api/app/vpn-keys/<string:device_id>', methods=['GET'])
def app_get_vpn_keys(device_id):
    """Получить актуальные VPN-ключи. Создаёт Marzban-пользователя если нет."""
    try:
        conn = db_manager.get_connection()

        # Проверяем баланс
        cursor = conn.execute(
            "SELECT balance FROM app_users WHERE device_id = ?", (device_id,)
        )
        user = cursor.fetchone()
        if not user or user['balance'] <= 0:
            return jsonify({'error': 'Insufficient balance'}), 402

        # Проверяем есть ли уже ключи
        vpn = _get_vpn_keys(conn, device_id)
        if vpn.get('vless_key'):
            return jsonify(vpn)

        # Создаём пользователя в Marzban
        marzban_username = f"app_{device_id[-12:]}_{int(time.time())}"
        try:
            # Получаем список всех VLESS инбаундов
            inbounds_data = marzban_request('GET', '/api/inbounds')
            all_vless_tags = [i["tag"] for i in inbounds_data.get("vless", [])]
            logger.info(f"Available VLESS inbounds: {all_vless_tags}")
            
            marzban_payload = {
                "username": marzban_username,
                "proxies": {"vless": {"flow": ""}},
                "inbounds": {"vless": all_vless_tags},  # Добавляем ВСЕ инбаунды
                "expire": 0,
                "data_limit": 0,
                "data_limit_reset_strategy": "no_reset",
                "status": "active",
            }
            marzban_data = marzban_request('POST', '/api/user', marzban_payload)

            links = marzban_data.get('links', [])
            vless_key = None
            xhttp_key = None
            hysteria2_key = None

            for link in links:
                if link.startswith('vless://'):
                    if 'reality' in link.lower() or 'type=tcp' in link.lower():
                        if not vless_key:
                            vless_key = link
                    elif 'xhttp' in link.lower() or 'splithttp' in link.lower():
                        xhttp_key = link
                    elif not vless_key:
                        vless_key = link
                elif link.startswith('hysteria2://') or link.startswith('hy2://'):
                    hysteria2_key = link

            sub_url = marzban_data.get('subscription_url', '')
            sub_token = sub_url.split('/')[-1] if sub_url else None
            subscription_url = f"https://sub.papaha.site/sub/{sub_token}" if sub_token else None

            # Сохраняем в БД
            conn.execute(
                """INSERT OR REPLACE INTO app_devices
                   (device_id, marzban_username, vless_key, xhttp_key, hysteria2_key, subscription_url)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (device_id, marzban_username, vless_key, xhttp_key, hysteria2_key, subscription_url)
            )
            conn.commit()

            return jsonify({
                'marzban_username': marzban_username,
                'vless_key': vless_key,
                'xhttp_key': xhttp_key,
                'hysteria2_key': hysteria2_key,
                'subscription_url': subscription_url,
            })

        except Exception as e:
            logger.error(f"Marzban create error: {e}")
            return jsonify({'error': 'VPN provisioning failed'}), 500

    except Exception as e:
        logger.error(f"app_get_vpn_keys error: {e}")
        return jsonify({'error': str(e)}), 500


# ── /api/yukassa/create-payment (обновлённый для device_id) ──────────────────

@app.route('/api/app/payment', methods=['POST'])
def app_create_payment():
    """Создать платёж ЮKassa для Flutter-приложения."""
    try:
        import requests as req
        data = request.json
        device_id = data.get('device_id', '').strip()
        amount = float(data.get('amount', 0))
        tariff_name = data.get('tariff_name', 'Пополнение баланса')

        if not device_id or amount <= 0:
            return jsonify({'error': 'Invalid params'}), 400

        idempotence_key = str(uuid.uuid4())
        payment_data = {
            'amount': {'value': f'{amount:.2f}', 'currency': 'RUB'},
            'confirmation': {
                'type': 'redirect',
                'return_url': 'https://papaha.site/app-return'
            },
            'capture': True,
            'description': f'PAPAHA VPN - {tariff_name}',
            'metadata': {
                'device_id': device_id,
                'tariff_name': tariff_name,
                'source': 'flutter_app'
            }
        }

        resp = req.post(
            'https://api.yookassa.ru/v3/payments',
            json=payment_data,
            headers={'Idempotence-Key': idempotence_key, 'Content-Type': 'application/json'},
            auth=(config['YUKASSA_SHOP_ID'], config['YUKASSA_SECRET_KEY']),
            timeout=10
        )

        if not resp.ok:
            logger.error(f"YuKassa error: {resp.status_code} {resp.text}")
            return jsonify({'error': 'Payment creation failed'}), 500

        payment_resp = resp.json()
        payment_url = payment_resp.get('confirmation', {}).get('confirmation_url')

        return jsonify({'success': True, 'payment_url': payment_url})

    except Exception as e:
        logger.error(f"app_create_payment error: {e}")
        return jsonify({'error': str(e)}), 500


# ── Webhook ЮKassa (обновлённый — обрабатывает device_id) ────────────────────
# Добавить в существующий yukassa_webhook() обработку source=flutter_app:
#
# if metadata.get('source') == 'flutter_app':
#     device_id = metadata.get('device_id')
#     if device_id:
#         conn = db_manager.get_connection()
#         conn.execute(
#             "UPDATE app_users SET balance = balance + ? WHERE device_id = ?",
#             (amount_value, device_id)
#         )
#         conn.commit()
#         # Создаём VPN-ключи если ещё нет
#         # (вызов app_get_vpn_keys логики)
#     return jsonify({'status': 'ok'}), 200


# ── Charity ───────────────────────────────────────────────────────────────────

@app.route('/api/charity/feed', methods=['GET'])
def charity_feed():
    """Анонимная лента пожертвований (20% от платежей)."""
    try:
        conn = db_manager.get_connection()
        cursor = conn.execute(
            """SELECT amount * 0.20 as donated, confirmed_at as date
               FROM payments WHERE status = 'confirmed'
               ORDER BY confirmed_at DESC LIMIT 50"""
        )
        rows = cursor.fetchall()
        return jsonify([
            {'amount': round(r['donated'], 2), 'date': (r['date'] or '')[:10]}
            for r in rows if r['donated'] > 0
        ])
    except Exception as e:
        logger.error(f"charity_feed error: {e}")
        return jsonify([])


@app.route('/api/charity/user/<string:device_id>', methods=['GET'])
def charity_user(device_id):
    """Сумма пожертвований пользователя."""
    try:
        conn = db_manager.get_connection()
        cursor = conn.execute(
            "SELECT COALESCE(SUM(balance_paid) * 0.20, 0) as total FROM app_payments WHERE device_id = ?",
            (device_id,)
        )
        row = cursor.fetchone()
        return jsonify({'total_donated': round(row['total'] if row else 0, 2)})
    except Exception as e:
        return jsonify({'total_donated': 0.0})


# ── Семейный доступ ───────────────────────────────────────────────────────────

@app.route('/api/app/family/join', methods=['POST'])
def family_join():
    """Подключиться к подписке друга по short_id."""
    try:
        data = request.json
        my_device_id = data.get('device_id', '').strip()
        friend_short_id = data.get('friend_id', '').strip().upper()

        if not my_device_id or not friend_short_id:
            return jsonify({'error': 'Missing params'}), 400

        conn = db_manager.get_connection()

        # Ищем владельца по short_id
        cursor = conn.execute(
            "SELECT device_id, balance FROM app_users WHERE short_id = ?",
            (friend_short_id,)
        )
        owner = cursor.fetchone()

        if not owner:
            return jsonify({'error': 'ID не найден'}), 404

        if owner['balance'] <= 0:
            return jsonify({'error': 'У этого пользователя нет активной подписки'}), 400

        if owner['device_id'] == my_device_id:
            return jsonify({'error': 'Нельзя подключиться к самому себе'}), 400

        # Проверяем лимит (3 устройства на владельца)
        cursor = conn.execute(
            "SELECT COUNT(*) as cnt FROM app_family WHERE owner_device_id = ?",
            (owner['device_id'],)
        )
        count = cursor.fetchone()['cnt']
        if count >= 3:
            return jsonify({'error': 'Достигнут лимит устройств (3)'}), 400

        # Добавляем связь
        conn.execute(
            """INSERT OR IGNORE INTO app_family (owner_device_id, member_device_id, joined_at)
               VALUES (?, ?, ?)""",
            (owner['device_id'], my_device_id, datetime.now().isoformat())
        )
        conn.commit()

        # Копируем VPN-ключи владельца
        vpn = _get_vpn_keys(conn, owner['device_id'])

        return jsonify({
            'success': True,
            'vless_key': vpn.get('vless_key'),
            'xhttp_key': vpn.get('xhttp_key'),
            'hysteria2_key': vpn.get('hysteria2_key'),
            'subscription_url': vpn.get('subscription_url'),
        })

    except Exception as e:
        logger.error(f"family_join error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/ping', methods=['GET'])
def app_ping():
    return jsonify({'status': 'ok', 'ts': datetime.utcnow().isoformat()})
