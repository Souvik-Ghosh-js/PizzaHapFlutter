import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

// ─── AUTH PROVIDER ────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;
  bool _sessionExpired = false;
  bool _isInitialized = false;  // Add this flag

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => ApiService.isLoggedIn;
  bool get sessionExpired => _sessionExpired;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) {
      print('AuthProvider already initialized');
      return;
    }

    print('=== AUTH PROVIDER INIT ===');

    // Ensure ApiService is initialized
    await ApiService.init();

    // Try to restore session
    final restored = await ApiService.restoreSession();
    print('Session restored: $restored');

    if (ApiService.isLoggedIn) {
      print('User is logged in, fetching user data...');
      try {
        _user = await ApiService.getMe();
        print('User fetched: ${_user?.name} (ID: ${_user?.id})');
        _sessionExpired = false;
        notifyListeners();
      } on ApiException catch (e) {
        print('Error fetching user: ${e.message} (Status: ${e.statusCode})');
        if (e.message == 'token_refreshed') {
          // Token was refreshed, retry getMe once
          print('Token was refreshed, retrying getMe...');
          try {
            _user = await ApiService.getMe();
            print('User fetched on retry: ${_user?.name}');
            notifyListeners();
          } catch (retryError) {
            print('Retry failed: $retryError');
            if (retryError is ApiException && retryError.statusCode == 401) {
              await ApiService.clearTokens();
              _user = null;
            }
          }
        } else if (e.statusCode == 401) {
          // Only clear if it's a terminal auth failure
          print('401 error, clearing tokens');
          await ApiService.clearTokens();
          _user = null;
        }
      } catch (e) {
        print('Unexpected error: $e');
        // Network or other transient error: keep tokens, let them try later
      }
    } else {
      print('User is NOT logged in, no tokens found');
      _user = null;
    }

    _isInitialized = true;
    notifyListeners();
    print('=== AUTH PROVIDER INIT COMPLETE ===');
  }
  Future<bool> sendOtp(String email) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await ApiService.sendOtp(email);
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", ""); return false;
    } finally { _loading = false; notifyListeners(); }
  }

  Future<bool> resendOtp(String email) async {
    try {
      await ApiService.resendOtp(email);
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    }
  }

  Future<bool> login(String email, String otp) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final auth = await ApiService.login(email, otp);
      _user = auth.user;
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", ""); return false;
    } finally { _loading = false; notifyListeners(); }
  }

  Future<bool> register(String name, String email, String otp, {String? mobile}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final auth = await ApiService.register(name, email, otp, mobile: mobile);
      _user = auth.user;
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", ""); return false;
    } finally { _loading = false; notifyListeners(); }
  }

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await ApiService.updateProfile(data);
      // Refresh user from server to get latest coin_balance + address
      _user = await ApiService.getMe();
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", ""); return false;
    } finally { _loading = false; notifyListeners(); }
  }

  /// Refresh user (e.g. after order delivered to update coin_balance)
  /// Returns false if the session has genuinely expired and tokens are cleared.
  Future<bool> refreshUser() async {
    if (!ApiService.isLoggedIn) return false;
    try {
      _user = await ApiService.getMe();
      _sessionExpired = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.message == 'token_refreshed') {
        // The token was refreshed successfully — retry getMe once
        try {
          _user = await ApiService.getMe();
          _sessionExpired = false;
          notifyListeners();
          return true;
        } catch (_) {
          return true; // still transient
        }
      }
      // If we still have a 401 and tokens are now gone, session truly expired
      if (e.statusCode == 401 && !ApiService.isLoggedIn) {
        _user = null;
        _sessionExpired = true;
        notifyListeners();
        return false;
      }
      return true; // other errors (network, 5xx) are transient — don't log out
    } catch (_) {
      return true; // network errors are transient
    }
  }

  void resetSessionExpired() { _sessionExpired = false; }

  void clearError() { _error = null; notifyListeners(); }
}

// ─── CART PROVIDER ───────────────────────────────────────────────

