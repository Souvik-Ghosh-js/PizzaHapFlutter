import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static SharedPreferences? _prefs;
  // encryptedSharedPreferences uses Jetpack's EncryptedSharedPreferences instead of the
  // legacy Keystore mode, which is much less prone to losing/invalidating the encryption
  // key when Android kills the process (the cause of "logged out after closing the app").
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String? _accessToken;
  static String? _refreshToken;

  // Completer ensures all concurrent init() calls wait for the same single run
  static Completer<void>? _initCompleter;

  // For locking simultaneous refresh calls
  static Future<bool>? _refreshFuture;

  static Future<void> init() async {
    if (_initCompleter != null) {
      // Already running or done — wait for the same future
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      _prefs ??= await SharedPreferences.getInstance();

      // Secure storage can hang or throw on some Android devices if the KeyStore key was
      // invalidated (e.g. after the OS kills the process). Read each key independently so
      // a decrypt failure on one doesn't block the other, and treat failures as "no token"
      // rather than letting the whole init() bail out.
      _accessToken = await _readKeySafely('access_token');
      _refreshToken = await _readKeySafely('refresh_token');

      _log('=== INIT DEBUG ===');
      _log('Access token exists: ${_accessToken != null}');
      _log('isLoggedIn: $isLoggedIn');

      // Migration logic
      if (_accessToken == null && _prefs != null) {
        _accessToken = _prefs!.getString('access_token');
        _refreshToken = _prefs!.getString('refresh_token');
        if (_accessToken != null && _refreshToken != null) {
          await _storage.write(key: 'access_token', value: _accessToken!);
          await _storage.write(key: 'refresh_token', value: _refreshToken!);
          await _prefs!.remove('access_token');
          await _prefs!.remove('refresh_token');
          _log('Tokens migrated to SecureStorage');
        }
      }
    } catch (e) {
      _log('ApiService init error: $e', isError: true);
      // If secure storage fails, we still proceed as unauthenticated
    } finally {
      _initCompleter!.complete();
    }
  }

  /// Reads a single secure storage key, treating timeouts/decrypt errors as "missing"
  /// instead of throwing — so a corrupted entry never gets mistaken for a deliberate logout.
  static Future<String?> _readKeySafely(String key) async {
    try {
      return await _storage.read(key: key).timeout(const Duration(seconds: 3));
    } catch (e) {
      _log('Secure storage read failed for "$key": $e', isError: true);
      return null;
    }
  }
  static Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    _log('Tokens saved successfully to SecureStorage');
  }
  static Future<bool> restoreSession() async {
    _log('=== RESTORE SESSION ===');
    await init();

    final hasAccessToken = _accessToken != null;
    final hasRefreshToken = _refreshToken != null;

    _log('Access token exists: $hasAccessToken');
    _log('Refresh token exists: $hasRefreshToken');

    if (hasAccessToken && hasRefreshToken) {
      _log('Session restored successfully');
      return true;
    }

    // Try to read directly from secure storage as fallback
    final directAccess = await _storage.read(key: 'access_token');
    final directRefresh = await _storage.read(key: 'refresh_token');

    if (directAccess != null && directRefresh != null) {
      _accessToken = directAccess;
      _refreshToken = directRefresh;
      _log('Session restored directly from secure storage');
      return true;
    }

    _log('No saved session found');
    return false;
  }
  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    _log('Tokens cleared from SecureStorage');
  }

  static bool get isLoggedIn => _accessToken != null;
  static String? get accessToken => _accessToken;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    _log('Response ${response.statusCode}: ${response.request?.url.path}');
    
    // Check if unauthorized
    if (response.statusCode == 401 && _refreshToken != null) {
      _log('401 detected. Attempting token refresh...');
      final refreshed = await _doRefresh();
      if (refreshed) {
        _log('Token refreshed successfully. Requesting caller to retry.');
        throw ApiException('token_refreshed', statusCode: 401);
      }
      _log('Token refresh failed.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid server response (${response.statusCode})');
    }

    if (!(body['success'] ?? false)) {
      final msg = body['message'] ?? 'An error occurred';
      final code = response.statusCode;
      _log('API Error [$code]: $msg', isError: true);
      throw ApiException(msg, statusCode: code);
    }
    return body;
  }

  // Synchronized refresh: if multiple calls trigger refresh simultaneously, 
  // only one actually goes to the server.
  static Future<bool> _doRefresh() async {
    if (_refreshFuture != null) return await _refreshFuture!;

    _refreshFuture = _tryRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      _log('Posting refresh token to server...');
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${AppStrings.refreshToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        await saveTokens(body['data']['accessToken'], body['data']['refreshToken']);
        return true;
      } else {
        _log('Refresh rejected by server: ${body['message']}', isError: true);
        // If server explicitly rejects (401/400), clear everything
        if (response.statusCode == 401 || response.statusCode == 400) {
          await clearTokens();
        }
      }
    } catch (e) {
      _log('Refresh network/system error: $e', isError: true);
      // DO NOT clear tokens for network errors, just fail this attempt.
      // Next attempt might succeed if internet is back.
    }
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

  // ─── GEOFENCE ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkGeofence({required double lat, required double lng}) => _safeRequest(() async {
    final url = '${AppConfig.baseUrl}${AppStrings.checkGeofence}?latitude=$lat&longitude=$lng';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['data'] != null) {
      return body['data'] as Map<String, dynamic>;
    }
    throw ApiException(body['message'] ?? 'Geofence check failed');
  });

  // ─── BANNERS ──────────────────────────────────────────────────────

  static Future<List<PromoBanner>> getBanners() => _safeRequest(() async {
    final url = '${AppConfig.baseUrl}${AppStrings.banners}';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(AppConfig.connectTimeout);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['data'] != null) {
      return (body['data'] as List).map((b) => PromoBanner.fromJson(b)).toList();
    }
    throw ApiException(body['message'] ?? 'Failed to load banners');
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

  static Future<Product> getProduct(int id, {int? locationId}) => _safeRequest(() async {
    var url = '${AppConfig.baseUrl}${AppStrings.products}/$id';
    if (locationId != null) url += '?location_id=$locationId';
    final response = await http.get(
      Uri.parse(url),
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

  /// Initiate online payment — validates order data and returns PayU params
  /// without creating an order in the DB.
  static Future<dynamic> initiateOnlinePayment(Map<String, dynamic> orderData) =>
      _safeRequest(() async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppStrings.initiatePayment}'),
      headers: _headers,
      body: jsonEncode(orderData),
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
