# Jatoi Bin Trader Code Audit

This audit records the code present before the master-prompt implementation phase. “Works” means the action is connected to the current local implementation; it does not imply production payment, printing, or device validation.

## A. Route inventory

| Path | Screen file | Exists? | Guard | Back behavior | Linked from |
|---|---|---:|---|---|---|
| `/login` | `lib/screens/auth_screens.dart` | Yes | Signed out; signed-in redirects to products | No back action | Auth redirect |
| `/register` | `lib/screens/auth_screens.dart` | Yes | Signed out; signed-in redirects to products | Login link | Login |
| `/products` | `lib/screens/products_screen.dart` in `HomeShell` | Yes | Signed in | Stateful tab stack | Navigation tab, successful auth |
| `/products/:id` | `lib/screens/product_detail_screen.dart` | Yes | Signed in | Explicit products navigation | Product card |
| `/products/:id/quote` | `lib/screens/inquiry_screen.dart` | Yes | Signed in | Router stack/default | Product detail |
| `/cart` | `lib/screens/cart_screen.dart` in `HomeShell` | Yes | Signed in | Stateful tab stack | Navigation tab, add-to-cart snackbar |
| `/checkout` | `lib/screens/checkout_screen.dart` | Yes | Signed in | Back currently pops; no explicit cart-parent route policy | Cart |
| `/success/:id` | `lib/screens/order_success_screen.dart` | Yes | Signed in | Explicit order/products links | Checkout |
| `/orders` | `lib/screens/orders_screen.dart` in `HomeShell` | Yes | Signed in | Stateful tab stack | Navigation tab |
| `/orders/:id` | `lib/screens/order_detail_screen.dart` | Yes | Signed in, but record ownership is not enforced by detail lookup | Explicitly navigates to orders | Order cards, admin dashboard |
| `/profile` | `lib/screens/profile_screen.dart` in `HomeShell` | Yes | Signed in | Stateful tab stack | Navigation tab |
| `/admin` | `lib/screens/admin_screen.dart` | Yes | Admin redirect plus screen-level check | Explicit profile navigation | Profile |
| `/quotes` | `lib/screens/quotes_screen.dart` | Yes | Signed in | No dedicated parent/back policy | Profile |
| `/notifications` | `lib/screens/notifications_screen.dart` in shell | Yes | Signed in | Stateful tab stack | Navigation tab |
| `*` (unknown route) | `router.dart` inline error builder | Partial | Auth redirect first | No localized 404; generic “Home” button | Invalid URL |
| `/splash`, `/onboarding` | Missing | No | N/A | N/A | N/A |
| `/forgot-password` | Missing | No | N/A | N/A | Login |
| `/saved` | Missing as a route; saved filter is embedded in products | Partial | Signed in | N/A | Products filter |
| `/quotes/:id` | Missing | No | N/A | N/A | Quote list only |
| `/orders/:id/invoice` | Missing; invoice action lives on order detail | Partial | Signed in | N/A | Order detail |
| `/profile/edit`, `/profile/addresses`, `/profile/addresses/new`, `/profile/addresses/:id`, `/profile/password` | Missing as distinct routes; dialogs/inline profile flows exist | Partial | Signed in | N/A | Profile |
| `/settings`, `/about` | Missing | No | N/A | N/A | Profile/settings area |
| `/admin/products`, `/admin/products/new`, `/admin/products/:id`, `/admin/orders`, `/admin/customers`, `/admin/quotes`, `/admin/settings`, `/admin/export` | Missing as distinct routes; most are tabs/actions within one admin screen | Partial | Admin | N/A | Admin screen |

Routing gaps: paths are embedded directly in router and widget code; forgot-password and first-run exceptions do not exist; unknown routes have an English hard-coded fallback; deep-link redirects and record ownership need explicit tests; checkout/order detail/back behavior is inconsistent with the requested route contract.

## B. Button/action inventory

