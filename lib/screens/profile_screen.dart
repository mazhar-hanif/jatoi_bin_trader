import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/business_rules.dart';
import '../core/l10n.dart';
import '../core/local_image.dart';
import '../core/routes.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final mode = ref.watch(themeModeProvider);
    final s = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        gradientHeader(
          context,
          radius: 32,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Row(children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(user: user, radius: 34),
                    if (user != null)
                      PositionedDirectional(
                        bottom: -8,
                        end: -8,
                        child: Tooltip(
                          message: context.tr('choose_image'),
                          child: Material(
                            color: s.secondary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _chooseAvatar(context, ref, user),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.camera_alt_outlined, size: 20, color: s.onSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(user?.email ?? '', style: const TextStyle(color: Color(0xFFE8DFB5))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                      child: Text(context.tr(isAdmin ? 'role_admin' : 'role_buyer'),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (user != null) ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => _editProfile(context, ref, user),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('edit_profile')),
                ),
              ),
              SectionTitle(context.tr('saved_addresses')),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    if (user.addresses.isEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(context.tr('no_saved_addresses')),
                      ),
                    for (final address in user.addresses)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(address.isDefault ? Icons.place : Icons.place_outlined),
                        title: Text(address.label),
                        subtitle: Text(address.address),
                        trailing: PopupMenuButton<String>(
                          tooltip: context.tr('edit'),
                          onSelected: (action) {
                            if (action == 'edit') {
                              _editAddress(context, ref, user, address);
                            } else if (action == 'default') {
                              final updated = [
                                for (final item in user.addresses)
                                  DeliveryAddress(
                                    id: item.id,
                                    label: item.label,
                                    address: item.address,
                                    isDefault: item.id == address.id,
                                  ),
                              ];
                              ref.read(authProvider.notifier).updateProfile(
                                    name: user.name,
                                    phone: user.phone,
                                    addresses: updated,
                                  );
                            } else if (action == 'delete') {
                              final updated = user.addresses.where((item) => item.id != address.id).toList();
                              if (!updated.any((item) => item.isDefault) && updated.isNotEmpty) {
                                final first = updated.first;
                                updated[0] = DeliveryAddress(
                                  id: first.id,
                                  label: first.label,
                                  address: first.address,
                                  isDefault: true,
                                );
                              }
                              ref.read(authProvider.notifier).updateProfile(
                                    name: user.name,
                                    phone: user.phone,
                                    addresses: updated,
                                  );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
                            if (!address.isDefault)
                              PopupMenuItem(value: 'default', child: Text(context.tr('set_default'))),
                            PopupMenuItem(value: 'delete', child: Text(context.tr('delete'))),
                          ],
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: Text(context.tr('add_address')),
                      onTap: () => _editAddress(context, ref, user),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => _changePassword(context, ref),
                child: Row(children: [
                  const Icon(Icons.password_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('change_password'))),
                  const Icon(Icons.chevron_right),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            if (isAdmin) ...[
              AppCard(
                onTap: () => context.push(Routes.admin),
                color: s.secondaryContainer.withValues(alpha: 0.4),
                child: Row(children: [
                  const Icon(Icons.admin_panel_settings_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('admin_panel'), style: const TextStyle(fontWeight: FontWeight.w800))),
                  const Icon(Icons.chevron_right),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            AppCard(
              onTap: () => context.push(Routes.quotes),
              child: Row(children: [
                const Icon(Icons.request_quote_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(context.tr('quotes'), style: const TextStyle(fontWeight: FontWeight.w800))),
                const Icon(Icons.chevron_right),
              ]),
            ),
            const SizedBox(height: 14),
            SectionTitle(context.tr('settings')),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.language), const SizedBox(width: 10), Text(context.tr('language'), style: const TextStyle(fontWeight: FontWeight.w700))]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'en', label: Text(context.tr('english'))),
                      ButtonSegment(value: 'ar', label: Text(context.tr('arabic'))),
                    ],
                    selected: {lang},
                    onSelectionChanged: (v) => ref.read(localeProvider.notifier).set(v.first),
                  ),
                ),
                const Divider(height: 28),
                Row(children: [const Icon(Icons.brightness_6_outlined), const SizedBox(width: 10), Text(context.tr('theme'), style: const TextStyle(fontWeight: FontWeight.w700))]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.phone_android, size: 18), label: Text(context.tr('theme_system'))),
                      ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined, size: 18), label: Text(context.tr('theme_light'))),
                      ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined, size: 18), label: Text(context.tr('theme_dark'))),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).set(v.first),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            SectionTitle(context.tr('about')),
            AppCard(
              child: Column(children: [
                ListTile(contentPadding: EdgeInsets.zero, leading: const LogoMark(size: 40), title: const Text('Jatoi Bin Trader'), subtitle: Text(context.tr('tagline'))),
                const Divider(height: 8),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_outlined), title: Text(context.tr('contact_phone'))),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.mail_outline), title: Text(context.tr('contact_email'))),
              ]),
            ),
            const SizedBox(height: 18),
            FullButton(
              outlined: true,
              icon: Icons.logout,
              label: context.tr('logout'),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _chooseAvatar(BuildContext context, WidgetRef ref, AppUser user) async {
    try {
      final bytes = await pickLocalImage();
      if (bytes == null) return;
      await ref.read(authProvider.notifier).updateProfile(
            name: user.name,
            phone: user.phone,
            addresses: user.addresses,
            avatarData: encodeLocalImage(bytes),
          );
    } on LocalImageTooLarge {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('image_too_large'))),
        );
      }
    } on LocalImageUnavailable {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('image_unavailable'))),
        );
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('image_unavailable'))),
        );
      }
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('image_unavailable'))),
        );
      }
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, AppUser user) async {
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('edit_profile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: fieldDec(context, context.tr('full_name'))),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: fieldDec(context, context.tr('phone')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty ||
                  (phone.text.trim().isNotEmpty && !isValidBahrainPhone(phone.text))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(name.text.trim().isEmpty ? 'required' : 'invalid_bahrain_phone'),
                    ),
                  ),
                );
                return;
              }
              ref.read(authProvider.notifier).updateProfile(
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    addresses: user.addresses,
                  );
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
  }

  Future<void> _editAddress(
    BuildContext context,
    WidgetRef ref,
    AppUser user, [
    DeliveryAddress? original,
  ]) async {
    final label = TextEditingController(text: original?.label ?? '');
    final addressText = TextEditingController(text: original?.address ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(original == null ? 'add_address' : 'edit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: label, decoration: fieldDec(context, context.tr('address_label'))),
            const SizedBox(height: 10),
            TextField(
              controller: addressText,
              maxLines: 3,
              decoration: fieldDec(context, context.tr('address')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (label.text.trim().isEmpty || addressText.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('required'))),
                );
                return;
              }
              final isDefault = original?.isDefault ?? user.addresses.isEmpty;
              final entries = [
                for (final item in user.addresses)
                  if (item.id != original?.id)
                    DeliveryAddress(
                      id: item.id,
                      label: item.label,
                      address: item.address,
                      isDefault: isDefault ? false : item.isDefault,
                    ),
                DeliveryAddress(
                  id: original?.id ?? 'A${DateTime.now().microsecondsSinceEpoch}',
                  label: label.text.trim(),
                  address: addressText.text.trim(),
                  isDefault: isDefault,
                ),
              ];
              ref.read(authProvider.notifier).updateProfile(
                    name: user.name,
                    phone: user.phone,
                    addresses: entries,
                  );
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    label.dispose();
    addressText.dispose();
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    var error = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.tr('change_password')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassword,
                obscureText: true,
                decoration: fieldDec(context, context.tr('current_password')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: fieldDec(context, context.tr('new_password')),
              ),
              if (error.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(context.tr(error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('cancel'))),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(authProvider.notifier).changePassword(
                      oldPassword.text,
                      newPassword.text,
                    );
                if (result == null) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } else {
                  setState(() => error = result);
                }
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
    oldPassword.dispose();
    newPassword.dispose();
  }
}
