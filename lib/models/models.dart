String? _buildImageUrl(dynamic raw) {
  if (raw == null) return null;
  final str = raw.toString().trim();
  if (str.isEmpty) return null;
  const mediaHost = 'https://api.gobt.in';
  if (str.startsWith('https://api.gobt.in')) return str;
  if (str.startsWith('http://') || str.startsWith('https://')) {
    try {
      final uri = Uri.parse(str);
      return mediaHost + uri.path;
    } catch (_) {}
  }
  final sep = str.startsWith('/') ? '' : '/';
  return mediaHost + sep + str;
}

// ─── AUTH MODELS ─────────────────────────────────────────────────

class User {
  final int id;
  final String name;
  final String email;
  final String? mobile;
  final String? profilePicture;
  final String? address;
  final String? addressHouse;
  final String? addressTown;
  final String? addressState;
  final String? addressPincode;
  final double? latitude;
  final double? longitude;
  final int? preferredLocationId;
  final String? preferredLocationName;
  final String? createdAt;
  final int coinBalance;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    this.profilePicture,
    this.address,
    this.addressHouse,
    this.addressTown,
    this.addressState,
    this.addressPincode,
    this.latitude,
    this.longitude,
    this.preferredLocationId,
    this.preferredLocationName,
    this.createdAt,
    this.coinBalance = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        mobile: json['mobile'],
        profilePicture: _buildImageUrl(json['profile_picture']),
        address: json['address'],
        addressHouse: json['address_house'],
        addressTown: json['address_town'],
        addressState: json['address_state'],
        addressPincode: json['address_pincode'],
        latitude: _parseDoubleOrNull(json['latitude']),
        longitude: _parseDoubleOrNull(json['longitude']),
        preferredLocationId: json['preferred_location_id'],
        preferredLocationName: json['preferred_location_name'],
        createdAt: json['created_at'],
        coinBalance: json['coin_balance'] != null
            ? (json['coin_balance'] as num).toInt()
            : 0,
      );

  String get fullAddress {
    final parts = [addressHouse, addressTown, addressState, addressPincode]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return address ?? '';
  }

  User copyWith({
    String? name,
    String? mobile,
    String? address,
    String? addressHouse,
    String? addressTown,
    String? addressState,
    String? addressPincode,
    int? preferredLocationId,
    int? coinBalance,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email,
        mobile: mobile ?? this.mobile,
        profilePicture: profilePicture,
        address: address ?? this.address,
        addressHouse: addressHouse ?? this.addressHouse,
        addressTown: addressTown ?? this.addressTown,
        addressState: addressState ?? this.addressState,
        addressPincode: addressPincode ?? this.addressPincode,
        latitude: latitude,
        longitude: longitude,
        preferredLocationId: preferredLocationId ?? this.preferredLocationId,
        preferredLocationName: preferredLocationName,
        createdAt: createdAt,
        coinBalance: coinBalance ?? this.coinBalance,
      );
}

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthResponse(
      {required this.user,
      required this.accessToken,
      required this.refreshToken});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: User.fromJson(json['user']),
        accessToken: json['accessToken'] ?? json['access_token'] ?? '',
        refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
      );
}

// ─── LOCATION MODEL ───────────────────────────────────────────────

class Location {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? openingTime;
  final String? closingTime;
  final double? distanceKm;

  Location({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.openingTime,
    this.closingTime,
    this.distanceKm,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'],
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        latitude: _parseDouble(json['latitude']),
        longitude: _parseDouble(json['longitude']),
        phone: json['phone'],
        openingTime: json['opening_time'],
        closingTime: json['closing_time'],
        distanceKm: _parseDoubleOrNull(json['distance_km']),
      );
}

// ─── BANNER MODEL ─────────────────────────────────────────────────

class PromoBanner {
  final int id;
  final String badgeText;
  final String titleText;
  final String gradientStart;
  final String gradientEnd;
  final String iconName;
  final int sortOrder;

