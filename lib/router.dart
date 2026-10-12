import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/routes.dart';
import 'providers/core_providers.dart';
import 'screens/admin_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/home_shell.dart';
import 'screens/inquiry_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/order_success_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quotes_screen.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isPublicCatalog = Routes.publicCatalogEnabled &&
          (loc == Routes.products ||
              RegExp(r'^/products/[^/]+$').hasMatch(loc));
      final publicPaths = {
        Routes.splash,
        Routes.onboarding,
        Routes.login,
        Routes.register,
        Routes.forgotPassword,
      };
      if (user == null) {
        if (publicPaths.contains(loc) || isPublicCatalog) return null;
        final requested = Routes.safeInternalPath(state.uri.toString());
        return requested == null
            ? Routes.login
            : Uri(path: Routes.login, queryParameters: {'from': requested})
                .toString();
      }
      if (publicPaths.contains(loc)) {
        final from = Routes.safeInternalPath(state.uri.queryParameters['from']);
        if (from != null && !publicPaths.contains(Uri.parse(from).path)) {
          return from;
        }
        return Routes.products;
      }
      if (loc.startsWith(Routes.admin) && user.role != 'admin') {
        return Routes.products;
      }
      return null;
    },
    routes: [
      GoRoute(
          path: Routes.splash,
          builder: (c, s) => _titled(s, const SplashScreen())),
      GoRoute(
          path: Routes.onboarding,
          builder: (c, s) => _titled(s, const OnboardingScreen())),
      GoRoute(
          path: Routes.login,
          builder: (c, s) => _titled(s, const LoginScreen())),
      GoRoute(
          path: Routes.register,
          builder: (c, s) => _titled(s, const RegisterScreen())),
      GoRoute(
          path: Routes.forgotPassword,
          builder: (c, s) => _titled(s, const ForgotPasswordScreen())),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.products,
              builder: (c, s) => _titled(s, const ProductsScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (c, s) => _titled(
                    s,
                    ProductDetailScreen(id: s.pathParameters['id']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'quote',
                      builder: (c, s) => _titled(
                        s,
                        InquiryScreen(productId: s.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: Routes.saved,
                  builder: (c, s) => _titled(s, const ProductsScreen()),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.cart,
                builder: (c, s) => _titled(s, const CartScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.orders,
              builder: (c, s) => _titled(s, const OrdersScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (c, s) => _titled(
                    s,
                    OrderDetailScreen(id: s.pathParameters['id']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'invoice',
                      builder: (c, s) => _titled(
                        s,
                        OrderDetailScreen(id: s.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.profile,
                builder: (c, s) => _titled(s, const ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (c, s) => _titled(s, const ProfileScreen()),
                  ),
                  GoRoute(
                    path: 'addresses',
                    builder: (c, s) => _titled(s, const ProfileScreen()),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (c, s) => _titled(s, const ProfileScreen()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'password',
                    builder: (c, s) => _titled(s, const ProfileScreen()),
                  ),
                ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.notifications,
                builder: (c, s) => _titled(s, const NotificationsScreen())),
          ]),
        ],
      ),
      GoRoute(
          path: Routes.checkout,
          parentNavigatorKey: _rootKey,
          builder: (c, s) => _titled(s, const CheckoutScreen())),
      GoRoute(
        path: Routes.successPattern,
        parentNavigatorKey: _rootKey,
        builder: (c, s) => _titled(
          s,
          OrderSuccessScreen(orderId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
          path: Routes.admin,
          parentNavigatorKey: _rootKey,
          builder: (c, s) => _titled(s, const AdminScreen())),
      GoRoute(
          path: Routes.quotes,
          parentNavigatorKey: _rootKey,
          builder: (c, s) => _titled(s, const QuotesScreen())),
      GoRoute(
        path: '/quotes/:id',
        parentNavigatorKey: _rootKey,
        builder: (c, s) => _titled(s, const QuotesScreen()),
      ),
      for (final path in [
        Routes.adminProducts,
        Routes.newAdminProduct,
        Routes.adminOrders,
        Routes.adminCustomers,
        Routes.adminQuotes,
        Routes.adminSettings,
        Routes.adminExport,
        Routes.settings,
        Routes.about,
      ])
        GoRoute(
          path: path,
          parentNavigatorKey: _rootKey,
          builder: (c, s) => _titled(
            s,
            path.startsWith(Routes.admin)
                ? const AdminScreen()
                : const ProfileScreen(),
          ),
        ),
      GoRoute(
        path: '${Routes.adminProducts}/:id',
        parentNavigatorKey: _rootKey,
        builder: (c, s) => _titled(s, const AdminScreen()),
      ),
    ],
    errorBuilder: (context, state) => _titled(
        state,
        Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_outlined, size: 52),
                const SizedBox(height: 12),
                Text('Page not found',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('The page you requested is unavailable.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: () => context.go(Routes.products),
                    child: const Text('Products')),
              ],
            ),
          ),
        )),
  );
});

Widget _titled(GoRouterState state, Widget child) {
  final path = state.uri.path;
  final segments = path.split('/').where((segment) => segment.isNotEmpty);
  final screen = switch (segments.firstOrNull) {
    'products' => segments.length > 1
        ? segments
            .elementAt(1)
            .split('-')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ')
        : 'Products',
    'saved' => 'Products',
    'orders' =>
      segments.length > 1 ? 'Order ${segments.elementAt(1)}' : 'Orders',
    'admin' => 'Admin',
    'cart' => 'Cart',
    'checkout' => 'Checkout',
    'profile' => 'Profile',
    'settings' => 'Settings',
    'about' => 'About',
    'success' => 'Order complete',
    'quotes' => 'Quotes',
    'notifications' => 'Notifications',
    'login' => 'Login',
    'register' => 'Register',
    'onboarding' => 'Welcome',
    'forgot-password' => 'Reset password',
    _ => 'Jatoi Bin Trader',
  };
  final title =
      screen == 'Jatoi Bin Trader' ? screen : '$screen | Jatoi Bin Trader';
  return Title(
    title: title,
    color: const Color(0xFF1B5E20),
    child: KeyedSubtree(
      key: ValueKey('route-screen:$screen'),
      child: child,
    ),
  );
}
