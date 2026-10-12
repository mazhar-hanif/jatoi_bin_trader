import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../core/business_rules.dart';
import '../core/routes.dart';
import '../data/seed.dart';
import '../models/models.dart';
import '../services/resilient_preferences_store.dart';

final prefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

Future<SharedPreferences> openPreferences({
  Future<SharedPreferences> Function()? load,
}) async {
  final loadPreferences = load ?? SharedPreferences.getInstance;
  try {
    final prefs = await loadPreferences();
    await migrateLocalData(prefs);
    return prefs;
  } catch (error, stackTrace) {
    debugPrint('Preference storage unavailable; using memory storage: $error');
    debugPrintStack(stackTrace: stackTrace);
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.withData({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('storage_unavailable', true);
    storageUnavailableListenable.value = true;
    await migrateLocalData(prefs);
    return prefs;
  }
}

List<Map<String, dynamic>> _readList(SharedPreferences p, String key) {
  final raw = p.getString(key);
  if (raw == null) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Expected a list');
    return decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  } on FormatException {
    p.setBool('storage_corrupted', true);
    p.remove(key);
    return [];
  } on TypeError {
    p.setBool('storage_corrupted', true);
    p.remove(key);
    return [];
  }
}

List<T> _decodeList<T>(
  SharedPreferences prefs,
  String key,
  T Function(Map<String, dynamic>) decode,
) {
  final decoded = <T>[];
  for (final item in _readList(prefs, key)) {
    try {
      decoded.add(decode(item));
    } on FormatException {
      prefs.setBool('storage_corrupted', true);
      prefs.remove(key);
    } on TypeError {
      prefs.setBool('storage_corrupted', true);
      prefs.remove(key);
    } on RangeError {
      prefs.setBool('storage_corrupted', true);
      prefs.remove(key);
    }
  }
  return decoded;
}

String _hashPassword(String password, {String? salt}) {
  // This salted hash is only for the offline demo; real accounts require backend authentication.
  final actualSalt = salt ??
      List<int>.generate(16, (_) => Random.secure().nextInt(256))
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
  final digest = sha256.convert(utf8.encode('$actualSalt:$password'));
  return 'sha256\$$actualSalt\$$digest';
}

bool _verifyPassword(String encoded, String password) {
  final parts = encoded.split(r'$');
  if (parts.length != 3 || parts.first != 'sha256') return false;
  return _hashPassword(password, salt: parts[1]) == encoded;
}

Future<void> migrateLocalData(SharedPreferences prefs) async {
  const currentVersion = 2;
  final version = prefs.getInt('schema_version') ?? 0;
  if (version >= currentVersion) return;
  final users = _readList(prefs, 'users');
  if (users.isNotEmpty) {
    final migrated = users.map((user) {
      final rawHash = user['passwordHash'] ?? user['password'];
      if (rawHash is String && !rawHash.startsWith('sha256\$')) {
        user['passwordHash'] = _hashPassword(rawHash);
        user.remove('password');
      }
      return user;
    }).toList();
    await prefs.setString('users', jsonEncode(migrated));
  }
  await prefs.setInt('schema_version', currentVersion);
}

// ---------------- settings ----------------
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(prefsProvider).getString('lang') ?? 'en');
  Future<void> set(String code) async {
    state = Locale(code);
    await ref.read(prefsProvider).setString('lang', code);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    switch (ref.read(prefsProvider).getString('theme')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    await ref.read(prefsProvider).setString('theme', m.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class VatRegistrationNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.read(prefsProvider).getString('vat_registration_number') ?? '';

  Future<void> set(String value) async {
    state = value.trim();
    await ref.read(prefsProvider).setString('vat_registration_number', state);
  }
}

final vatRegistrationProvider =
    NotifierProvider<VatRegistrationNotifier, String>(
        VatRegistrationNotifier.new);

class BankTransferDetailsNotifier extends Notifier<BankTransferDetails> {
  @override
  BankTransferDetails build() {
    final raw = ref.read(prefsProvider).getString('bank_transfer_details');
    if (raw == null || raw.isEmpty) return const BankTransferDetails();
    try {
      return BankTransferDetails.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const BankTransferDetails();
    } on TypeError {
      return const BankTransferDetails();
    }
  }

  Future<void> set(BankTransferDetails value) async {
    state = value;
    await ref.read(prefsProvider).setString(
          'bank_transfer_details',
          jsonEncode(value.toMap()),
        );
  }
}

final bankTransferDetailsProvider =
    NotifierProvider<BankTransferDetailsNotifier, BankTransferDetails>(
  BankTransferDetailsNotifier.new,
);

class LowStockThresholdNotifier extends Notifier<int> {
  @override
  int build() => ref.read(prefsProvider).getInt('low_stock_threshold') ?? 20;

  Future<void> set(int value) async {
    state = value.clamp(1, 100000);
    await ref.read(prefsProvider).setInt('low_stock_threshold', state);
  }
}

final lowStockThresholdProvider =
    NotifierProvider<LowStockThresholdNotifier, int>(
        LowStockThresholdNotifier.new);

final stockHistoryProvider = Provider<List<Map<String, dynamic>>>(
  (ref) {
    ref.watch(productsProvider);
    return _readList(ref.read(prefsProvider), 'stock_history');
  },
);

// ---------------- auth (local demo accounts) ----------------
class AuthNotifier extends Notifier<AppUser?> {
  SharedPreferences get _p => ref.read(prefsProvider);

  List<AppUser> _users() {
    final list = _decodeList(_p, 'users', AppUser.fromMap);
    return list.isEmpty ? [demoAdmin] : list;
  }

  Future<void> _saveUsers(List<AppUser> u) =>
      _p.setString('users', jsonEncode(u.map((e) => e.toMap()).toList()));

  @override
  AppUser? build() {
    final id = _p.getString('session');
    if (id == null) return null;
    for (final u in _users()) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Returns an error key, or null on success.
  Future<String?> login(String email, String password) async {
    final e = email.trim().toLowerCase();
    for (final u in _users()) {
      if (u.email == e && _verifyPassword(u.passwordHash, password)) {
        state = u;
        await _p.setString('session', u.id);
        return null;
      }
    }
    return 'err_login';
  }

  Future<String?> register(String name, String email, String password) async {
    final e = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'required';
    if (!isValidEmail(e)) return 'invalid_email';
    if (password.length < 6) return 'pass_min';
    final users = _users();
    if (users.any((u) => u.email == e)) return 'err_email_exists';
    final u = AppUser(
        id: 'u${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        email: e,
        passwordHash: _hashPassword(password),
        role: 'buyer');
    await _saveUsers([...users, u]);
    state = u;
    await _p.setString('session', u.id);
    return null;
  }

  Future<void> logout() async {
    state = null;
    await _p.remove('session');
  }

  Future<String?> changePassword(String oldPassword, String newPassword) async {
    final user = state;
    if (user == null || !_verifyPassword(user.passwordHash, oldPassword)) {
      return 'err_old_password';
    }
    if (newPassword.length < 6) return 'pass_min';
    await _replaceUser(user.copyWith(passwordHash: _hashPassword(newPassword)));
    return null;
  }

  Future<String?> resetPassword(String email, String newPassword) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !isValidEmail(normalized)) return 'invalid_email';
    if (newPassword.length < 6) return 'pass_min';
    final users = _users();
    final index = users.indexWhere((user) => user.email == normalized);
    if (index < 0) return 'err_login';
    final updated =
        users[index].copyWith(passwordHash: _hashPassword(newPassword));
    await _saveUsers(
        users.map((user) => user.id == updated.id ? updated : user).toList());
    if (state?.id == updated.id) state = updated;
    return null;
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required List<DeliveryAddress> addresses,
    String? avatarData,
    bool clearAvatar = false,
  }) async {
    final user = state;
    if (user == null) return;
    await _replaceUser(user.copyWith(
      name: name,
      phone: phone,
      addresses: addresses,
      avatarData: avatarData,
      clearAvatar: clearAvatar,
    ));
  }

  Future<void> _replaceUser(AppUser updated) async {
    final users =
        _users().map((user) => user.id == updated.id ? updated : user).toList();
    await _saveUsers(users);
    state = updated;
  }

  List<AppUser> customers() =>
      _users().where((user) => user.role == 'buyer').toList();
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
final isAdminProvider =
    Provider<bool>((ref) => ref.watch(authProvider)?.role == 'admin');
final customersProvider = Provider<List<AppUser>>((ref) {
  ref.watch(authProvider);
  return ref.read(authProvider.notifier).customers();
});

// ---------------- products ----------------
class ProductsNotifier extends Notifier<List<Product>> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  List<Product> build() {
    if (!_p.containsKey('products')) return sampleProducts;
    final list = _decodeList(_p, 'products', Product.fromMap);
    if (list.isEmpty && _p.getString('products') != '[]') return sampleProducts;
    return list;
  }

  void _save() => _p.setString(
      'products', jsonEncode(state.map((e) => e.toMap()).toList()));

  void upsert(Product p) {
    final id =
        p.id.isEmpty ? 'p${DateTime.now().millisecondsSinceEpoch}' : p.id;
    final np = p.withId(id);
    final i = state.indexWhere((x) => x.id == id);
    if (i < 0) {
      state = [...state, np];
    } else {
      final stockChange = np.stock - state[i].stock;
      if (stockChange != 0) {
        final history = _readList(_p, 'stock_history');
        history.insert(0, {
          'productId': id,
          'productName': np.name,
          'change': stockChange,
          'who': ref.read(authProvider)?.email ?? 'system',
          'reason': 'Admin product edit',
          'when': DateTime.now().toIso8601String(),
        });
        _p.setString('stock_history', jsonEncode(history.take(500).toList()));
      }
      final c = [...state];
      c[i] = np;
      state = c;
    }
    _save();
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
    _save();
  }

  void adjustStock(
    Map<String, int> delta, {
    String reason = 'manual adjustment',
  }) {
    final user = ref.read(authProvider);
    final history = _readList(_p, 'stock_history');
    for (final product in state) {
      final change = delta[product.id] ?? 0;
      if (change == 0) continue;
      history.insert(0, {
        'productId': product.id,
        'productName': product.name,
        'change': change,
        'who': user?.email ?? 'system',
        'reason': reason,
        'when': DateTime.now().toIso8601String(),
      });
    }
    state = [
      for (final p in state)
        delta.containsKey(p.id)
            ? p.withStock(max(0, p.stock + delta[p.id]!))
            : p
    ];
    _save();
    _p.setString('stock_history', jsonEncode(history.take(500).toList()));
  }
}

