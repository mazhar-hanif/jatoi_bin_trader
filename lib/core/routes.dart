abstract final class Routes {
  static const publicCatalogEnabled = bool.fromEnvironment(
    'PUBLIC_CATALOG',
    defaultValue: false,
  );

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const products = '/products';
  static const saved = '/saved';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const addresses = '/profile/addresses';
  static const newAddress = '/profile/addresses/new';
  static const password = '/profile/password';
  static const settings = '/settings';
  static const about = '/about';
  static const admin = '/admin';
  static const adminProducts = '/admin/products';
  static const newAdminProduct = '/admin/products/new';
  static const adminOrders = '/admin/orders';
  static const adminCustomers = '/admin/customers';
  static const adminQuotes = '/admin/quotes';
  static const adminSettings = '/admin/settings';
  static const adminExport = '/admin/export';
  static const quotes = '/quotes';
  static const notifications = '/notifications';
  static const successPattern = '/success/:id';

  static String product(String id) => '/products/${Uri.encodeComponent(id)}';
  static String loginFrom(String path) =>
      '/login?from=${Uri.encodeQueryComponent(path)}';
  static String quoteRequest(String productId) => '${product(productId)}/quote';
  static String quote(String id) => '/quotes/${Uri.encodeComponent(id)}';
  static String order(String id) => '/orders/${Uri.encodeComponent(id)}';
  static String invoice(String id) => '${order(id)}/invoice';
  static String success(String id) => '/success/${Uri.encodeComponent(id)}';
  static String adminProduct(String id) =>
      '$adminProducts/${Uri.encodeComponent(id)}';

  static String? safeInternalPath(String? value) {
    if (value == null ||
        !value.startsWith('/') ||
        value.startsWith('//') ||
        value.contains('\\') ||
        value.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//')) {
      return null;
    }
    return value;
  }
}