  PromoBanner({
    required this.id,
    required this.badgeText,
    required this.titleText,
    required this.gradientStart,
    required this.gradientEnd,
    required this.iconName,
    required this.sortOrder,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        id: json['id'],
        badgeText: json['badge_text'] ?? '',
        titleText: json['title_text'] ?? '',
        gradientStart: json['gradient_start'] ?? '#991515',
        gradientEnd: json['gradient_end'] ?? '#FF6B35',
        iconName: json['icon_name'] ?? 'local_offer',
        sortOrder: json['sort_order'] ?? 0,
      );
}

// ─── MENU MODELS ──────────────────────────────────────────────────

class Category {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;

  Category(
      {required this.id,
      required this.name,
      this.description,
      this.imageUrl,
      required this.sortOrder});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'],
        imageUrl: _buildImageUrl(json['image_url']),
        sortOrder: json['sort_order'] ?? 0,
      );
}

class ProductSize {
  final int id;
  final String sizeName;
  final double price;
  final double effectivePrice;
  final bool isAvailable;

  ProductSize(
      {required this.id,
      required this.sizeName,
      required this.price,
      required this.effectivePrice,
      required this.isAvailable});

  factory ProductSize.fromJson(Map<String, dynamic> json) => ProductSize(
        id: json['id'],
        sizeName: json['size_name'] ?? '',
        price: _parseDouble(json['price']),
        effectivePrice: _parseDouble(json['effective_price'] ?? json['price']),
        isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      );
}

class CrustType {
  final int id;
  final String name;
  final double extraPrice;
  final double effectiveExtraPrice;
  final bool isAvailable;

  CrustType(
      {required this.id,
      required this.name,
      required this.extraPrice,
      required this.effectiveExtraPrice,
      required this.isAvailable});

  factory CrustType.fromJson(Map<String, dynamic> json) => CrustType(
        id: json['id'],
        name: json['name'] ?? '',
        extraPrice: _parseDouble(json['extra_price']),
        effectiveExtraPrice: _parseDouble(json['effective_extra_price'] ?? json['extra_price']),
        isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      );
}

class Topping {
  final int id;
  final String name;
  final double price;
  final double effectivePrice;
  final bool isVeg;
  final bool isAvailable;

  Topping(
      {required this.id,
      required this.name,
      required this.price,
      required this.effectivePrice,
      required this.isVeg,
      required this.isAvailable});

  factory Topping.fromJson(Map<String, dynamic> json) => Topping(
        id: json['id'],
        name: json['name'] ?? '',
        price: _parseDouble(json['price']),
        effectivePrice: _parseDouble(json['effective_price'] ?? json['price']),
        isVeg: json['is_veg'] == 1 || json['is_veg'] == true,
        isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      );
}

class Product {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final int categoryId;
  final String? categoryName;
  final bool isVeg;
  final bool isFeatured;
  final bool isAvailable;
  final double? avgRating;
  final int? reviewCount;
  final List<ProductSize> sizes;
  final List<CrustType> crusts;
  final List<Topping> toppings;
  final bool? locationAvailable;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.basePrice,
    required this.categoryId,
    this.categoryName,
    required this.isVeg,
    required this.isFeatured,
    required this.isAvailable,
    this.avgRating,
    this.reviewCount,
    this.sizes = const [],
    this.crusts = const [],
    this.toppings = const [],
    this.locationAvailable,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'],
        imageUrl: _buildImageUrl(json['image_url']),
        basePrice: _parseDouble(json['base_price']),
        categoryId: json['category_id'] ?? 0,
        categoryName: json['category_name'],
        isVeg: json['is_veg'] == 1 || json['is_veg'] == true,
        isFeatured: json['is_featured'] == 1 || json['is_featured'] == true,
        isAvailable: json['is_available'] == 1 || json['is_available'] == true,
        avgRating: json['avg_rating'] != null
            ? _parseDouble(json['avg_rating'])
            : null,
        reviewCount: json['review_count'],
        sizes: (json['sizes'] as List<dynamic>?)
                ?.map((s) => ProductSize.fromJson(s))
                .toList() ??
            [],
        crusts: (json['crusts'] as List<dynamic>?)
                ?.map((c) => CrustType.fromJson(c))
                .toList() ??
            [],
        toppings: (json['toppings'] as List<dynamic>?)
                ?.map((t) => Topping.fromJson(t))
                .toList() ??
            [],
        locationAvailable: json['location_available'] != null
            ? (json['location_available'] == 1 ||
                json['location_available'] == true)
            : null,
      );
}