/// BOGO size ladder — covers both size_code conventions used by the backend
/// ('regular'/'medium'/'large' and 'REG'/'MED'/'LG').
int _sizeRank(String? code, String? name) {
  const ranks = {
    'small': 0, 'sm': 0, 's': 0, 'regular': 0, 'reg': 0, 'r': 0,
    'medium': 1, 'med': 1, 'm': 1,
    'large': 2, 'lg': 2, 'l': 2,
  };
  for (final v in [code, name]) {
    if (v == null) continue;
    final r = ranks[v.trim().toLowerCase()];
    if (r != null) return r;
  }
  return -1;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _appliedCouponCode;
  Coupon? _appliedCoupon;
  int? _selectedLocationId;
  String? _selectedLocationName;
  String _deliveryType = 'delivery';
  String _paymentMethod = 'cash_on_delivery';

  // Structured delivery address
  String? _addressHouse;
  String? _addressTown;
  String? _addressState;
  String? _addressPincode;

  // Coins
  int _coinsToRedeem = 0;
  int _availableCoins = 0;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get couponCode => _appliedCouponCode;
  Coupon? get appliedCoupon => _appliedCoupon;
  int? get selectedLocationId => _selectedLocationId;
  String? get selectedLocationName => _selectedLocationName;
  String get deliveryType => _deliveryType;
  String get paymentMethod => _paymentMethod;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get coinsToRedeem => _coinsToRedeem;
  int get availableCoins => _availableCoins;

  String? get addressHouse => _addressHouse;
  String? get addressTown => _addressTown;
  String? get addressState => _addressState;
  String? get addressPincode => _addressPincode;

  String get deliveryAddressString {
    final parts = [_addressHouse, _addressTown, _addressState, _addressPincode]
        .where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  bool get hasDeliveryAddress => _addressHouse != null && _addressHouse!.isNotEmpty
      && _addressTown != null && _addressTown!.isNotEmpty
      && _addressPincode != null && _addressPincode!.isNotEmpty;

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get deliveryFee => _deliveryType == 'pickup' ? 0 : (subtotal < 300 ? 40 : 0);
  double get discount {
    final coupon = _appliedCoupon;
    if (coupon == null) return 0.0;
    // BOGO adds a free smaller pizza (see bogoFreeItem) instead of cutting money
    if (coupon.isBogo) return 0.0;
    return coupon.calculatedDiscount ?? 0.0;
  }

  /// BOGO reward: a smaller size of the priciest eligible pizza, free —
  /// Large → Medium, Medium → Small. The free pizza is plain (no crust
  /// addon, no toppings). Small sizes never trigger BOGO.
  /// Returns null if nothing qualifies.
  CartItem? get bogoFreeItem {
    final coupon = _appliedCoupon;
    if (coupon == null || !coupon.isBogo) return null;
    final eligible = (coupon.applicableProductIds.isEmpty
            ? _items
            : _items.where((i) => coupon.applicableProductIds.contains(i.product.id)))
        .where((i) => _sizeRank(i.size.sizeCode, i.size.sizeName) >= 1)
        .toList()
      ..sort((a, b) => b.unitPrice.compareTo(a.unitPrice));
    for (final trigger in eligible) {
      final targetRank = _sizeRank(trigger.size.sizeCode, trigger.size.sizeName) - 1;
      for (final s in trigger.product.sizes) {
        if (s.isAvailable && _sizeRank(s.sizeCode, s.sizeName) == targetRank) {
          return CartItem(
            product: trigger.product,
            size: s,
            quantity: 1,
          );
        }
      }
    }
    return null;
  }
  double get coinsDiscount => _coinsToRedeem * 0.5;
  // Backend has NO TAX — total = subtotal - discount - coins_discount + delivery_fee
  double get tax => 0.0;
  double get total => (subtotal - discount - coinsDiscount + deliveryFee).clamp(0.0, double.infinity);

  bool get isEmpty => _items.isEmpty;

  void addItem(CartItem item) {
    final idx = _items.indexWhere((i) => i.uniqueKey == item.uniqueKey);
    if (idx >= 0) { _items[idx].quantity += item.quantity; } else { _items.add(item); }
    notifyListeners();
  }

  void removeItem(int index) { _items.removeAt(index); notifyListeners(); }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) { _items.removeAt(index); } else { _items[index].quantity = quantity; }
    notifyListeners();
  }

  void setLocation(int locationId, String locationName) {
    _selectedLocationId = locationId;
    _selectedLocationName = locationName;
    _persistLocation();
    notifyListeners();
  }

  Future<void> _persistLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedLocationId != null) {
      await prefs.setInt('selected_location_id', _selectedLocationId!);
      await prefs.setString('selected_location_name', _selectedLocationName ?? '');
    } else {
      await prefs.remove('selected_location_id');
      await prefs.remove('selected_location_name');
    }
  }

  /// Restore persisted location on app startup
  Future<void> restoreLocation() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLocationId = prefs.getInt('selected_location_id');
    _selectedLocationName = prefs.getString('selected_location_name');
    if (_selectedLocationId != null) {
      notifyListeners();
    }
  }

  void setDeliveryType(String type) { _deliveryType = type; notifyListeners(); }
  void setPaymentMethod(String method) { _paymentMethod = method; notifyListeners(); }

  void setDeliveryAddress({String? house, String? town, String? state, String? pincode}) {
    _addressHouse = house;
    _addressTown = town;
    _addressState = state;
    _addressPincode = pincode;
    notifyListeners();
  }

  void setAvailableCoins(int coins) { _availableCoins = coins; notifyListeners(); }

  void setCoinsToRedeem(int coins) {
    // Clamp: can't redeem more coins than available, and can't exceed the payable amount
    // 1 coin = ₹0.50, so max coins = payable / 0.5 = payable * 2
    final maxByBalance = coins.clamp(0, _availableCoins);
    final payable = (subtotal - discount + deliveryFee);
    final maxCoinsByPayable = (payable / 0.5).floor();
    _coinsToRedeem = maxByBalance.clamp(0, maxCoinsByPayable);
    notifyListeners();
  }

  void applyCoupon(Coupon coupon) {
    _appliedCouponCode = coupon.code;
    _appliedCoupon = coupon;
    notifyListeners();
  }

  void removeCoupon() {
    _appliedCouponCode = null;
    _appliedCoupon = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> toOrderItems() =>
    _items.map((i) => i.toOrderJson()).toList();

  void clear() {
    _items.clear();
    _appliedCouponCode = null;
    _appliedCoupon = null;
    _coinsToRedeem = 0;
    _addressHouse = null;
    _addressTown = null;
    _addressState = null;
    _addressPincode = null;
    notifyListeners();
  }
}

