import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/l10n.dart';
import '../core/design_tokens.dart';
import '../core/local_image.dart';
import '../core/theme.dart';
import '../models/models.dart';

InputDecoration fieldDec(BuildContext c, String label,
    {IconData? icon, String? hint}) {
  final s = Theme.of(c).colorScheme;
  OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius12),
      borderSide: BorderSide(color: col, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: true,
    fillColor: s.surface,
    border: b(s.outlineVariant),
    enabledBorder: b(s.outlineVariant),
    focusedBorder: b(s.primary, 1.6),
    errorBorder: b(s.error),
    focusedErrorBorder: b(s.error, 1.6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

AppBar appBar(BuildContext c, String title,
        {List<Widget>? actions,
        Widget? leading,
        PreferredSizeWidget? bottom}) =>
    AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: Theme.of(c)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800),
    );

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(DesignTokens.radius20);
    return Material(
      color: color ?? s.surface,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        mouseCursor:
            onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
              borderRadius: r,
              border:
                  Border.all(color: s.outlineVariant.withValues(alpha: 0.6))),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class FullButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool busy;
  final bool outlined;
  const FullButton(
      {super.key,
      required this.onPressed,
      required this.label,
      this.icon,
      this.busy = false,
      this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8)
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]);
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(onPressed: busy ? null : onPressed, child: child)
          : FilledButton(onPressed: busy ? null : onPressed, child: child),
    );
  }
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/logo.png', width: size, height: size);
}

class UserAvatar extends StatelessWidget {
  final AppUser? user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.name.trim() ?? '';
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final bytes = decodeLocalImage(user?.avatarData);
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: bytes == null
          ? Text(
              initials,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.8,
              ),
            )
          : ClipOval(
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: radius * 0.8,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class BankTransferCard extends StatelessWidget {
  final BankTransferDetails details;
  final double? amount;

  const BankTransferCard({super.key, required this.details, this.amount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(String label, String value, {bool copyable = false}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Text(
                  label,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (copyable)
                IconButton(
                  tooltip: context.tr('copy'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('copied'))),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
            ],
          ),
        );

    return AppCard(
      color: scheme.secondaryContainer.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('bank_transfer_details'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (amount != null)
            row(context.tr('amount_due'), 'BHD ${amount!.toStringAsFixed(3)}'),
          row(context.tr('bank_account_holder'), details.accountName),
          row(context.tr('bank_name'), details.bankName),
          row(context.tr('iban'), details.iban, copyable: true),
          if (details.swift.trim().isNotEmpty)
            row(context.tr('swift'), details.swift),
          const SizedBox(height: 12),
          Text(
            context.tr('bank_payment_manual_notice'),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'confirmed':
      return const Color(0xFF2563EB);
    case 'shipped':
      return const Color(0xFF7C3AED);
    case 'delivered':
      return const Color(0xFF16A34A);
    case 'cancelled':
      return const Color(0xFFDC2626);
    default:
      return Colors.grey;
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20)),
      child: Text(context.tr('status_$status'),
          style:
              TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.action});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
                color: s.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: s.primary),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: s.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const QtyStepper(
      {super.key,
      required this.value,
      required this.min,
      required this.max,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget btn(IconData i, VoidCallback? f) => IconButton(
          icon: Icon(i, size: 20),
          onPressed: f,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        );
    return Container(
      decoration: BoxDecoration(
          color: s.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s.outlineVariant)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
            width: 34,
            child: Center(
                child: Text('$value',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)))),
        btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }
}

List<Color> _palette(String origin) {
  switch (origin.toLowerCase()) {
    case 'pakistan':
      return const [Color(0xFF1B5E20), Color(0xFF66BB6A)];
    case 'india':
      return const [Color(0xFFE65100), Color(0xFFFFB74D)];
    case 'thailand':
      return const [Color(0xFF4A148C), Color(0xFFBA68C8)];
    default:
      return const [Color(0xFF37474F), Color(0xFF90A4AE)];
  }
}

class ProductVisual extends StatelessWidget {
  final Product product;
  final double height;
  final double radius;
  const ProductVisual(
      {super.key, required this.product, this.height = 120, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final imageBytes = decodeLocalImage(product.imageData);
    if (imageBytes != null) {
      return Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackVisual(),
        ),
      );
    }
    if (product.imageAsset != null && product.imageAsset!.isNotEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
        child: Image.asset(
          product.imageAsset!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackVisual(),
        ),
      );
    }
    return _fallbackVisual();
  }

  Widget _fallbackVisual() {
    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _palette(product.origin)),
      ),
      child: Stack(children: [
        PositionedDirectional(
          end: -height * 0.12,
          bottom: -height * 0.12,
          child: Icon(Icons.grain,
              size: height * 0.9, color: Colors.white.withValues(alpha: 0.12)),
        ),
        Center(
          child: Container(
            padding: EdgeInsets.all(height * 0.14),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: Icon(Icons.rice_bowl_rounded,
                size: height * 0.3, color: Colors.white),
          ),
        ),
        PositionedDirectional(
          start: 10,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${product.bagKg} kg',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
        ),
      ]),
    );
  }
}

class PriceRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const PriceRow(this.label, this.value, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        fontSize: bold ? 17 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: st), Text(value, style: st)]),
    );
  }
}

class LangButton extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const LangButton({super.key, required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => onChanged(current == 'ar' ? 'en' : 'ar'),
        icon: const Icon(Icons.language, size: 18),
        label: Text(current == 'ar' ? 'English' : 'العربية'),
      );
}

Widget gradientHeader(BuildContext context,
        {required Widget child, double radius = 28}) =>
    Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.greenDark, AppColors.green]),
        borderRadius: BorderRadiusDirectional.only(
            bottomStart: Radius.circular(radius),
            bottomEnd: Radius.circular(radius)),
      ),
      child: child,
    );