// ─── CART MODELS ──────────────────────────────────────────────────

class CartItem {
  final Product product;
  final ProductSize size;
  final CrustType? crust;
  final List<Topping> selectedToppings;
  int quantity;
  final String? specialInstructions;

  CartItem({
    required this.product,
    required this.size,
    this.crust,
    this.selectedToppings = const [],
    this.quantity = 1,
    this.specialInstructions,
  });

  double get unitPrice {
    double price = size.effectivePrice;
    if (crust != null) price += crust!.effectiveExtraPrice;
    for (final t in selectedToppings) {
      price += t.effectivePrice;
    }
    return price;
  }

  double get totalPrice => unitPrice * quantity;

  String get uniqueKey =>
      '${product.id}-${size.id}-${crust?.id}-${selectedToppings.map((t) => t.id).join(',')}';

  Map<String, dynamic> toOrderJson() => {
        'product_id': product.id,
        'size_id': size.id,
        if (crust != null) 'crust_id': crust!.id,
        'toppings': selectedToppings.map((t) => t.id).toList(),
        'quantity': quantity,
        if (specialInstructions != null)
          'special_instructions': specialInstructions,
      };
}

// ─── ORDER MODELS ─────────────────────────────────────────────────

class OrderCalculation {
  final double subtotal;
  final double discountAmount;
  final double deliveryFee;
  final double taxAmount;
  final double totalAmount;
  final double coinsDiscount;
  final int availableCoins;

  OrderCalculation({
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.taxAmount,
    required this.totalAmount,
    this.coinsDiscount = 0,
    this.availableCoins = 0,
  });

  factory OrderCalculation.fromJson(Map<String, dynamic> json) =>
      OrderCalculation(
        subtotal: _parseDouble(json['subtotal']),
        discountAmount: _parseDouble(json['discount_amount']),
        deliveryFee: _parseDouble(json['delivery_fee']),
        taxAmount: _parseDouble(json['tax_amount']),
        totalAmount: _parseDouble(json['total_amount']),
        coinsDiscount: _parseDouble(json['coins_discount']),
        availableCoins: json['available_coins'] != null
            ? (json['available_coins'] as num).toInt()
            : 0,
      );
}

class OrderItem {
  final int id;
  final String productName;
  final String sizeName;
  final String? crustName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? imageUrl;
  final List<dynamic> toppings;

  OrderItem({
    required this.id,
    required this.productName,
    required this.sizeName,
    this.crustName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.imageUrl,
    this.toppings = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] ?? 0,
        productName: json['product_name'] ?? '',
        sizeName: json['size_name'] ?? '',
        crustName: json['crust_name'],
        quantity: json['quantity'] ?? 1,
        unitPrice: _parseDouble(json['unit_price']),
        totalPrice: _parseDouble(json['total_price']),
        imageUrl: _buildImageUrl(json['image_url']),
        toppings: json['toppings'] ?? [],
      );
}

class OrderStatusHistory {
  final String status;
  final String? note;
  final String createdAt;

  OrderStatusHistory(
      {required this.status, this.note, required this.createdAt});

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) =>
      OrderStatusHistory(
        status: json['status'] ?? '',
        note: json['note'],
        createdAt: json['created_at'] ?? '',
      );
}