| Screen | Tappable controls/actions | Current result | Works? / needed |
|---|---|---|---|
| Login | Email/password fields, submit, register link | Local hashed-password sign-in and navigation | Yes; add forgot-password and route constants |
| Register | Name/email/password fields, submit, login link | Local account creation and navigation | Yes; verify input feedback and duplicate handling |
| Products | Sort menu; search; origin/saved chips; refresh; dismiss storage banner; product card; favorite; add button | Filters/sorts list, resets current state, opens details, toggles persisted favorite, adds to cart | Mostly; refresh is not a data fetch; saved is not a standalone route; colors/localization and failed add feedback need consistency |
| Product detail | Back; favorite; quantity stepper; quote; add to cart; snackbar view-cart | Navigates, toggles favorite, chooses quantity, starts quote and adds product | Mostly; no gallery or route constants; verify stale stock feedback |
| Quote request | Product/quantity/destination/notes fields; send request | Adds a local inquiry and returns to catalogue/list flow | Connected; form/model error and unknown-product states need checks |
| Quote list | Accept/reject controls and cart navigation | Accepts valid answered quote into cart; rejects quote | Connected; no quote details route; expiry/status interaction needs explicit route/UI |
| Cart | Clear; dismiss item; undo snackbar; quantity stepper; checkout | Removes/persists, restores dismissed quantity on undo, recalculates, opens checkout | Connected; ensure quote prices survive quantity edits, stock cleanup notice, empty/error states |
| Checkout | Address dropdown; date picker; three-step continue/back; payment choices; place order | Collects delivery/payment/review; validates and places order locally | Connected; empty-cart/identity guard, logical back, duplicate tap and stale-stock behavior need hardening |
| Success | Track order; continue shopping | Navigates to order detail or products | Connected; unknown order and post-success history policy need tests |
| Orders | Empty-state browse; order card | Opens products or detail | Basic; search/status filter requested but absent |
| Order detail | Back; admin status dropdown; buyer cancel/reorder; file picker/doc-type selector; invoice print/save | Status update, cancel/reorder, stores selected document filename, invokes PDF print layout | Partial; enforce order ownership; file picker only stores filename; no invoice route/preview; cancellation needs confirmation/feedback; invoice is Latin-font only |
| Notifications | Notification row | Marks read and opens target | Connected; invalid target handling and unread badge route are incomplete |
| Profile | Edit profile; address edit/default/delete/menu; settings controls; admin/quotes links; password change; logout | Opens forms/dialogs, persists local profile/settings, role-gated admin, quote list, sign-out | Mostly; routes are missing for sub-pages; destructive confirmation and action feedback need review |
| Admin | Tabs; product create/edit/delete; order search/status/date/export; quote response; customer rows; VAT/threshold settings; stock controls/history | Runs local administration functions across one tabbed screen | Partial; requested subroutes absent; verify delete confirmation/undo, edit validation, export on each platform, and status transition feedback |
| Shared shell | Navigation destinations; cart/unread badges; rail selection | Switches stateful branch and displays counts | Connected; badge semantics, layout breakpoint, rail labels and path centralization need improvement |
| Error route | Home button | Goes to `/products` | Partial; hard-coded English, not a dedicated localized 404, and route fallback behavior is untested |

## C. Feature matrix

