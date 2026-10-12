import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jatoi_bin_trader/main.dart';
import 'package:jatoi_bin_trader/models/models.dart';
import 'package:jatoi_bin_trader/providers/core_providers.dart';
import 'package:jatoi_bin_trader/router.dart';
import 'package:jatoi_bin_trader/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;

  Future<void> pumpApplication(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JatoiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'session': 'admin'});
    final prefs = await SharedPreferences.getInstance();
    container =
        ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  });

  tearDown(() => container.dispose());

  testWidgets('startup failures show bilingual details and reload action',
      (tester) async {
    await tester.pumpWidget(
      const StartupFailureApp(error: 'CanvasKit module load failed'),
    );
    expect(find.textContaining('could not start'), findsOneWidget);
    expect(find.textContaining('تعذر بدء'), findsOneWidget);
    expect(find.text('CanvasKit module load failed'), findsOneWidget);
    expect(find.textContaining('Reload'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets(
      'all registered product, quote, order, profile, and admin routes open',
      (tester) async {
    await pumpApplication(tester);
    final router = container.read(routerProvider);
    const routeCases = <String, String>{
      '/products': 'Products',
      '/saved': 'Products',
      '/products/basmati-1121': 'Basmati 1121',
      '/products/basmati-1121/quote': 'Basmati 1121',
      '/cart': 'Cart',
      '/orders': 'Orders',
      '/orders/JBT-1001': 'Order JBT-1001',
      '/orders/JBT-1001/invoice': 'Order JBT-1001',
      '/profile': 'Profile',
      '/profile/edit': 'Profile',
      '/profile/addresses': 'Profile',
      '/profile/addresses/new': 'Profile',
      '/profile/password': 'Profile',
      '/checkout': 'Checkout',
      '/success/JBT-1001': 'Order complete',
      '/admin': 'Admin',
      '/admin/products': 'Admin',
      '/admin/products/new': 'Admin',
      '/admin/products/basmati-1121': 'Admin',
      '/admin/orders': 'Admin',
      '/admin/customers': 'Admin',
      '/admin/quotes': 'Admin',
      '/admin/settings': 'Admin',
      '/admin/export': 'Admin',
      '/quotes': 'Quotes',
      '/quotes/Q-1001': 'Quotes',
      '/notifications': 'Notifications',
      '/settings': 'Settings',
      '/about': 'About',
    };
    for (final route in routeCases.keys) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Route failed: $route');
      expect(
        find.byKey(ValueKey('route-screen:${routeCases[route]}')),
        findsOneWidget,
        reason: 'Incorrect screen for route: $route',
      );
    }
  });

  testWidgets('unknown URLs display the not-found page', (tester) async {
    await pumpApplication(tester);
    container.read(routerProvider).go('/not-a-route');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('signed-out deep link returns to the requested route after login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container.dispose();
    container =
        ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    await pumpApplication(tester);

    final router = container.read(routerProvider);
    router.go('/orders/JBT-1001?view=invoice');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/orders/JBT-1001?view=invoice',
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@jatoi.bh');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/orders/JBT-1001');
  });

  testWidgets('navigation switches from bottom bar to rail at tablet width',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await pumpApplication(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('catalogue fits requested viewport sizes, themes, and locales',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApplication(tester);
    container.read(routerProvider).go('/products');
    await tester.pumpAndSettle();
    for (final size in [
      const Size(360, 640),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1280, 800),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      for (final locale in ['en', 'ar']) {
        await container.read(localeProvider.notifier).set(locale);
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await container.read(themeModeProvider.notifier).set(mode);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Layout overflow at $size, $locale, $mode',
          );
        }
      }
    }
  });

  testWidgets('demo banner can be dismissed and follows Arabic locale',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: [Locale('en'), Locale('ar')],
        home: DemoBannerFrame(
          key: ValueKey('english'),
          enabled: true,
          child: Text('Screen'),
        ),
      ),
    );
    expect(find.textContaining('Demo version'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo version'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DemoBannerFrame(
          key: ValueKey('arabic'),
          enabled: true,
          child: Text('Screen'),
        ),
      ),
    );
    expect(find.textContaining('نسخة تجريبية'), findsOneWidget);
  });

  testWidgets('first-time signed-out users see onboarding before login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container.dispose();
    container =
        ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    await pumpApplication(tester);
    expect(find.text('Rice supply made simple'), findsOneWidget);
  });

  testWidgets('a buyer is redirected away from admin', (tester) async {
    await container
        .read(authProvider.notifier)
        .register('Buyer', 'buyer@test.com', 'secret1');
    await pumpApplication(tester);
    container.read(routerProvider).go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Admin panel'), findsNothing);
    expect(find.text('Products'), findsWidgets);
  });

  testWidgets('tapping a product opens its complete detail screen',
      (tester) async {
    await pumpApplication(tester);
    container.read(routerProvider).go('/products');
    await tester.pumpAndSettle();
    final product = container.read(productsProvider).first;
    await tester.tap(find.text(product.name).first);
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/products/${product.id}',
    );
    expect(find.text(product.name), findsOneWidget);
    expect(find.text(product.description), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved profile photo is also displayed in the home header',
      (tester) async {
    final auth = container.read(authProvider.notifier);
    await auth.register('Photo Buyer', 'photo@test.com', 'secret1');
    final user = container.read(authProvider)!;
    await auth.updateProfile(
      name: user.name,
      phone: user.phone,
      addresses: user.addresses,
      avatarData: 'YXZhdGFyLWJ5dGVz',
    );
    await pumpApplication(tester);

    final homeAvatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
    expect(homeAvatar.user?.avatarData, 'YXZhdGFyLWJ5dGVz');
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('buyer can confirm delivery of a shipped order', (tester) async {
    final auth = container.read(authProvider.notifier);
    await auth.register('Buyer', 'buyer@test.com', 'secret1');
    final buyer = container.read(authProvider)!;
    final product = container.read(productsProvider).first;
    container.read(cartProvider.notifier).add(product);
    final order = container.read(ordersProvider.notifier).place(
          user: buyer,
          name: buyer.name,
          phone: '33000000',
          address: 'Manama',
          payment: 'cod',
          items: container.read(cartProvider).values.toList(),
          subtotal: container.read(cartSubtotalProvider),
          vat: container.read(cartVatProvider),
          total: container.read(cartTotalProvider),
        )!;
    await auth.logout();
    await auth.login('admin@jatoi.bh', 'admin123');
    container.read(ordersProvider.notifier)
      ..setStatus(order.id, 'confirmed')
      ..setStatus(order.id, 'shipped');
    await auth.logout();
    await auth.login('buyer@test.com', 'secret1');

    await pumpApplication(tester);
    container.read(routerProvider).go('/orders/${order.id}');
    await tester.pumpAndSettle();
    expect(find.text('Confirm delivery'), findsOneWidget);
    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();
    expect(container.read(orderByIdProvider(order.id))!.status, 'delivered');
    expect(find.text('Delivery confirmed. Thank you!'), findsOneWidget);
  });

  testWidgets('switching to Arabic applies right-to-left layout',
      (tester) async {
    await pumpApplication(tester);
    await container.read(localeProvider.notifier).set('ar');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );
  });

  testWidgets('cart proceeds through checkout to a persisted order',
      (tester) async {
    await container.read(bankTransferDetailsProvider.notifier).set(
          const BankTransferDetails(
            accountName: 'Test Company',
            bankName: 'Test Bank',
            iban: 'BH00TEST00000000000000',
          ),
        );
    final product = container.read(productsProvider).first;
    container.read(cartProvider.notifier).add(product);
    await pumpApplication(tester);
    container.read(routerProvider).go('/checkout');
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Buyer');
    await tester.enterText(fields.at(1), '33000000');
    await tester.enterText(fields.at(2), 'Manama, Bahrain');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('Test Company'), findsOneWidget);
    expect(find.text('BH00TEST00000000000000'), findsOneWidget);
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();
    expect(container.read(ordersProvider), hasLength(1));
    expect(container.read(ordersProvider).first.payment, 'bank');
    expect(container.read(cartProvider), isEmpty);
  });
}