// ─── MENU PROVIDER ───────────────────────────────────────────────

class MenuProvider extends ChangeNotifier {
  List<Category> _categories = [];
  List<Product> _featuredProducts = [];
  List<Product> _products = [];
  List<Topping> _toppings = [];
  List<CrustType> _crusts = [];
  bool _loading = false;
  String? _error;
  int? _selectedCategoryId;
  int? _selectedLocationId;

  List<Category> get categories => _categories;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get products => _products;
  List<Topping> get toppings => _toppings;
  List<CrustType> get crusts => _crusts;
  bool get loading => _loading;
  String? get error => _error;
  int? get selectedCategoryId => _selectedCategoryId;
  int? get selectedLocationId => _selectedLocationId;

  void setSelectedLocation(int locationId) {
    _selectedLocationId = locationId;
    notifyListeners();
  }

  Future<void> loadHomeData() async {
    _loading = true; _error = null; notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getFeaturedProducts(locationId: _selectedLocationId),
      ]);
      _categories = results[0] as List<Category>;
      _featuredProducts = results[1] as List<Product>;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
    } finally { _loading = false; notifyListeners(); }
  }


  Future<void> loadProducts({int? categoryId, bool? isVeg, String? search}) async {
    _loading = true; _error = null;
    _selectedCategoryId = categoryId;
    notifyListeners();
    try {
      final result = await ApiService.getProducts(
        categoryId: categoryId, isVeg: isVeg, search: search,
        locationId: _selectedLocationId,
      );
      _products = result['products'] as List<Product>;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
    } finally { _loading = false; notifyListeners(); }
  }

  Future<void> loadToppingsAndCrusts() async {
    try {
      final results = await Future.wait([ApiService.getToppings(), ApiService.getCrusts()]);
      _toppings = results[0] as List<Topping>;
      _crusts = results[1] as List<CrustType>;
      notifyListeners();
    } catch (_) {}
  }

  void selectCategory(int? id) {
    _selectedCategoryId = id;
    loadProducts(categoryId: id);
  }
}

