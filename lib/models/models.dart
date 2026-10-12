class PriceTier {
  final int minimumBags;
  final double discountPercent;

  const PriceTier({required this.minimumBags, required this.discountPercent});

  Map<String, dynamic> toMap() => {
        'minimumBags': minimumBags,
        'discountPercent': discountPercent,
      };

  factory PriceTier.fromMap(Map<String, dynamic> map) => PriceTier(
        minimumBags: ((map['minimumBags'] ?? 1) as num).toInt(),
        discountPercent: ((map['discountPercent'] ?? 0) as num).toDouble(),
      );
}

class DeliveryAddress {
  final String id;
  final String label;
  final String address;
  final bool isDefault;

  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.address,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'address': address,
        'isDefault': isDefault,
      };

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) => DeliveryAddress(
        id: (map['id'] ?? '') as String,
        label: (map['label'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        isDefault: (map['isDefault'] ?? false) as bool,
      );
}

class Product {
  final String id, name, nameAr, origin, description;
  final int bagKg, minOrderBags, stock;
  final double pricePerBag;
  final bool active;
  final List<PriceTier> priceTiers;
  final String? imageAsset, imageData;

  const Product({
    required this.id,
    required this.name,
    this.nameAr = '',
    required this.origin,
    required this.description,
    required this.bagKg,
    required this.pricePerBag,
    this.minOrderBags = 1,
    this.stock = 0,
    this.active = true,
    this.priceTiers = const [],
    this.imageAsset,
    this.imageData,
  });

  Product withId(String value) => Product(
        id: value,
        name: name,
        nameAr: nameAr,
        origin: origin,
        description: description,
        bagKg: bagKg,
        pricePerBag: pricePerBag,
        minOrderBags: minOrderBags,
        stock: stock,
        active: active,
        priceTiers: priceTiers,
        imageAsset: imageAsset,
        imageData: imageData,
      );

  Product withStock(int value) => Product(
        id: id,
        name: name,
        nameAr: nameAr,
        origin: origin,
        description: description,
        bagKg: bagKg,
        pricePerBag: pricePerBag,
        minOrderBags: minOrderBags,
        stock: value,
        active: active,
        priceTiers: priceTiers,
        imageAsset: imageAsset,
        imageData: imageData,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nameAr': nameAr,
        'origin': origin,
        'description': description,
        'bagKg': bagKg,
        'pricePerBag': pricePerBag,
        'minOrderBags': minOrderBags,
        'stock': stock,
        'active': active,
        'priceTiers': priceTiers.map((tier) => tier.toMap()).toList(),
        'imageAsset': imageAsset,
        'imageData': imageData,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: (map['id'] ?? '') as String,
        name: (map['name'] ?? '') as String,
        nameAr: (map['nameAr'] ?? '') as String,
        origin: (map['origin'] ?? '') as String,
        description: (map['description'] ?? '') as String,
        bagKg: ((map['bagKg'] ?? 1) as num).toInt(),
        pricePerBag: ((map['pricePerBag'] ?? 0) as num).toDouble(),
        minOrderBags: ((map['minOrderBags'] ?? 1) as num).toInt(),
        stock: ((map['stock'] ?? 0) as num).toInt(),
        active: (map['active'] ?? true) as bool,
        priceTiers: ((map['priceTiers'] ?? []) as List)
            .map((item) => PriceTier.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList(),
        imageAsset: map['imageAsset'] as String?,
        imageData: map['imageData'] as String?,
      );
}

class CartItem {
  final Product product;
  final int qty;
  final double? quotedUnitPrice;
  final double? tierUnitPrice;
  final int? appliedTier;
  final double savings;

  const CartItem(
    this.product,
    this.qty, {
    this.quotedUnitPrice,
    this.tierUnitPrice,
    this.appliedTier,
    this.savings = 0,
  });
  double get unitPrice => quotedUnitPrice ?? tierUnitPrice ?? product.pricePerBag;
}

class OrderLine {
  final String productId, name, nameAr;
  final int qty, bagKg;
  final double pricePerBag;
  const OrderLine({
    required this.productId,
    required this.name,
    this.nameAr = '',
    required this.qty,
    required this.bagKg,
    required this.pricePerBag,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'nameAr': nameAr,
        'qty': qty,
        'bagKg': bagKg,
        'pricePerBag': pricePerBag,
      };

  factory OrderLine.fromMap(Map<String, dynamic> map) => OrderLine(
        productId: (map['productId'] ?? '') as String,
        name: (map['name'] ?? '') as String,
        nameAr: (map['nameAr'] ?? '') as String,
        qty: ((map['qty'] ?? 0) as num).toInt(),
        bagKg: ((map['bagKg'] ?? 1) as num).toInt(),
        pricePerBag: ((map['pricePerBag'] ?? 0) as num).toDouble(),
      );
}

class OrderDoc {
  final String type, name;
  const OrderDoc({required this.type, required this.name});
  Map<String, dynamic> toMap() => {'type': type, 'name': name};
  factory OrderDoc.fromMap(Map<String, dynamic> map) =>
      OrderDoc(type: (map['type'] ?? '') as String, name: (map['name'] ?? '') as String);
}

const orderStatuses = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];
const documentTypes = ['invoice', 'packing', 'origin', 'bol'];

class OrderModel {
  final String id, userId, userName, phone, address, payment, status;
  final String paymentStatus, paymentReference;
  final BankTransferDetails? bankTransferDetails;
  final List<OrderLine> items;
  final List<OrderDoc> docs;
  final double subtotal, vat, total;
  final DateTime createdAt;
  final DateTime? deliveryDate;
  final String notes;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.address,
    required this.payment,
    required this.status,
    required this.items,
    required this.docs,
    required this.subtotal,
    required this.vat,
    required this.total,
    required this.createdAt,
    this.deliveryDate,
    this.notes = '',
    this.paymentStatus = 'not_applicable',
    this.paymentReference = '',
    this.bankTransferDetails,
  });

  OrderModel copyWith({
    String? status,
    List<OrderDoc>? docs,
    DateTime? deliveryDate,
    String? notes,
    String? paymentStatus,
    String? paymentReference,
  }) =>
      OrderModel(
        id: id,
        userId: userId,
        userName: userName,
        phone: phone,
        address: address,
        payment: payment,
        status: status ?? this.status,
        items: items,
        docs: docs ?? this.docs,
        subtotal: subtotal,
        vat: vat,
        total: total,
        createdAt: createdAt,
        deliveryDate: deliveryDate ?? this.deliveryDate,
        notes: notes ?? this.notes,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paymentReference: paymentReference ?? this.paymentReference,
        bankTransferDetails: bankTransferDetails,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'phone': phone,
        'address': address,
        'payment': payment,
        'paymentStatus': paymentStatus,
        'paymentReference': paymentReference,
        'bankTransferDetails': bankTransferDetails?.toMap(),
        'status': status,
        'items': items.map((item) => item.toMap()).toList(),
        'docs': docs.map((doc) => doc.toMap()).toList(),
        'subtotal': subtotal,
        'vat': vat,
        'total': total,
        'createdAt': createdAt.toIso8601String(),
        'deliveryDate': deliveryDate?.toIso8601String(),
        'notes': notes,
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) => OrderModel(
        id: (map['id'] ?? '') as String,
        userId: (map['userId'] ?? '') as String,
        userName: (map['userName'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        payment: (map['payment'] ?? 'cod') as String,
        paymentStatus: (map['paymentStatus'] ??
            ((map['payment'] ?? 'cod') == 'bank'
                ? 'pending'
                : 'not_applicable')) as String,
        paymentReference: (map['paymentReference'] ?? '') as String,
        bankTransferDetails: map['bankTransferDetails'] is Map
            ? BankTransferDetails.fromMap(
                Map<String, dynamic>.from(map['bankTransferDetails'] as Map),
              )
            : null,
        status: (map['status'] ?? 'pending') as String,
        items: ((map['items'] ?? []) as List)
            .map((item) => OrderLine.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList(),
        docs: ((map['docs'] ?? []) as List)
            .map((item) => OrderDoc.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList(),
        subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
        vat: ((map['vat'] ?? 0) as num).toDouble(),
        total: ((map['total'] ?? 0) as num).toDouble(),
        createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
        deliveryDate: DateTime.tryParse((map['deliveryDate'] ?? '') as String),
        notes: (map['notes'] ?? '') as String,
      );
}

class BankTransferDetails {
  final String accountName, bankName, iban, swift;

  const BankTransferDetails({
    this.accountName = '',
    this.bankName = '',
    this.iban = '',
    this.swift = '',
  });

  bool get isComplete =>
      accountName.trim().isNotEmpty &&
      bankName.trim().isNotEmpty &&
      RegExp(r'^BH\d{2}[A-Z0-9]{18}$').hasMatch(
        iban.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
      );

  Map<String, dynamic> toMap() => {
        'accountName': accountName,
        'bankName': bankName,
        'iban': iban,
        'swift': swift,
      };

  factory BankTransferDetails.fromMap(Map<String, dynamic> map) =>
      BankTransferDetails(
        accountName: (map['accountName'] ?? '') as String,
        bankName: (map['bankName'] ?? '') as String,
        iban: (map['iban'] ?? '') as String,
        swift: (map['swift'] ?? '') as String,
      );
}

class Inquiry {
  final String id, userId, userName, email, productId, productName, destination, notes, status;
  final int qty;
  final DateTime createdAt;
  final double? quotedPrice;
  final DateTime? validUntil;
  final String answerMessage;

  const Inquiry({
    required this.id,
    this.userId = '',
    required this.userName,
    required this.email,
    this.productId = '',
    required this.productName,
    required this.qty,
    required this.destination,
    required this.notes,
    required this.createdAt,
    this.status = 'new',
    this.quotedPrice,
    this.validUntil,
    this.answerMessage = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'email': email,
        'productId': productId,
        'productName': productName,
        'qty': qty,
        'destination': destination,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'quotedPrice': quotedPrice,
        'validUntil': validUntil?.toIso8601String(),
        'answerMessage': answerMessage,
      };

  factory Inquiry.fromMap(Map<String, dynamic> map) => Inquiry(
        id: (map['id'] ?? '') as String,
        userId: (map['userId'] ?? '') as String,
        userName: (map['userName'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        productId: (map['productId'] ?? '') as String,
        productName: (map['productName'] ?? '') as String,
        qty: ((map['qty'] ?? 0) as num).toInt(),
        destination: (map['destination'] ?? '') as String,
        notes: (map['notes'] ?? '') as String,
        createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
        status: (map['status'] ?? 'new') as String,
        quotedPrice: (map['quotedPrice'] as num?)?.toDouble(),
        validUntil: DateTime.tryParse((map['validUntil'] ?? '') as String),
        answerMessage: (map['answerMessage'] ?? '') as String,
      );
}

class AppUser {
  final String id, name, email, passwordHash, role, phone;
  final String? avatarData;
  final List<DeliveryAddress> addresses;
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.phone = '',
    this.addresses = const [],
    this.avatarData,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'role': role,
        'phone': phone,
        'avatarData': avatarData,
        'addresses': addresses.map((address) => address.toMap()).toList(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: (map['id'] ?? '') as String,
        name: (map['name'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        passwordHash: (map['passwordHash'] ?? map['password'] ?? '') as String,
        role: (map['role'] ?? 'buyer') as String,
        phone: (map['phone'] ?? '') as String,
        avatarData: map['avatarData'] as String?,
        addresses: ((map['addresses'] ?? []) as List)
            .map((address) => DeliveryAddress.fromMap(Map<String, dynamic>.from(address as Map)))
            .toList(),
      );

  AppUser copyWith({
    String? name,
    String? passwordHash,
    String? phone,
    List<DeliveryAddress>? addresses,
    String? avatarData,
    bool clearAvatar = false,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role,
        phone: phone ?? this.phone,
        addresses: addresses ?? this.addresses,
        avatarData: clearAvatar ? null : avatarData ?? this.avatarData,
      );
}

class AppNotification {
  final String id, userId, title, message, target;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.target,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        userId: userId,
        title: title,
        message: message,
        target: target,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'message': message,
        'target': target,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: (map['id'] ?? '') as String,
        userId: (map['userId'] ?? '') as String,
        title: (map['title'] ?? '') as String,
        message: (map['message'] ?? '') as String,
        target: (map['target'] ?? '') as String,
        createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
        isRead: (map['isRead'] ?? false) as bool,
      );
}