| Feature | Implemented? | Missing pieces / follow-up |
|---|---|---|
| Offline persistence and repository/provider boundary | Partial | Providers own most persistence directly; formal repository interfaces are absent |
| Register/login/session | Yes | Forgot-password flow is absent; offline recovery identity is not verified |
| Salted password hash | Partial | SHA-256 salt is a demo safeguard, not a password KDF; keep the limitation explicit |
| Catalogue search/filter/sort/favorites | Partial | Category filter and dedicated saved route absent; product image gallery absent |
| Product tiers, cart totals, BHD and VAT | Yes | Verify one totals path across quote/cart/order/invoice; ensure one VAT constant |
| Persistent cart, min order and stock reconciliation | Partial | Recently strengthened; verify all authentication, product-change and restart paths |
| Checkout/address/date/notes/manual payment | Partial | End-to-end widget test exists; payment remains manual; robust rapid repeat submission/back behavior needed |
| Orders, status, numbering, cancellation, reorder | Partial | Provider guards and stock updates exist; cross-user order detail access, filter/search, and full rule tests remain |
| Quote request/answer/acceptance | Partial | Main flow exists; separate detail route and exhaustive expiry/stock tests absent |
| Notifications | Partial | Persisted, badge and target navigation exist; route/error/read-state coverage incomplete |
| Invoice PDF | Partial | Print/save invoked from order detail; company details are static/demo, no Arabic font, no invoice preview route |
| Profile, addresses, password, settings | Partial | Core edit flows exist in profile screen; requested separate route structure and forgot-password absent |
| Admin product/order/customer/quote/settings/export | Partial | One tabbed screen; distinct route inventory absent; confirm all edit/export/action outcomes |
| Schema migration/corrupt JSON | Partial | Versioned migration and safe defaults exist; user notice exists; migrate each record shape and test edge cases |
| Splash/onboarding | No | Splash and once-only skippable onboarding missing |
| 404/not-found UX | No | Generic, unlocalized error builder; entities need friendly missing-record state |
| Dark mode / responsive | Partial | Theme mode and a wide-screen rail exist; color hardcodes and breakpoint/text-scale verification remain |
| Design system/components | Partial | Tokens exist but incomplete (no 32 spacing/type scale); widgets still use scattered raw values and colors |
| Accessibility/reduced motion | No/partial | No reduced-motion policy, comprehensive semantics/focus audit, or required 48dp audit |
| Loading/error/skeleton states | Partial | Lists largely synchronous and empty states exist; no shared skeleton/error component or async-state coverage |
| Tests | Partial | Unit and route/purchase tests exist; route table/back/deep-link/quote/notification/admin/Arabic screen/golden coverage absent |
| Documentation/manual QA | Partial | README/Firebase map exist; AUDIT.md added for this phase; MANUAL_QA.md absent |

## D. Missing files/screens/widgets/tests

### Requested screens/routes not present as dedicated screens

- Splash and three-step once-only onboarding.
- Offline forgot-password screen/flow (requires a clearly safe recovery policy).
- Dedicated saved-products screen/route.
- Quote detail screen/route.
- Order invoice preview/print screen/route.
- Profile edit, address book/add/edit, password, settings, and about routes/screens.
- Dedicated admin dashboard/products/product form/orders/customers/quotes/settings/export routes.
- Localized 404 screen.

### Missing shared infrastructure

- `lib/core/routes.dart` route constants and typed route builders.
- Formal repository layer separating persistence from notifiers/providers.
- Reusable error/skeleton/loading components and comprehensive empty/error state coverage.
- Shared reusable 52dp button, section header, bottom-sheet, dialog, and accessibility helpers.
- Complete design-token type scale and spacing/radius/duration definitions.
- Invoice company-information model/provider instead of static placeholder details.

### Missing QA/docs

- Route table/back/deep-link tests for every required path.
- Quote, notification target/read, all order transition/stock/cancel/reorder/migration edge tests.
- Golden tests for key screens by light/dark and English/Arabic.
- `MANUAL_QA.md`.

## E. UI inconsistencies found

- Existing tokens are not applied consistently; raw spacing, font weights/sizes, radii, and icon dimensions remain throughout screens.
- Some UI colors bypass `ColorScheme` (`Colors.white`, red status/favorite colors, country/product palettes, hard-coded status colors); dark mode contrast can drift.
- Tokens omit the requested 32dp spacing and full display/title/subtitle/body/caption/button scale.
- The shared quantity stepper uses 38dp controls, below the 48dp touch target.
- Some UI labels and router error text are hard-coded rather than localized; route fallback is not Arabic-aware.
- Navigation rail appears only at 900dp and content max width is 1440 rather than the requested approximately 1100dp.
- Product cards are fixed-height; small screens, text scaling, and long Arabic labels require overflow verification.
- Insets/paddings and radii vary between screens; RTL-safe directional spacing is not universal.
- Loading feedback is mostly spinner/none; list skeleton and error patterns are missing.
- Motion and semantic labels/tooltips are inconsistent; no reduce-motion behavior was found.
- Invoice PDF lacks bundled Arabic font/shaping; current details include demo company identity.

## Audit conclusion

The offline commerce core is substantially present, but the requested screen/route inventory and QA bar are not met. Continue implementation only against verifiable, tested flows; document any platform- or scope-limited items instead of exposing inert actions.
