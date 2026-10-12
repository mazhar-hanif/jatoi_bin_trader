import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jatoi_bin_trader/core/business_rules.dart';
import 'package:jatoi_bin_trader/core/routes.dart';
import 'package:jatoi_bin_trader/models/models.dart';
import 'package:jatoi_bin_trader/providers/core_providers.dart';
import 'package:jatoi_bin_trader/services/csv_export_service.dart';
import 'package:jatoi_bin_trader/services/invoice_service.dart';
import 'package:jatoi_bin_trader/services/resilient_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c =
      ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('return paths allow only safe in-app locations', () {
    expect(Routes.safeInternalPath('/orders/JBT-1001?tab=invoice'),
        '/orders/JBT-1001?tab=invoice');
    for (final path in [
      'https://example.com',
      '//example.com/path',
      r'\example.com',
      r'/\example.com',
      '/orders/\u0000bad',
    ]) {
      expect(Routes.safeInternalPath(path), isNull, reason: path);
    }
  });

  test('blocked preference storage falls back to memory', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await openPreferences(
      load: () async => throw StateError('Storage is blocked'),
    );
    expect(prefs.getBool('storage_unavailable'), isTrue);
    await prefs.setString('memory-only', 'available');
    expect(prefs.getString('memory-only'), 'available');
  });

  test('preference writes rejected by a full store continue in memory',
      () async {
    SharedPreferences.setMockInitialValues({});
    storageUnavailableListenable.value = false;
    final originalStore = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = originalStore;
      storageUnavailableListenable.value = false;
    });
    SharedPreferencesStorePlatform.instance =
        ResilientPreferencesStore(_FailingPreferencesStore());
    final prefs = await SharedPreferences.getInstance();

    expect(storageUnavailableListenable.value, isTrue);
    expect(prefs.getBool('storage_unavailable'), isTrue);
    await prefs.setString('saved-in-memory', 'available');
    expect(prefs.getString('saved-in-memory'), 'available');
  });

  test('CSV rows quote and escape cells correctly', () {
    expect(
      encodeCsvRows([
        ['Order', 'Customer'],
        ['JBT-1001', 'Ali "Rice" Khan'],
      ]),
      '"Order","Customer"\r\n"JBT-1001","Ali ""Rice"" Khan"',
    );
  });

  test('invoice PDF bytes can be generated without opening a print dialog',
      () async {
    final bytes = await createOrderInvoicePdf(
      OrderModel(
        id: 'JBT-1001',
        userId: 'user-1',
        userName: 'Test Customer',
        phone: '33000000',
        address: 'Manama, Bahrain',
        payment: 'cod',
        status: 'pending',
        items: const [],
        docs: const [],
        subtotal: 0,
        vat: 0,
        total: 0,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('register, logout, wrong password, login', () async {
    final c = await makeContainer();
    final auth = c.read(authProvider.notifier);
    expect(await auth.register('Ali Khan', 'Ali@Test.com', 'secret1'), isNull);
    expect(c.read(authProvider)?.email, 'ali@test.com');
    expect(await auth.register('Other', 'ali@test.com', 'secret1'),
        'err_email_exists');
    await auth.logout();
    expect(c.read(authProvider), isNull);
    expect(await auth.login('ali@test.com', 'wrong'), 'err_login');
    expect(await auth.login('ali@test.com', 'secret1'), isNull);
    expect(c.read(isAdminProvider), isFalse);
  });

  test('cart totals: subtotal, 10% VAT, total, min order and stock cap',
      () async {
    final c = await makeContainer();
    final p =
        c.read(productsProvider).first; // 10kg bag, 6.500 BHD, min 5, stock 120
    final cart = c.read(cartProvider.notifier);
    cart.add(p);
    expect(c.read(cartCountProvider), 5);
    expect(c.read(cartSubtotalProvider), closeTo(32.5, 1e-9));
    expect(c.read(cartVatProvider), closeTo(3.25, 1e-9));
    expect(c.read(cartTotalProvider), closeTo(35.75, 1e-9));
    cart.setQty(p.id, 1); // below minimum -> raised to minimum
    expect(c.read(cartCountProvider), 5);
    cart.setQty(p.id, 9999); // above stock -> capped
    expect(c.read(cartCountProvider), p.stock);
  });

  test('cart refuses unavailable stock and preserves accepted quote pricing',
      () async {
    final c = await makeContainer();
    await c.read(authProvider.notifier).register(
          'Ali Khan',
          'ali@test.com',
          'secret1',
        );
    final user = c.read(authProvider)!;
    final product = c.read(productsProvider).first;
    final cart = c.read(cartProvider.notifier);

    expect(cart.addQuoted(product, product.minOrderBags, 5.125), isTrue);
    expect(cart.add(product, qty: 1), isTrue);
    expect(c.read(cartProvider)[product.id]!.unitPrice, 5.125);
    expect(c.read(cartProvider)[product.id]!.qty, product.minOrderBags + 1);

    final unavailable = product.withStock(product.minOrderBags - 1);
    c.read(productsProvider.notifier).upsert(unavailable);
    c.read(cartProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(cartProvider.notifier).add(unavailable), isFalse);
    expect(c.read(cartProvider), isEmpty);
    expect(c.read(prefsProvider).getString('cart_${user.id}'), '[]');
    expect(c.read(cartCleanupProvider), contains('cart_removed_unavailable'));
  });

  test('cart undo restores the original quantity and quoted unit price safely',
      () async {
    final c = await makeContainer();
    await c
        .read(authProvider.notifier)
        .register('Ali Khan', 'ali@test.com', 'secret1');
    final product = c.read(productsProvider).first;
    final cart = c.read(cartProvider.notifier);

    expect(cart.addQuoted(product, product.minOrderBags, 5.125), isTrue);
    final snapshot = Map<String, CartItem>.from(c.read(cartProvider));
    cart.remove(product.id);
    expect(cart.restoreSnapshot(snapshot), isTrue);
    expect(c.read(cartProvider)[product.id]!.qty, product.minOrderBags);
    expect(c.read(cartProvider)[product.id]!.unitPrice, 5.125);

    final unavailableSnapshot =
        Map<String, CartItem>.from(c.read(cartProvider));
    cart.remove(product.id);
    c
        .read(productsProvider.notifier)
        .upsert(product.withStock(product.minOrderBags - 1));
    c.read(cartProvider);
    await Future<void>.delayed(Duration.zero);
    expect(cart.restoreSnapshot(unavailableSnapshot), isFalse);
    expect(c.read(cartProvider), isEmpty);
  });

  test('order flow reduces stock; cancelling restores it', () async {
    final c = await makeContainer();
    expect(
        await c.read(authProvider.notifier).login('admin@jatoi.bh', 'admin123'),
        isNull);
    expect(c.read(isAdminProvider), isTrue);
    final p = c.read(productsProvider).first;
    c.read(cartProvider.notifier).add(p);
    final order = c.read(ordersProvider.notifier).place(
          user: c.read(authProvider)!,
          name: 'Test',
          phone: '3300 0000',
          address: 'Manama',
          payment: 'cod',
          items: c.read(cartProvider).values.toList(),
          subtotal: c.read(cartSubtotalProvider),
          vat: c.read(cartVatProvider),
          total: c.read(cartTotalProvider),
        );
    expect(order, isNotNull);
    expect(order!.id, 'JBT-1001');
    expect(c.read(productByIdProvider(p.id))!.stock, p.stock - 5);
    c.read(ordersProvider.notifier).setStatus(order.id, 'cancelled');
    expect(c.read(productByIdProvider(p.id))!.stock, p.stock);
    expect(c.read(myOrdersProvider).length, 1);
  });

  test('order placement rejects aggregated oversell and buyer status jumps',
      () async {
    final c = await makeContainer();
    await c
        .read(authProvider.notifier)
        .register('Buyer', 'buyer@test.com', 'secret1');
    final user = c.read(authProvider)!;
    final product = c.read(productsProvider).first;
    final orders = c.read(ordersProvider.notifier);
    final invalidOrder = orders.place(
      user: user,
      name: user.name,
      phone: '33000000',
      address: 'Manama',
      payment: 'cod',
      items: [
        CartItem(product, product.stock - 1),
        CartItem(product, product.minOrderBags),
      ],
      subtotal: 0,
      vat: 0,
      total: 0,
    );
    expect(invalidOrder, isNull);
    expect(c.read(ordersProvider), isEmpty);
    expect(c.read(productByIdProvider(product.id))!.stock, product.stock);

    final order = orders.place(
      user: user,
      name: user.name,
      phone: '33000000',
      address: 'Manama',
      payment: 'cod',
      items: [CartItem(product, product.minOrderBags)],
      subtotal: 0,
      vat: 0,
      total: 0,
    )!;
    orders.setStatus(order.id, 'confirmed');
    expect(c.read(orderByIdProvider(order.id))!.status, 'pending');
    expect(orders.cancelByBuyer(order.id, user.id), isTrue);
    expect(c.read(productByIdProvider(product.id))!.stock, product.stock);
  });

  test(
      'bank payment is retained and buyer confirms delivery only after shipping',
      () async {
    final c = await makeContainer();
    const bankDetails = BankTransferDetails(
      accountName: 'Jatoi Bin Trader Test',
      bankName: 'Test Bank',
      iban: 'BH00TEST00000000000000',
    );
    await c.read(bankTransferDetailsProvider.notifier).set(bankDetails);
    final auth = c.read(authProvider.notifier);
    await auth.register('Buyer', 'buyer@test.com', 'secret1');
    final buyer = c.read(authProvider)!;
    final product = c.read(productsProvider).first;
    c.read(cartProvider.notifier).add(product);
    final order = c.read(ordersProvider.notifier).place(
          user: buyer,
          name: buyer.name,
          phone: '33000000',
          address: 'Manama',
          payment: 'bank',
          items: c.read(cartProvider).values.toList(),
          subtotal: c.read(cartSubtotalProvider),
          vat: c.read(cartVatProvider),
          total: c.read(cartTotalProvider),
        )!;

    expect(order.payment, 'bank');
    expect(order.paymentStatus, 'pending');
    expect(order.bankTransferDetails?.toMap(), bankDetails.toMap());
    expect(
        c.read(ordersProvider.notifier).confirmBankPayment(order.id), isFalse);
    expect(c.read(ordersProvider.notifier).confirmDelivery(order.id, buyer.id),
        isFalse);
    expect(
      c
          .read(ordersProvider.notifier)
          .reportBankTransfer(order.id, buyer.id, ''),
      isFalse,
    );
    expect(
      c
          .read(ordersProvider.notifier)
          .reportBankTransfer(order.id, buyer.id, 'TEST-REF-1001'),
      isTrue,
    );
    expect(c.read(orderByIdProvider(order.id))!.paymentStatus,
        'transfer_reported');

    await auth.logout();
    expect(await auth.login('admin@jatoi.bh', 'admin123'), isNull);
    expect(
        c.read(ordersProvider.notifier).confirmBankPayment(order.id), isTrue);
    expect(c.read(orderByIdProvider(order.id))!.paymentStatus, 'received');
    c.read(ordersProvider.notifier)
      ..setStatus(order.id, 'confirmed')
      ..setStatus(order.id, 'shipped');

    await auth.logout();
    expect(await auth.login('buyer@test.com', 'secret1'), isNull);
    expect(c.read(orderByIdProvider(order.id))!.payment, 'bank');
    expect(c.read(ordersProvider.notifier).confirmDelivery(order.id, buyer.id),
        isTrue);
    expect(c.read(orderByIdProvider(order.id))!.status, 'delivered');
  });

  test('bank transfer details require a Bahrain IBAN and persist offline',
      () async {
    final c = await makeContainer();
    const incomplete = BankTransferDetails(
      accountName: 'Company',
      bankName: 'Bank',
      iban: '123456',
    );
    expect(incomplete.isComplete, isFalse);

    const complete = BankTransferDetails(
      accountName: 'Company',
      bankName: 'Bank',
      iban: 'BH00TEST00000000000000',
    );
    expect(complete.isComplete, isTrue);
    await c.read(bankTransferDetailsProvider.notifier).set(complete);
    expect(c.read(bankTransferDetailsProvider).toMap(), complete.toMap());
    expect(c.read(prefsProvider).getString('bank_transfer_details'), isNotNull);
  });

  test('product photos and profile avatars survive model serialization', () {
    const product = Product(
      id: 'photo',
      name: 'Photo rice',
      origin: 'India',
      description: '',
      bagKg: 10,
      pricePerBag: 1,
      imageData: 'cGhvdG8=',
    );
    const user = AppUser(
      id: 'buyer',
      name: 'Buyer',
      email: 'buyer@test.com',
      passwordHash: 'hash',
      role: 'buyer',
      avatarData: 'YXZhdGFy',
    );

    expect(Product.fromMap(product.toMap()).imageData, product.imageData);
    expect(AppUser.fromMap(user.toMap()).avatarData, user.avatarData);
  });

  test('bulk tier pricing and BHD VAT round to three decimals', () {
    const product = Product(
      id: 'tiered',
      name: 'Tiered rice',
      origin: 'India',
      description: '',
      bagKg: 10,
      pricePerBag: 1.111,
      priceTiers: [
        PriceTier(minimumBags: 20, discountPercent: 5),
        PriceTier(minimumBags: 50, discountPercent: 8),
      ],
    );
    expect(calculatePrice(product, 19).unitPrice, 1.111);
    final discounted = calculatePrice(product, 50);
    expect(discounted.unitPrice, 1.022);
    expect(discounted.subtotal, 51.1);
    expect(discounted.savings, 4.45);
    final totals = calculateOrderTotals(discounted.subtotal);
    expect(totals.vat, 5.11);
    expect(totals.total, 56.21);
  });

  test('validates Bahrain phone and email; only valid order transitions pass',
      () {
    expect(isValidBahrainPhone('+973 3300 0000'), isTrue);
    expect(isValidBahrainPhone('33000000'), isTrue);
    expect(isValidBahrainPhone('+1 3300 0000'), isFalse);
    expect(isValidEmail('buyer@jatoi.bh'), isTrue);
    expect(isValidEmail('buyer@'), isFalse);
    expect(canTransitionOrder('pending', 'confirmed'), isTrue);
    expect(canTransitionOrder('pending', 'shipped'), isFalse);
    expect(canTransitionOrder('pending', 'cancelled'), isTrue);
    expect(canTransitionOrder('shipped', 'cancelled'), isFalse);
    expect(canTransitionOrder('delivered', 'pending'), isFalse);
  });

  test(
      'order numbers do not repeat after cancelling; invalid jumps notify nobody',
      () async {
    final c = await makeContainer();
    final auth = c.read(authProvider.notifier);
    expect(await auth.login('admin@jatoi.bh', 'admin123'), isNull);
    final user = c.read(authProvider)!;
    final product = c.read(productsProvider).first;
    final cartItem = CartItem(product, product.minOrderBags);
    final orders = c.read(ordersProvider.notifier);
    final first = orders.place(
      user: user,
      name: 'Admin',
      phone: '33000000',
      address: 'Manama',
      payment: 'cod',
      items: [cartItem],
      subtotal: 0,
      vat: 0,
      total: 0,
    )!;
    orders.setStatus(first.id, 'shipped');
    expect(c.read(orderByIdProvider(first.id))!.status, 'pending');
    expect(c.read(unreadNotificationCountProvider), 0);
    orders.setStatus(first.id, 'cancelled');
    expect(c.read(unreadNotificationCountProvider), 1);
    final second = orders.place(
      user: user,
      name: 'Admin',
      phone: '33000000',
      address: 'Manama',
      payment: 'cod',
      items: [cartItem],
      subtotal: 0,
      vat: 0,
      total: 0,
    )!;
    expect(second.id, 'JBT-1002');
    expect(orders.cancelByBuyer(first.id, user.id), isFalse);
  });

  test(
      'legacy passwords migrate to salted hashes and damaged JSON falls back safely',
      () async {
    SharedPreferences.setMockInitialValues({
      'users':
          '[{"id":"u1","name":"Ali","email":"ali@test.com","password":"secret1","role":"buyer"}]',
      'orders': '{broken json',
    });
    final prefs = await SharedPreferences.getInstance();
    await migrateLocalData(prefs);
    final migratedUsers = prefs.getString('users')!;
    expect(migratedUsers, contains('sha256\$'));
    expect(migratedUsers, isNot(contains('"password":"secret1"')));
    expect(prefs.getInt('schema_version'), 2);
    final c =
        ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    expect(c.read(ordersProvider), isEmpty);
    expect(prefs.getBool('storage_corrupted'), isTrue);
    expect(await c.read(authProvider.notifier).login('ali@test.com', 'secret1'),
        isNull);
  });

  test('quote answer can be accepted once and creates a notification',
      () async {
    final c = await makeContainer();
    await c
        .read(authProvider.notifier)
        .register('Ali Khan', 'ali@test.com', 'secret1');
    final user = c.read(authProvider)!;
    final product = c.read(productsProvider).first;
    final quote = Inquiry(
      id: 'Q1',
      userId: user.id,
      userName: user.name,
      email: user.email,
      productId: product.id,
      productName: product.name,
      qty: product.minOrderBags,
      destination: 'Manama',
      notes: '',
      createdAt: DateTime.now(),
    );
    c.read(inquiriesProvider.notifier).add(quote);
    c.read(inquiriesProvider.notifier).answer(
          quote.id,
          pricePerBag: 5.125,
          validUntil: DateTime.now().add(const Duration(days: 5)),
          message: 'Valid for five days',
        );
    expect(c.read(unreadNotificationCountProvider), 1);
    expect(
      c
          .read(inquiriesProvider.notifier)
          .updateBuyerStatus(quote.id, user.id, 'accepted'),
      isTrue,
    );
    expect(c.read(cartProvider)[product.id]!.unitPrice, 5.125);
    expect(
      c
          .read(inquiriesProvider.notifier)
          .updateBuyerStatus(quote.id, user.id, 'accepted'),
      isFalse,
    );
  });
}

class _FailingPreferencesStore extends SharedPreferencesStorePlatform {
  PlatformException _failure() =>
      PlatformException(code: 'storage_unavailable');

  @override
  Future<Map<String, Object>> getAll() async => throw _failure();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw _failure();

  @override
  Future<bool> remove(String key) async => throw _failure();

  @override
  Future<bool> clear() async => throw _failure();
}
