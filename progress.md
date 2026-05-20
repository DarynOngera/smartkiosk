# Progress

## Guest cart and checkout

- Added a browser-session `session_id` plug so guests get a stable cart owner before logging in.
- Updated cart-related LiveViews to read `session["session_id"]` first and fall back to LiveView connect params.
- Kept guest checkout flow using name and phone number before placing orders.

## Storefront cart behavior

- Fixed storefront index add-to-cart so it works for both guests and logged-in users.
- Refreshed the navbar cart count after adding an item from the storefront index or product detail page.
- Added the shared app navbar wrapper to storefront product detail pages.

## Local image uploads

- Added `SmartKioskWeb.LocalUploads` for storing LiveView uploads under `priv/static/uploads`.
- Exposed `/uploads/...` through Phoenix static paths.
- Added product image upload support when creating inventory items.
- Added product image upload support when editing inventory items.
- Added shop logo upload support in shop settings, saved to `Shop.logo_url`.
- Added profile picture upload support in account settings, saved to `User.avatar_url`.
- Added `Accounts.change_user_profile/2` so profile validation does not persist changes during `phx-change`.

## Verification

- `mix format` passed after the upload changes.
- `mix compile` passed.
- `mix precommit` still fails because the project has existing warnings treated as errors, including unused helper functions and aliases that were intentionally kept.
