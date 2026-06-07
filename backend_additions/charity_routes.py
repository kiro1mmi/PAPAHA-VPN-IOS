"""
Дополнительные маршруты для Flutter-приложения PAPAHA VPN.
Добавить в webapp/app.py существующего бота.
"""
from flask import jsonify, request
from datetime import datetime


# ── Добавить в app.py ──────────────────────────────────────────────────────────

@app.route('/api/charity/feed', methods=['GET'])
def charity_feed():
    """
    Анонимная лента последних пожертвований.
    20% от каждого confirmed-платежа считается пожертвованием.
    """
    try:
        # Берём последние 50 подтверждённых платежей
        conn = db_manager.get_connection()
        cursor = conn.execute(
            """
            SELECT amount * 0.20 as donated, confirmed_at as date
            FROM payments
            WHERE status = 'confirmed'
            ORDER BY confirmed_at DESC
            LIMIT 50
            """
        )
        rows = cursor.fetchall()
        feed = [
            {
                'amount': round(row['donated'], 2),
                'date': row['date'][:10] if row['date'] else ''
            }
            for row in rows
            if row['donated'] > 0
        ]
        return jsonify(feed)
    except Exception as e:
        logger.error(f"charity_feed error: {e}")
        return jsonify([])


@app.route('/api/charity/user/<int:telegram_id>', methods=['GET'])
def user_charity(telegram_id):
    """
    Сумма пожертвований конкретного пользователя (20% от его платежей).
    """
    try:
        conn = db_manager.get_connection()
        cursor = conn.execute(
            """
            SELECT COALESCE(SUM(amount * 0.20), 0) as total_donated
            FROM payments
            WHERE telegram_id = ? AND status = 'confirmed'
            """,
            (telegram_id,)
        )
        row = cursor.fetchone()
        return jsonify({'total_donated': round(row['total_donated'], 2)})
    except Exception as e:
        logger.error(f"user_charity error: {e}")
        return jsonify({'total_donated': 0.0})


@app.route('/api/device/link', methods=['POST'])
def link_device():
    """
    Привязка DeviceID к Telegram ID.
    Flutter-приложение вызывает этот эндпоинт при онбординге.
    """
    try:
        data = request.json
        device_id = data.get('device_id')
        telegram_id = data.get('telegram_id')

        if not device_id or not telegram_id:
            return jsonify({'error': 'Missing fields'}), 400

        # Сохраняем device_id в таблицу users (добавить колонку device_id если нет)
        conn = db_manager.get_connection()
        conn.execute(
            "UPDATE users SET device_id = ? WHERE telegram_id = ?",
            (device_id, telegram_id)
        )
        conn.commit()

        return jsonify({'success': True})
    except Exception as e:
        logger.error(f"link_device error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/marzban/user/<string:marzban_username>', methods=['GET'])
def get_marzban_user_proxy(marzban_username):
    """
    Прокси к Marzban API — возвращает ключи и subscription_url.
    Flutter-приложение использует это для получения актуальных VPN-ключей.
    """
    try:
        data = marzban_request('GET', f'/api/user/{marzban_username}')
        return jsonify(data)
    except Exception as e:
        logger.error(f"get_marzban_user_proxy error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/ping', methods=['GET'])
def ping():
    """Latency check для Flutter-приложения."""
    return jsonify({'status': 'ok', 'ts': datetime.utcnow().isoformat()})
