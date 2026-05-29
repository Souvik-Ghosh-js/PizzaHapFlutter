import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../config/app_config.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId   = 'pizzahap_orders';
  static const _channelName = 'PizzaHap Orders';

  static GlobalKey<NavigatorState>? _navKey;
  static bool _initialized = false;

  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    _navKey = navKey;
    if (_initialized) return;
    _initialized = true;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios     = DarwinInitializationSettings(
        requestAlertPermission : true,
        requestBadgePermission : true,
        requestSoundPermission : true,
      );

      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onTap,
      );

      // Create Android channel with vibration
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance     : Importance.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 100, 300]),
        playSound      : true,
      ));
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  // ── Show a system notification with vibration ─────────────────────────────
  static Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    // Haptic vibration
    await _vibrate();

    try {
      await _plugin.show(
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, _channelName,
            importance      : Importance.high,
            priority        : Priority.high,
            enableVibration : true,
            vibrationPattern: Int64List.fromList([0, 300, 100, 300]),
            color           : const Color(AppColors.primary),
            icon            : '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  // ── Vibrate device ─────────────────────────────────────────────────────────
  static Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern    : [0, 300, 100, 300],
          intensities: [0, 200, 0, 255],
        );
      }
    } catch (_) {}
  }

  // ── Vibrate only (no notification) ────────────────────────────────────────
  static Future<void> vibrate() => _vibrate();

  // ── Handle notification tap → navigate to order ───────────────────────────
  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && _navKey?.currentContext != null) {
      final orderId = int.tryParse(payload);
      if (orderId != null) {
        _navKey!.currentState
            ?.pushNamed('/order-detail', arguments: orderId);
      }
    }
  }

  // ── Trigger notification + vibration for order status update ──────────────
  static Future<void> notifyOrderUpdate({
    required String orderNumber,
    required String status,
    required int orderId,
  }) async {
    final statusText = _statusLabel(status);
    await show(
      title  : 'Order $orderNumber',
      body   : statusText,
      payload: '$orderId',
    );
  }

  // ── COD → "Pay now through UPI" reminders ─────────────────────────────────
  // For cash-on-delivery orders that are still unpaid, nudge the customer to
  // switch to UPI: once when the order is packed (status `preparing`) and twice
  // when it is on the way (status `out_for_delivery`) — 3 reminders in total.
  // Each reminder fires only once per order (persisted), so polling won't repeat
  // them.
  static const _upiTitle = 'Pay now through UPI';
  static const _upiBody =
      'Skip the cash — pay securely through UPI before your order arrives.';

  static Future<void> maybeSendCodUpiReminders(Order order) async {
    // Only nudge unpaid cash-on-delivery orders.
    if (!order.isCOD || order.isPaid) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (order.status == 'preparing') {
        // Packed → 1 reminder.
        final key = 'cod_upi_${order.id}_packed';
        if (prefs.getBool(key) ?? false) return;
        await prefs.setBool(key, true);
        await show(
          title: _upiTitle,
          body: 'Your order is packed! $_upiBody',
          payload: '${order.id}',
          id: _reminderId(order.id, 0),
        );
      } else if (order.status == 'out_for_delivery') {
        // On the way → 2 reminders.
        final key = 'cod_upi_${order.id}_otw';
        if (prefs.getBool(key) ?? false) return;
        await prefs.setBool(key, true);
        await show(
          title: _upiTitle,
          body: 'Your order is on the way! $_upiBody',
          payload: '${order.id}',
          id: _reminderId(order.id, 1),
        );
        await Future.delayed(const Duration(seconds: 2));
        await show(
          title: _upiTitle,
          body: 'Almost there — pay through UPI for a contactless handover.',
          payload: '${order.id}',
          id: _reminderId(order.id, 2),
        );
      }
    } catch (e) {
      debugPrint('COD UPI reminder error: $e');
    }
  }

  // Stable, collision-free notification id per (order, reminder slot).
  static int _reminderId(int orderId, int slot) =>
      (orderId * 10 + slot) % 2147483647;

  static String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':         return 'Your order has been confirmed!';
      case 'preparing':         return 'Your order is being prepared.';
      case 'out_for_delivery':  return 'Your order is out for delivery!';
      case 'delivered':         return 'Your order has been delivered!';
      case 'cancelled':         return 'Your order has been cancelled.';
      default:                  return 'Order status updated: $status';
    }
  }

  // ── Refresh notification count (call from anywhere) ───────────────────────
  static void refreshCount() {
    final ctx = _navKey?.currentContext;
    if (ctx != null) {
      try { ctx.read<NotificationProvider>().load(); } catch (_) {}
    }
  }
}