class OrderFeedback {
  final int id;
  final int foodRating;
  final int? deliveryRating;
  final int overallRating;
  final String? comment;
  final String createdAt;

  OrderFeedback({
    required this.id,
    required this.foodRating,
    this.deliveryRating,
    required this.overallRating,
    this.comment,
    required this.createdAt,
  });

  factory OrderFeedback.fromJson(Map<String, dynamic> json) => OrderFeedback(
        id: json['id'] ?? 0,
        foodRating: json['food_rating'] ?? 0,
        deliveryRating: json['delivery_rating'],
        overallRating: json['overall_rating'] ?? 0,
        comment: json['comment'],
        createdAt: json['created_at'] ?? '',
      );
}

class Order {
  final int id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String deliveryType;
  final String? deliveryAddress;
  final double subtotal;
  final double discountAmount;
  final double deliveryFee;
  final double taxAmount;
  final double totalAmount;
  final int coinsRedeemed;
  final int coinsEarned;
  final String? locationName;
  final String? specialInstructions;
  final String createdAt;
  final List<OrderItem> items;
  final List<OrderStatusHistory> statusHistory;
  final OrderFeedback? feedback;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod = 'online',
    required this.deliveryType,
    this.deliveryAddress,
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.taxAmount,
    required this.totalAmount,
    this.coinsRedeemed = 0,
    this.coinsEarned = 0,
    this.locationName,
    this.specialInstructions,
    required this.createdAt,
    this.items = const [],
    this.statusHistory = const [],
    this.feedback,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] ?? 0,
        orderNumber: json['order_number'] ?? '',
        status: json['status'] ?? '',
        paymentStatus: json['payment_status'] ?? '',
        paymentMethod: json['payment_method'] ?? 'online',
        deliveryType: json['delivery_type'] ?? 'delivery',
        deliveryAddress: json['delivery_address'],
        subtotal: _parseDouble(json['subtotal']),
        discountAmount: _parseDouble(json['discount_amount']),
        deliveryFee: _parseDouble(json['delivery_fee']),
        taxAmount: _parseDouble(json['tax_amount']),
        totalAmount: _parseDouble(json['total_amount']),
        coinsRedeemed: json['coins_redeemed'] != null
            ? (json['coins_redeemed'] as num).toInt()
            : 0,
        coinsEarned: json['coins_earned'] != null
            ? (json['coins_earned'] as num).toInt()
            : 0,
        locationName: json['location_name'],
        specialInstructions: json['special_instructions'],
        createdAt: json['created_at'] ?? '',
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => OrderItem.fromJson(i))
                .toList() ??
            [],
        statusHistory: (json['status_history'] as List<dynamic>?)
                ?.map((s) => OrderStatusHistory.fromJson(s))
                .toList() ??
            [],
        feedback: json['feedback'] != null
            ? OrderFeedback.fromJson(json['feedback'])
            : null,
      );

  bool get canCancel => status == 'pending' || status == 'confirmed';
  bool get isDelivered => status == 'delivered';
  bool get isCOD => paymentMethod == 'cash_on_delivery';
  bool get isPaid => paymentStatus == 'paid';
}

// ─── COINS MODELS ─────────────────────────────────────────────────

class CoinTransaction {
  final int id;
  final String type; // earned | redeemed | reverted
  final int coins;
  final String? description;
  final String? orderNumber;
  final String createdAt;

  CoinTransaction({
    required this.id,
    required this.type,
    required this.coins,
    this.description,
    this.orderNumber,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) =>
      CoinTransaction(
        id: json['id'] ?? 0,
        type: json['type'] ?? '',
        coins: json['coins'] != null ? (json['coins'] as num).toInt() : 0,
        description: json['description'],
        orderNumber: json['order_number'],
        createdAt: json['created_at'] ?? '',
      );
}

class CoinWallet {
  final int balance;
  final List<CoinTransaction> transactions;