// ─── ORDER PROVIDER ───────────────────────────────────────────────

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  Order? _currentOrder;
  Order? _activeOrder; // Latest in-progress order
  bool _loading = false;
  String? _error;

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  Order? get activeOrder => _activeOrder;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadOrders({String? status}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final result = await ApiService.getOrders(status: status);
      _orders = result['orders'] as List<Order>;
      // Refresh active order whenever orders are loaded
      if (status == null) _refreshActiveOrder();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
    } finally { _loading = false; notifyListeners(); }
  }

  /// Load just the latest active (in-progress) order for the home banner.
  Future<void> loadActiveOrder() async {
    try {
      final result = await ApiService.getOrders();
      final all = result['orders'] as List<Order>;
      _refreshActiveOrder(all);
      notifyListeners();
      // Nudge COD customers to pay via UPI as the order progresses.
      final active = _activeOrder;
      if (active != null) {
        await NotificationService.maybeSendCodUpiReminders(active);
      }
    } catch (_) {}
  }

  void _refreshActiveOrder([List<Order>? orders]) {
    final list = orders ?? _orders;
    const active = ['pending', 'confirmed', 'preparing', 'out_for_delivery'];
    _activeOrder = list.where((o) => active.contains(o.status)).firstOrNull;
  }

  Future<Order?> loadOrder(int id) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _currentOrder = await ApiService.getOrder(id);
      return _currentOrder;
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
      return null;
    } finally { _loading = false; notifyListeners(); }
  }


  Future<Order?> getLatestUnreviewedDeliveredOrder() async {
    try {
      final res = await ApiService.getOrders(status: 'delivered');
      final orders = res['orders'] as List<Order>;
      // Find the first order that is delivered but has NO feedback recorded.
      for (final o in orders) {
        if (o.isDelivered && o.feedback == null) return o;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> placeOrder(Map<String, dynamic> data) async {
    _loading = true; _error = null; notifyListeners();
    try {
      return await ApiService.placeOrder(data);
    } catch (e) {
      if (e is ApiException) {
        _error = e.message;
      } else {
        _error = e.toString().replaceAll("Exception: ", "");
      }
      return null;
    } finally { _loading = false; notifyListeners(); }
  }


  Future<bool> cancelOrder(int id, {String? reason}) async {
    try {
      await ApiService.cancelOrder(id, reason: reason);
      await loadOrder(id);
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    }
  }

  void clearError() { _error = null; notifyListeners(); }
}

// ─── COINS PROVIDER ──────────────────────────────────────────────

class CoinsProvider extends ChangeNotifier {
  CoinWallet? _wallet;
  bool _loading = false;

  CoinWallet? get wallet => _wallet;
  int get balance => _wallet?.balance ?? 0;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true; notifyListeners();
    try {
      _wallet = await ApiService.getCoinWallet();
    } catch (_) {}
    _loading = false; notifyListeners();
  }
}

// ─── NOTIFICATION PROVIDER ───────────────────────────────────────

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true; notifyListeners();
    try {
      final result = await ApiService.getNotifications();
      final newNotifs = result['notifications'] as List<AppNotification>;
      final newCount  = result['unread_count'] as int;
      // Vibrate + show local notification if new unread notifications arrived
      if (newCount > _unreadCount && _notifications.isNotEmpty) {
        final latest = newNotifs.first;
        NotificationService.show(
          title  : latest.title,
          body   : latest.message,
          payload: null,
        );
      }
      _notifications = newNotifs;
      _unreadCount   = newCount;
    } catch (_) {}
    _loading = false; notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      _notifications = _notifications.map((n) => AppNotification(
        id: n.id, title: n.title, message: n.message, isRead: true,
        type: n.type, createdAt: n.createdAt,
      )).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
