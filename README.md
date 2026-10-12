# Jatoi Bin Trader

An offline-first Flutter rice import/export ordering demo for Bahrain. It runs on local
SharedPreferences only; no Firebase, backend, or online payment integration is used.

## Run and verify

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Run on an attached Android/iOS device with `flutter run` (iOS builds require macOS and
Xcode). Android and iOS device execution have not been verified in this workspace.

## Demo accounts

- Admin: `admin@jatoi.bh` / `admin123`
- Buyer: register a new account in the app.

Accounts are stored locally. The salted SHA-256 password hash is a demo safeguard, not
production authentication; use a backend identity service for real customer accounts.

## Features

- English and Arabic UI, including RTL layout, plus light/dark/system theme selection.
- Product catalogue, search, origin filters, favourites, optional product image assets,
  minimum quantities, stock levels, bulk price tiers, and tier savings.
- Per-account cart persistence, live stock reconciliation, BHD (3 decimal) pricing,
  and one central 10% VAT calculation.
- Delivery date, saved addresses, order notes, manual cash/bank/Benefit Pay choices,
  unique sequential order numbers, guarded order status transitions, buyer cancellation,
  reorder, and persistent in-app status/quote notifications.
- Quote requests, admin quote replies with expiry, and buyer acceptance into the cart.
- Profile name/phone/address editing and old-password-verified password changes.
- Admin dashboard, customer summaries, product/order search, order status/date filters,
  editable low-stock threshold, stock adjustment history, and CSV order export.
- Printable/savable PDF invoices with optional VAT registration number.
- Local schema versioning and safe recovery for malformed preference data.

Benefit Pay is only a manual payment choice. It does not initiate or verify a transfer.

## Routes

| Route | Purpose |
|---|---|
| `/login`, `/register` | Local authentication |
| `/products` | Product catalogue |
| `/products/:id` | Product detail |
| `/products/:id/quote` | Request a quote |
| `/cart` | Per-user cart |
| `/checkout` | Delivery, payment, and order review |
| `/success/:id` | Order confirmation |
| `/orders` | Buyer order list |
| `/orders/:id` | Order detail, invoice, cancel/reorder |
| `/quotes` | Buyer's quotes and answers |
| `/notifications` | Persisted in-app notifications |
| `/profile` | Profile, saved addresses, language, theme |
| `/admin` | Admin dashboard and management (admin only) |

Signed-out users are redirected to `/login`; non-admin users are redirected away from `/admin`.

## Known limits

- Data is device-local and is not synchronized or backed up across devices. SharedPreferences
  is not encrypted and this application is not suitable for real customer data yet.
- SHA-256 with a random salt is not a production password KDF. Real security requires a
  backend, server-side authentication, authorization, and order validation.
- The invoice uses built-in Latin PDF fonts. No Arabic font is bundled, so Arabic text
  shaping/rendering in PDFs is not supported; the app displays a notice in Arabic mode.
- Invoice company contact/address details are demo placeholders and must be replaced before
  issuing real invoices.
- Android/iOS runtime behavior and printer sharing were not verified here.
- A dedicated first-run onboarding flow is not included yet; checkout is a three-step
  delivery/payment/review flow.

See [FIREBASE_LATER.md](./FIREBASE_LATER.md) for the planned backend mapping.
