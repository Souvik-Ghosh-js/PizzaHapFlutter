import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';

void _log(String message, {bool isError = false}) {
  // ignore: avoid_print
  debugPrint('${isError ? '[ERROR]' : '[API]'}: $message');
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Wrap every http call with this to turn network errors
/// into a clean ApiException instead of an unhandled crash.
Future<T> _safeRequest<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } on ApiException {
    rethrow;
  } on FormatException catch (e) {
    _log('Format error: $e', isError: true);
    throw ApiException('Unexpected response from server.');
  } on TimeoutException {
    _log('Timeout', isError: true);
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    final msg = e.toString();
    _log('Unknown error: $msg', isError: true);
    // CORS on web, SocketException on mobile, etc.
    if (msg.contains('Failed to fetch') || msg.contains('XMLHttpRequest') || msg.contains('CORS')) {
      if (kIsWeb) {
        throw ApiException('Cannot connect to server from browser (CORS). Please use the Android app.');
      }
      throw ApiException('No internet connection. Please check your network.');
    }
    if (msg.contains('SocketException') || msg.contains('No route to host') || msg.contains('Connection refused')) {
      throw ApiException('No internet connection. Please check your network.');
    }
    throw ApiException('Something went wrong. Please try again.');
  }
}

class ApiService {
  static const _storage = FlutterSecureStorage();
  static String? _accessToken;
  static String? _refreshToken;

