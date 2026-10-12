import '../models/models.dart';
import 'format.dart';

class PriceBreakdown {
  final double unitPrice;
  final double subtotal;
  final double savings;
  final int? appliedTier;

  const PriceBreakdown({
    required this.unitPrice,
    required this.subtotal,
    required this.savings,
    required this.appliedTier,
  });
}

PriceBreakdown calculatePrice(Product product, int quantity) {
  final matchingTiers = product.priceTiers
      .where((tier) => quantity >= tier.minimumBags)
      .toList()
    ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
  final tier = matchingTiers.isEmpty ? null : matchingTiers.first;
  final unitPrice = roundBhd(
    product.pricePerBag * (1 - (tier?.discountPercent ?? 0) / 100),
  );
  return PriceBreakdown(
    unitPrice: unitPrice,
    subtotal: roundBhd(unitPrice * quantity),
    savings: roundBhd((product.pricePerBag - unitPrice) * quantity),
    appliedTier: tier?.minimumBags,
  );
}

class OrderTotals {
  final double subtotal;
  final double vat;
  final double total;

  const OrderTotals(this.subtotal, this.vat, this.total);
}

OrderTotals calculateOrderTotals(double subtotal) {
  final roundedSubtotal = roundBhd(subtotal);
  final vat = roundBhd(roundedSubtotal * vatRate);
  return OrderTotals(roundedSubtotal, vat, roundBhd(roundedSubtotal + vat));
}

double roundBhd(double amount) => (amount * 1000).roundToDouble() / 1000;

double lineTotal(double unitPrice, int quantity) =>
    roundBhd(unitPrice * quantity);

bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

bool isValidBahrainPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[\s()+-]'), '');
  return RegExp(r'^(?:973)?[13679]\d{7}$').hasMatch(digits);
}

bool canTransitionOrder(String current, String next) {
  if (current == next) return false;
  if (next == 'cancelled') {
    return current == 'pending' || current == 'confirmed';
  }
  return switch (current) {
    'pending' => next == 'confirmed',
    'confirmed' => next == 'shipped',
    'shipped' => next == 'delivered',
    _ => false,
  };
}
