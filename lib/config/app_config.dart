class AppConfig {
  static const String baseUrl = 'https://api.gobt.in/api';
  static const String imageBaseUrl = 'https://api.gobt.in';  // for /uploads/... paths
  static const String appName = 'PizzaHap';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

class AppColors {
  static const primary = 0xFFCC1F1F;
  static const primaryDark = 0xFF991515;
  static const primaryLight = 0xFFE84040;
  static const accent = 0xFFFF6B35;
  static const background = 0xFFFAF7F4;
  static const surface = 0xFFFFFFFF;
  static const card = 0xFFFFFFFF;
  static const textPrimary = 0xFF1A1A1A;
  static const textSecondary = 0xFF666666;
  static const textHint = 0xFF999999;
  static const divider = 0xFFEEEEEE;
  static const success = 0xFF27AE60;
  static const warning = 0xFFF39C12;
  static const error = 0xFFE74C3C;
  static const vegGreen = 0xFF27AE60;
  static const nonVegRed = 0xFFCC1F1F;
  static const coins = 0xFFFFB300;
}

class AppStrings {
  static const sendOtp = '/auth/send-otp';
  static const resendOtp = '/auth/resend-otp';
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const refreshToken = '/auth/refresh-token';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const updateProfile = '/auth/profile';

  static const locations = '/locations';
  static const nearestLocation = '/locations/nearest';

  static const categories = '/menu/categories';
  static const products = '/menu/products';
  static const featuredProducts = '/menu/products/featured';
  static const toppings = '/menu/toppings';
  static const crusts = '/menu/crusts';

  static const calculateOrder = '/orders/calculate';
  static const orders = '/orders';
  static const coins = '/orders/coins';

  static const coupons = '/coupons';
  static const validateCoupon = '/coupons/validate';

  static const notifications = '/notifications';
  static const markAllRead = '/notifications/read-all';

  static const supportTickets = '/support/tickets';

  static const refundRequest = '/refunds/request';
  static const myRefunds = '/refunds/my-refunds';

  static const createPayment = '/payments/create-order';
  static const verifyPayment = '/payments/verify';

  static const ratings = '/ratings';
}
