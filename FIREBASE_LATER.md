# Firebase migration map

The current app is offline-only. Screens consume Riverpod providers; keep the screen
contracts stable while replacing local persistence with repository implementations.
Do not add Firebase to this demo until a backend migration is explicitly planned.

| Current provider/model | Suggested Firebase implementation |
|---|---|
| `AuthNotifier` / `AppUser` | Firebase Authentication for credentials; Firestore `users/{uid}` for profile, roles, and addresses. Store no password hashes in Firestore. |
| `ProductsNotifier` / `Product` | Firestore `products` collection, with image assets moved to Cloud Storage and their download URLs stored in product documents. |
| `CartNotifier` / `CartItem` | Firestore per-user cart or a client-side cart synchronized after sign-in; re-check product visibility, min order, and stock at checkout. |
| `OrdersNotifier.place` | Callable Cloud Function/transaction to validate stock, compute tier pricing and VAT, reserve/decrement inventory, and allocate a monotonic order number server-side. |
| `OrdersNotifier.setStatus` | Authorized Cloud Function enforcing the pending → confirmed → shipped → delivered flow and cancellation/stock restoration atomically. |
| `InquiriesNotifier` / `Inquiry` | Firestore `quotes` collection with buyer/admin security rules and server timestamps. |
| `NotificationsNotifier` | Firestore per-user notifications; optionally add FCM after token and consent handling are designed. |
| VAT registration, low-stock threshold, locale/theme | Firestore business settings for admin-owned values; keep personal presentation preferences local. |
| `OrderDoc` and invoice PDFs | Cloud Storage for uploads/generated PDFs, with signed or authenticated download URLs and audit metadata. |
| `stock_history` preference data | Append-only Firestore stock adjustment records with admin identity, reason, timestamp, and server-side authorization. |

Before production, move all price/tax calculations and stock/status authorization to trusted
server code. Client-side Riverpod validation improves UX but is not a security boundary.
Benefit Pay remains a manual payment instruction unless the business later adopts an
official supported integration; no integration is implied by this migration map.