  static Future<void> init() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    _log('Init - Logged in: ${_accessToken != null}');
  }

  static Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.deleteAll();
  }

  static bool get isLoggedIn => _accessToken != null;
  static String? get accessToken => _accessToken;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    _log('Response ${response.statusCode}: ${response.request?.url.path}');
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid server response (${response.statusCode})');
    }
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) throw ApiException('token_refreshed');
    }
    if (!(body['success'] ?? false)) {
      _log(body['message'] ?? 'Error', isError: true);
      throw ApiException(body['message'] ?? 'An error occurred', statusCode: response.statusCode);
    }
    return body;
  }

  static Future<bool> _tryRefresh() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${AppStrings.refreshToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        await saveTokens(body['data']['accessToken'], body['data']['refreshToken']);
        return true;
      }
    } catch (e) {
      _log('Refresh failed: $e', isError: true);
    }
    await clearTokens();
    return false;
  }

  // ─── AUTH ─────────────────────────────────────────────────────────

  static Future<void> sendOtp(String email) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.sendOtp}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  static Future<void> resendOtp(String email) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.resendOtp}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  static Future<AuthResponse> register(String name, String email, String otp, {String? mobile}) =>
      _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.register}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'otp': otp, if (mobile != null) 'mobile': mobile}),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    final auth = AuthResponse.fromJson(body['data']);
    await saveTokens(auth.accessToken, auth.refreshToken);
    return auth;
  });

  static Future<AuthResponse> login(String email, String otp) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    final auth = AuthResponse.fromJson(body['data']);
    await saveTokens(auth.accessToken, auth.refreshToken);
    return auth;
  });

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}${AppStrings.logout}'),
        headers: _headers,
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
    await clearTokens();
  }

  static Future<User> getMe() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.me}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return User.fromJson(body['data']);
  });

  static Future<void> updateProfile(Map<String, dynamic> data) => _safeRequest(() async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.updateProfile}'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  // ─── LOCATIONS ─────────────────────────────────────────────────────

  static Future<List<Location>> getLocations({double? lat, double? lng}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.locations}';
    if (lat != null && lng != null) url += '?latitude=$lat&longitude=$lng';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['data'] != null) {
      return (body['data'] as List).map((l) => Location.fromJson(l)).toList();
    }
    throw ApiException(body['message'] ?? 'Failed to load locations');
  });

  static Future<Location?> getNearestLocation({double? lat, double? lng}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.nearestLocation}';
    if (lat != null && lng != null) url += '?latitude=$lat&longitude=$lng';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    if (body['data'] == null) return null;
    return Location.fromJson(body['data']);
  });

  // ─── MENU ──────────────────────────────────────────────────────────

  static Future<List<Category>> getCategories() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.categories}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return (body['data'] as List).map((c) => Category.fromJson(c)).toList();
  });

  static Future<Map<String, dynamic>> getProducts({
    int? categoryId, bool? isVeg, String? search, int page = 1, int limit = 20, int? locationId,
  }) => _safeRequest(() async {
    var params = 'page=$page&limit=$limit';
    if (categoryId != null) params += '&category_id=$categoryId';
    if (isVeg != null) params += '&is_veg=$isVeg';
    if (search != null && search.isNotEmpty) params += '&search=${Uri.encodeComponent(search)}';
    if (locationId != null) params += '&location_id=$locationId';
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.products}?$params'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return {
      'products': (body['data'] as List).map((p) => Product.fromJson(p)).toList(),
      'pagination': body['pagination'],
    };
  });

  static Future<List<Product>> getFeaturedProducts({int? locationId}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.featuredProducts}';
    if (locationId != null) url += '?location_id=$locationId';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return (body['data'] as List).map((p) => Product.fromJson(p)).toList();
  });

  static Future<Product> getProduct(int id) => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.products}/$id'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return Product.fromJson(body['data']);
  });

  static Future<List<Topping>> getToppings({bool? isVeg}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.toppings}';
    if (isVeg != null) url += '?is_veg=$isVeg';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return (body['data'] as List).map((t) => Topping.fromJson(t)).toList();
  });

  static Future<List<CrustType>> getCrusts() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.crusts}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return (body['data'] as List).map((c) => CrustType.fromJson(c)).toList();
  });

  // ─── ORDERS ─────────────────────────────────────────────────────────

  static Future<OrderCalculation> calculateOrder(
    List<Map<String, dynamic>> items, {
    String? couponCode, String deliveryType = 'delivery', int coinsToRedeem = 0,
  }) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.calculateOrder}'),
      headers: _headers,
      body: jsonEncode({
        'items': items,
        if (couponCode != null) 'coupon_code': couponCode,
        'delivery_type': deliveryType,
        if (coinsToRedeem > 0) 'coins_to_redeem': coinsToRedeem,
      }),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return OrderCalculation.fromJson(body['data']);
  });

  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.orders}'),
      headers: _headers,
      body: jsonEncode(orderData),
    ).timeout(AppConfig.receiveTimeout);
    final body = await _handleResponse(response);
    return body['data'];
  });

  static Future<Map<String, dynamic>> getOrders({String? status, int page = 1}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.orders}?page=$page';
    if (status != null) url += '&status=$status';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return {
      'orders': (body['data'] as List).map((o) => Order.fromJson(o)).toList(),
      'pagination': body['pagination'],
    };
  });

  static Future<Order> getOrder(int id) => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.orders}/$id'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return Order.fromJson(body['data']);
  });

  static Future<void> cancelOrder(int id, {String? reason}) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.orders}/$id/cancel'),
      headers: _headers,
      body: jsonEncode({'reason': reason ?? 'Cancelled by user'}),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  static Future<List<Map<String, dynamic>>> reorder(int id) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.orders}/$id/reorder'),
      headers: _headers,
      body: jsonEncode({}),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return List<Map<String, dynamic>>.from(body['data']['items']);
  });

  static Future<void> submitOrderFeedback(int orderId, {
    required int foodRating, int? deliveryRating,
    required int overallRating, String? comment,
  }) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.orders}/$orderId/feedback'),
      headers: _headers,
      body: jsonEncode({
        'food_rating': foodRating,
        if (deliveryRating != null) 'delivery_rating': deliveryRating,
        'overall_rating': overallRating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  // ─── COINS ──────────────────────────────────────────────────────────

  static Future<CoinWallet> getCoinWallet() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.coins}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return CoinWallet.fromJson(body['data']);
  });

  // ─── COUPONS ────────────────────────────────────────────────────────

  static Future<List<Coupon>> getCoupons() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.coupons}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return (body['data'] as List).map((c) => Coupon.fromJson(c)).toList();
  });

  static Future<Coupon> validateCoupon(String code, double orderValue) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.validateCoupon}'),
      headers: _headers,
      body: jsonEncode({'code': code, 'order_value': orderValue}),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return Coupon.fromJson(body['data']);
  });

  // ─── PAYMENTS ───────────────────────────────────────────────────────

  static Future<dynamic> createPaymentOrder(int orderId, String paymentMethod) =>
      _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.createPayment}'),
      headers: _headers,
      body: jsonEncode({'order_id': orderId, 'payment_method': paymentMethod}),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return body['data'];
  });

  // ─── NOTIFICATIONS ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.notifications}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return {
      'notifications': (body['data']['notifications'] as List)
          .map((n) => AppNotification.fromJson(n)).toList(),
      'unread_count': body['data']['unread_count'],
    };
  });

  static Future<void> markAllNotificationsRead() => _safeRequest(() async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.markAllRead}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  static Future<void> markNotificationRead(int id) => _safeRequest(() async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.notifications}/$id/read'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  // ─── SUPPORT ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createTicket(Map<String, dynamic> data) =>
      _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.supportTickets}'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return body['data'];
  });

  static Future<List<SupportTicket>> getTickets({String? status}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.supportTickets}';
    if (status != null) url += '?status=$status';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return (body['data'] as List).map((t) => SupportTicket.fromJson(t)).toList();
  });

  static Future<SupportTicket> getTicket(int id) => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.supportTickets}/$id'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return SupportTicket.fromJson(body['data']);
  });

  static Future<void> replyToTicket(int id, String message) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.supportTickets}/$id/reply'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  // ─── REFUNDS ──────────────────────────────────────────────────────────

  static Future<void> requestRefund(int orderId, String reason) => _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.refundRequest}'),
      headers: _headers,
      body: jsonEncode({'order_id': orderId, 'reason': reason}),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });

  static Future<List<dynamic>> getMyRefunds() => _safeRequest(() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.myRefunds}'),
      headers: _headers,
    ).timeout(AppConfig.connectTimeout);
    final body = await _handleResponse(response);
    return body['data'];
  });

  // ─── RATINGS ──────────────────────────────────────────────────────────

  static Future<void> submitRating(int orderId, int productId, int rating, {String? review}) =>
      _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.ratings}'),
      headers: _headers,
      body: jsonEncode({'order_id': orderId, 'product_id': productId, 'rating': rating,
        if (review != null) 'review': review}),
    ).timeout(AppConfig.connectTimeout);
    await _handleResponse(response);
  });
}