  CoinWallet({required this.balance, this.transactions = const []});

  factory CoinWallet.fromJson(Map<String, dynamic> json) => CoinWallet(
        balance: json['balance'] != null ? (json['balance'] as num).toInt() : 0,
        transactions: (json['transactions'] as List<dynamic>?)
                ?.map((t) => CoinTransaction.fromJson(t))
                .toList() ??
            [],
      );
}

// ─── COUPON MODEL ─────────────────────────────────────────────────

class Coupon {
  final String code;
  final String? description;
  final String discountType;
  final double discountValue;
  final double minOrderValue;
  final String? validUntil;
  final double? calculatedDiscount;
  final bool isBogo;
  final List<int> applicableProductIds;

  Coupon({
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    this.validUntil,
    this.calculatedDiscount,
    this.isBogo = false,
    this.applicableProductIds = const [],
  });

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        code: json['code'] ?? '',
        description: json['description'],
        discountType: json['discount_type'] ?? 'flat',
        discountValue: _parseDouble(json['discount_value']),
        minOrderValue: _parseDouble(json['min_order_value']),
        validUntil: json['valid_until'],
        calculatedDiscount: json['calculated_discount'] != null
            ? _parseDouble(json['calculated_discount'])
            : null,
        isBogo: json['is_bogo'] == true ||
            json['discount_type'] == 'buy_1_get_1',
        applicableProductIds: json['applicable_product_ids'] != null
            ? List<int>.from(
                (json['applicable_product_ids'] as List).map((e) => e is int ? e : int.parse(e.toString())))
            : [],
      );

  String get displayDiscount => isBogo
      ? 'Buy 1 Get 1 FREE'
      : discountType == 'percentage'
          ? '${discountValue.toInt()}% OFF'
          : '₹${discountValue.toInt()} OFF';
}

// ─── NOTIFICATION MODEL ───────────────────────────────────────────

class AppNotification {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final String? type;
  final int? orderId; // Add this field
  final String createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.type,
    this.orderId, // Add this parameter
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        isRead: json['is_read'] == 1 || json['is_read'] == true,
        type: json['type'],
        orderId: json['order_id'], // Parse order_id from JSON
        createdAt: json['created_at'] ?? '',
      );
}
// ─── SUPPORT MODELS ───────────────────────────────────────────────

class SupportTicket {
  final int id;
  final String ticketNumber;
  final String subject;
  final String category;
  final String status;
  final String? orderNumber;
  final String createdAt;
  final List<SupportMessage> messages;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.category,
    required this.status,
    this.orderNumber,
    required this.createdAt,
    this.messages = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] ?? 0,
        ticketNumber: json['ticket_number'] ?? '',
        subject: json['subject'] ?? '',
        category: json['category'] ?? '',
        status: json['status'] ?? '',
        orderNumber: json['order_number'],
        createdAt: json['created_at'] ?? '',
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => SupportMessage.fromJson(m))
                .toList() ??
            [],
      );
}

class SupportMessage {
  final int id;
  final String message;
  final String senderRole;
  final String? senderName;
  final String createdAt;

  SupportMessage({
    required this.id,
    required this.message,
    required this.senderRole,
    this.senderName,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] ?? 0,
        message: json['message'] ?? '',
        senderRole: json['sender_role'] ?? 'user',
        senderName: json['sender_name'],
        createdAt: json['created_at'] ?? '',
      );
}

// ─── HELPERS ──────────────────────────────────────────────────────

class Pagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  Pagination(
      {required this.total,
      required this.page,
      required this.limit,
      required this.totalPages});

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        total: json['total'] ?? 0,
        page: json['page'] ?? 1,
        limit: json['limit'] ?? 10,
        totalPages: json['totalPages'] ?? 1,
      );
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