final productsProvider =
    NotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

final productByIdProvider = Provider.family<Product?, String>((ref, id) {
  for (final p in ref.watch(productsProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      (ref.read(prefsProvider).getStringList('favorites') ?? []).toSet();
  void toggle(String id) {
    final s = {...state};
    if (!s.remove(id)) s.add(id);
    state = s;
    ref.read(prefsProvider).setStringList('favorites', s.toList());
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

// ---------------- cart ----------------
final cartCleanupProvider = StateProvider<List<String>>((ref) => const []);

class CartNotifier extends Notifier<Map<String, CartItem>> {
  String? _storageKey;

  @override
  Map<String, CartItem> build() {
    final user = ref.watch(authProvider);
    final products = ref.watch(productsProvider);
    if (user == null) {
      _storageKey = null;
      return {};
    }
    _storageKey = 'cart_${user.id}';
    final raw = ref.read(prefsProvider).getString(_storageKey!);
    if (raw == null) return {};
    try {
      final stored = jsonDecode(raw);
      if (stored is! List) throw const FormatException('Expected a list');
      final validProducts = {
        for (final product in products) product.id: product
      };
      final result = <String, CartItem>{};
      final removed = <String>[];
      final adjusted = <String>[];
      for (final entry in stored.whereType<Map>()) {
        final id = entry['productId'];
        final qty = entry['qty'];
        if (id is! String || qty is! int) continue;
        final product = validProducts[id];
        if (product == null ||
            !product.active ||
            product.stock < product.minOrderBags ||
            qty < product.minOrderBags) {
          removed.add(product?.name ?? (entry['name'] as String? ?? ''));
          continue;
        }
        final acceptedQty = min(qty, product.stock);
        if (acceptedQty != qty) adjusted.add(product.name);
        final quotePrice = (entry['quotedUnitPrice'] as num?)?.toDouble();
        result[id] =
            _pricedItem(product, acceptedQty, quotedUnitPrice: quotePrice);
      }
      final cleanupMessages = [
        if (removed.isNotEmpty) 'cart_removed_unavailable',
        if (adjusted.isNotEmpty) 'cart_quantity_adjusted',
      ];
      if (cleanupMessages.isNotEmpty) {
        _persistItems(result);
        Future.microtask(() {
          ref.read(cartCleanupProvider.notifier).state = cleanupMessages;
        });
      } else if (ref.read(cartCleanupProvider).isNotEmpty) {
        Future.microtask(() {
          ref.read(cartCleanupProvider.notifier).state = const [];
        });
      }
      return result;
    } on FormatException {
      ref.read(prefsProvider).setBool('storage_corrupted', true);
      ref.read(prefsProvider).remove(_storageKey!);
      return {};
    } on TypeError {
      ref.read(prefsProvider).setBool('storage_corrupted', true);
      ref.read(prefsProvider).remove(_storageKey!);
      return {};
    }
  }

  CartItem _pricedItem(Product product, int quantity,
      {double? quotedUnitPrice}) {
    if (quotedUnitPrice != null) {
      return CartItem(product, quantity, quotedUnitPrice: quotedUnitPrice);
    }
    final price = calculatePrice(product, quantity);
    return CartItem(
      product,
      quantity,
      tierUnitPrice: price.unitPrice,
      appliedTier: price.appliedTier,
      savings: price.savings,
    );
  }

  void _persist() {
    _persistItems(state);
  }

  void _persistItems(Map<String, CartItem> items) {
    final key = _storageKey;
    if (key == null) return;
    ref.read(prefsProvider).setString(
          key,
          jsonEncode([
            for (final entry in items.entries)
              {
                'productId': entry.key,
                'name': entry.value.product.name,
                'qty': entry.value.qty,
                'quotedUnitPrice': entry.value.quotedUnitPrice,
              }
          ]),
        );
  }

  /// Adds [qty] bags (default = minimum order). Capped at stock.
  bool add(Product p, {int? qty}) {
    final current = ref.read(productsProvider).where((item) => item.id == p.id);
    if (current.isEmpty || !current.first.active) return false;
    p = current.first;
    if (p.stock < p.minOrderBags) return false;
    final existing = state[p.id];
    final add = qty ?? p.minOrderBags;
    final next = min(p.stock, max(p.minOrderBags, (existing?.qty ?? 0) + add));
    if (next <= (existing?.qty ?? 0)) return false;
    state = {
      ...state,
      p.id: _pricedItem(p, next, quotedUnitPrice: existing?.quotedUnitPrice),
    };
    _persist();
    return true;
  }

  void setQty(String id, int qty) {
    final item = state[id];
    if (item == null) return;
    final product = ref.read(productsProvider).where((entry) => entry.id == id);
    if (product.isEmpty ||
        !product.first.active ||
        product.first.stock < product.first.minOrderBags) {
      remove(id);
      return;
    }
    final p = product.first;
    final q = min(p.stock, max(p.minOrderBags, qty));
    state = {
      ...state,
      id: _pricedItem(p, q, quotedUnitPrice: item.quotedUnitPrice),
    };
    _persist();
  }

  bool addQuoted(Product product, int qty, double price) {
    final current =
        ref.read(productsProvider).where((item) => item.id == product.id);
    if (state.containsKey(product.id) ||
        current.isEmpty ||
        !current.first.active ||
        qty < current.first.minOrderBags ||
        qty > current.first.stock ||
        !price.isFinite ||
        price <= 0) {
      return false;
    }
    state = {
      ...state,
      product.id: CartItem(current.first, qty, quotedUnitPrice: price),
    };
    _persist();
    return true;
  }

  void remove(String id) {
    state = {...state}..remove(id);
    _persist();
  }

  bool restoreSnapshot(Map<String, CartItem> snapshot) {
    final products = {
      for (final product in ref.read(productsProvider)) product.id: product
    };
    final restored = {...state};
    var complete = true;

    for (final entry in snapshot.entries) {
      if (restored.containsKey(entry.key)) {
        complete = false;
        continue;
      }
      final product = products[entry.key];
      final item = entry.value;
      if (product == null ||
          !product.active ||
          product.stock < product.minOrderBags ||
          item.qty < product.minOrderBags ||
          item.qty > product.stock) {
        complete = false;
        continue;
      }
      restored[entry.key] = _pricedItem(
        product,
        item.qty,
        quotedUnitPrice: item.quotedUnitPrice,
      );
    }

    state = restored;
    _persist();
    return complete;
  }

  void clear() {
    state = {};
    _persist();
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, Map<String, CartItem>>(CartNotifier.new);
final cartCountProvider = Provider<int>(
    (ref) => ref.watch(cartProvider).values.fold(0, (s, i) => s + i.qty));
final cartSubtotalProvider =
    Provider<double>((ref) => roundBhd(ref.watch(cartProvider).values.fold(
          0.0,
          (sum, item) => sum + lineTotal(item.unitPrice, item.qty),
        )));
final cartVatProvider = Provider<double>(
    (ref) => calculateOrderTotals(ref.watch(cartSubtotalProvider)).vat);
final cartTotalProvider = Provider<double>(
    (ref) => calculateOrderTotals(ref.watch(cartSubtotalProvider)).total);

// ---------------- orders ----------------
class OrdersNotifier extends Notifier<List<OrderModel>> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  List<OrderModel> build() => _decodeList(_p, 'orders', OrderModel.fromMap);

  void _save() =>
      _p.setString('orders', jsonEncode(state.map((e) => e.toMap()).toList()));

  /// Returns null if stock is no longer enough.
  OrderModel? place({
    required AppUser user,
    required String name,
    required String phone,
    required String address,
    required String payment,
    required List<CartItem> items,
    required double subtotal,
    required double vat,
    required double total,
    DateTime? deliveryDate,
    String notes = '',
    BankTransferDetails? bankTransferDetails,
  }) {
    final products = ref.read(productsProvider);
    final BankTransferDetails transferDetails =
        bankTransferDetails ?? ref.read(bankTransferDetailsProvider);
    if (items.isEmpty ||
        ref.read(authProvider)?.id != user.id ||
        name.trim().isEmpty ||
        address.trim().isEmpty ||
        !isValidBahrainPhone(phone) ||
        !const {'cod', 'bank', 'benefit'}.contains(payment) ||
        (payment == 'bank' && !transferDetails.isComplete)) {
      return null;
    }
    final quantities = <String, int>{};
    for (final it in items) {
      final match = products.where((product) => product.id == it.product.id);
      if (match.isEmpty ||
          !match.first.active ||
          it.qty <= 0 ||
          !it.unitPrice.isFinite ||
          it.unitPrice <= 0) {
        return null;
      }
      quantities.update(
        match.first.id,
        (quantity) => quantity + it.qty,
        ifAbsent: () => it.qty,
      );
    }
    for (final entry in quantities.entries) {
      final product = products.firstWhere((item) => item.id == entry.key);
      if (entry.value < product.minOrderBags || entry.value > product.stock) {
        return null;
      }
    }
    final nextSequence = max(
          _p.getInt('order_sequence') ?? 1000,
          state.fold<int>(1000, (maxId, order) {
            final sequence =
                int.tryParse(order.id.replaceFirst('JBT-', '')) ?? 1000;
            return max(maxId, sequence);
          }),
        ) +
        1;
    _p.setInt('order_sequence', nextSequence);
    final lines = [
      for (final item in items)
        OrderLine(
          productId: item.product.id,
          name: item.product.name,
          nameAr: item.product.nameAr,
          qty: item.qty,
          bagKg: item.product.bagKg,
          pricePerBag: item.unitPrice,
        )
    ];
    final calculatedSubtotal = roundBhd(
      lines.fold<double>(
        0,
        (sum, line) => sum + lineTotal(line.pricePerBag, line.qty),
      ),
    );
    final totals = calculateOrderTotals(calculatedSubtotal);
    final order = OrderModel(
      id: 'JBT-$nextSequence',
      userId: user.id,
      userName: name,
      phone: phone,
      address: address,
      payment: payment,
      status: 'pending',
      items: lines,
      docs: const [],
      subtotal: totals.subtotal,
      vat: totals.vat,
      total: totals.total,
      createdAt: DateTime.now(),
      deliveryDate: deliveryDate,
      notes: notes,
      paymentStatus: payment == 'bank' ? 'pending' : 'not_applicable',
      bankTransferDetails: payment == 'bank' ? transferDetails : null,
    );
    state = [order, ...state];
    _save();
    ref.read(productsProvider.notifier).adjustStock(
      {for (final entry in quantities.entries) entry.key: -entry.value},
      reason: 'Order ${order.id}',
    );
    return order;
  }

  void setStatus(String id, String status) {
    final i = state.indexWhere((o) => o.id == id);
    if (i < 0) return;
    final old = state[i];
    final user = ref.read(authProvider);
    final isAdmin = user?.role == 'admin';
    final isOwnPendingCancellation = status == 'cancelled' &&
        old.status == 'pending' &&
        old.userId == user?.id;
    final isOwnDeliveryConfirmation = status == 'delivered' &&
        old.status == 'shipped' &&
        old.userId == user?.id;
    if (!isAdmin && !isOwnPendingCancellation && !isOwnDeliveryConfirmation) {
      return;
    }
    if (!canTransitionOrder(old.status, status)) return;
    final c = [...state];
    c[i] = old.copyWith(status: status);
    state = c;
    _save();
    final delta = <String, int>{};
    for (final line in old.items) {
      delta.update(
        line.productId,
        (quantity) => quantity + line.qty,
        ifAbsent: () => line.qty,
      );
    }
    final products = ref.read(productsProvider.notifier);
    if (status == 'cancelled') {
      products.adjustStock(delta, reason: 'Cancelled order $id');
    }
    ref.read(notificationsProvider.notifier).add(
          userId: old.userId,
          title: 'notification_order_title',
          message: 'notification_order_$status',
          target: Routes.order(id),
        );
  }

  bool cancelByBuyer(String id, String userId) {
    final order = state.where((item) => item.id == id);
    if (order.isEmpty ||
        order.first.userId != userId ||
        order.first.status != 'pending') {
      return false;
    }
    setStatus(id, 'cancelled');
    return state.firstWhere((item) => item.id == id).status == 'cancelled';
  }

  bool confirmDelivery(String id, String userId) {
    final matching = state.where((order) => order.id == id);
    if (matching.isEmpty ||
        matching.first.userId != userId ||
        matching.first.status != 'shipped') {
      return false;
    }
    setStatus(id, 'delivered');
    return state.firstWhere((order) => order.id == id).status == 'delivered';
  }

  bool reportBankTransfer(String id, String userId, String reference) {
    final index = state.indexWhere((order) => order.id == id);
    if (index < 0) return false;
    final order = state[index];
    if (order.userId != userId ||
        order.payment != 'bank' ||
        order.paymentStatus != 'pending' ||
        order.bankTransferDetails?.isComplete != true ||
        order.status == 'cancelled' ||
        reference.trim().isEmpty) {
      return false;
    }
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            paymentStatus: 'transfer_reported',
            paymentReference: reference.trim(),
          )
        else
          item,
    ];
    _save();
    ref.read(notificationsProvider.notifier).add(
          userId: order.userId,
          title: 'notification_payment_title',
          message: 'notification_payment_reported',
          target: Routes.order(id),
        );
    return true;
  }

  bool confirmBankPayment(String id) {
    if (ref.read(authProvider)?.role != 'admin') return false;
    final index = state.indexWhere((order) => order.id == id);
    if (index < 0) return false;
    final order = state[index];
    if (order.payment != 'bank' ||
        order.paymentStatus != 'transfer_reported' ||
        order.status == 'cancelled') {
      return false;
    }
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(paymentStatus: 'received') else item,
    ];
    _save();
    ref.read(notificationsProvider.notifier).add(
          userId: order.userId,
          title: 'notification_payment_title',
          message: 'notification_payment_received',
          target: Routes.order(id),
        );
    return true;
  }

  bool reorder(String id, String userId) {
    final order = state.where((item) => item.id == id);
    if (order.isEmpty || order.first.userId != userId) return false;
    final products = ref.read(productsProvider);
    var addedAny = false;
    for (final line in order.first.items) {
      final product = products.where((item) => item.id == line.productId);
      if (product.isEmpty ||
          !product.first.active ||
          product.first.stock < product.first.minOrderBags) {
        continue;
      }
      addedAny = ref.read(cartProvider.notifier).add(
                product.first,
                qty: min(line.qty, product.first.stock),
              ) ||
          addedAny;
    }
    return addedAny;
  }

  void addDoc(String id, OrderDoc d) {
    final i = state.indexWhere((o) => o.id == id);
    if (i < 0) return;
    final c = [...state];
    c[i] = state[i].copyWith(docs: [...state[i].docs, d]);
    state = c;
    _save();
  }
}

final ordersProvider =
    NotifierProvider<OrdersNotifier, List<OrderModel>>(OrdersNotifier.new);

final myOrdersProvider = Provider<List<OrderModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return ref.watch(ordersProvider).where((o) => o.userId == user.id).toList();
});

final orderByIdProvider = Provider.family<OrderModel?, String>((ref, id) {
  for (final o in ref.watch(ordersProvider)) {
    if (o.id == id) return o;
  }
  return null;
});

// ---------------- quote requests ----------------
class InquiriesNotifier extends Notifier<List<Inquiry>> {
  @override
  List<Inquiry> build() =>
      _decodeList(ref.read(prefsProvider), 'inquiries', Inquiry.fromMap);

  void add(Inquiry q) {
    state = [q, ...state];
    ref.read(prefsProvider).setString(
        'inquiries', jsonEncode(state.map((e) => e.toMap()).toList()));
  }

  void answer(
    String id, {
    required double pricePerBag,
    required DateTime validUntil,
    required String message,
  }) {
    final index = state.indexWhere((quote) => quote.id == id);
    if (index < 0 || pricePerBag <= 0 || validUntil.isBefore(DateTime.now())) {
      return;
    }
    final old = state[index];
    if (old.status != 'new') return;
    final updated = Inquiry(
      id: old.id,
      userId: old.userId,
      userName: old.userName,
      email: old.email,
      productId: old.productId,
      productName: old.productName,
      qty: old.qty,
      destination: old.destination,
      notes: old.notes,
      createdAt: old.createdAt,
      status: 'answered',
      quotedPrice: roundBhd(pricePerBag),
      validUntil: validUntil,
      answerMessage: message,
    );
    _replace(index, updated);
    ref.read(notificationsProvider.notifier).add(
          userId: old.userId,
          title: 'notification_quote_title',
          message: 'notification_quote_answer',
          target: Routes.quotes,
        );
  }

  bool updateBuyerStatus(String id, String userId, String status) {
    final index =
        state.indexWhere((quote) => quote.id == id && quote.userId == userId);
    if (index < 0 || state[index].status != 'answered') return false;
    if (status != 'accepted' && status != 'rejected') return false;
    final quote = state[index];
    if (status == 'accepted') {
      final validUntil = quote.validUntil;
      final product = ref.read(productByIdProvider(quote.productId));
      if (quote.quotedPrice == null ||
          validUntil == null ||
          validUntil.isBefore(DateTime.now()) ||
          product == null ||
          !product.active ||
          product.stock < quote.qty ||
          ref.read(cartProvider).containsKey(quote.productId)) {
        return false;
      }
      final added = ref
          .read(cartProvider.notifier)
          .addQuoted(product, quote.qty, quote.quotedPrice!);
      if (!added) return false;
    }
    _replace(
        index,
        Inquiry(
          id: quote.id,
          userId: quote.userId,
          userName: quote.userName,
          email: quote.email,
          productId: quote.productId,
          productName: quote.productName,
          qty: quote.qty,
          destination: quote.destination,
          notes: quote.notes,
          createdAt: quote.createdAt,
          status: status,
          quotedPrice: quote.quotedPrice,
          validUntil: quote.validUntil,
          answerMessage: quote.answerMessage,
        ));
    return true;
  }

  void _replace(int index, Inquiry quote) {
    final updated = [...state]..[index] = quote;
    state = updated;
    ref.read(prefsProvider).setString(
          'inquiries',
          jsonEncode(state.map((item) => item.toMap()).toList()),
        );
  }
}

final inquiriesProvider =
    NotifierProvider<InquiriesNotifier, List<Inquiry>>(InquiriesNotifier.new);

final myQuotesProvider = Provider<List<Inquiry>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return ref
      .watch(inquiriesProvider)
      .where((quote) => quote.userId == user.id)
      .toList();
});

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => _decodeList(
      ref.read(prefsProvider), 'notifications', AppNotification.fromMap);

  void add({
    required String userId,
    required String title,
    required String message,
    required String target,
  }) {
    if (userId.isEmpty) return;
    state = [
      AppNotification(
        id: 'N${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        title: title,
        message: message,
        target: target,
        createdAt: DateTime.now(),
      ),
      ...state,
    ];
    _save();
  }

  void markRead(String id) {
    state = [
      for (final notification in state)
        notification.id == id
            ? notification.copyWith(isRead: true)
            : notification,
    ];
    _save();
  }

  void markAllRead() {
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];
    _save();
  }

  void _save() => ref.read(prefsProvider).setString(
        'notifications',
        jsonEncode(state.map((item) => item.toMap()).toList()),
      );
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
        NotificationsNotifier.new);

final myNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return ref
      .watch(notificationsProvider)
      .where((notification) => notification.userId == user.id)
      .toList();
});

final unreadNotificationCountProvider = Provider<int>((ref) => ref
    .watch(myNotificationsProvider)
    .where((notification) => !notification.isRead)
    .length);
