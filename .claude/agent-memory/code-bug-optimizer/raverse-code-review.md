---
name: raverse-code-review
description: Recurring bug patterns and conventions found reviewing THE RAVERS iOS SwiftUI app (Ravers-ios)
metadata:
  type: project
---

THE RAVERS iOS app (dir: Ravers-ios/, iOS 17+ @Observable MVVM, Supabase stubbed). State observed during 2026-08-15 code review.

**Why:** App is in early scaffold stage — most feature screens are placeholder Text() stubs; Home is the only built screen.
**How to apply:** When reviewing, expect stubs; focus real bug-hunting on Home (HomeView/HomeViewModel/ProductDetailView) and Auth flow, which have actual logic.

Recurring patterns to watch for in this codebase:
- **Asset-name drift**: `Image("name")` string literals frequently reference assets that don't exist in Assets.xcassets. Only these exist: bg-img, cap, chain, hoody (EMPTY placeholder - Contents.json but no image file), jacket, jeans, logo, t-shirt. HomeViewModel mock data uses many phantom names (sin-01, hoodie-b, tee-a, ravers-tee, hoodie-a, shirt-a, glasses-a, pants-a). Missing assets render blank silently (no crash).
- **Data-model vs UI mismatch**: `Product.imageName` exists but views (CatalogCard, HeroProductCard) ignore it and hardcode Image("t-shirt")/shapes. Category strings in mock data ("HARDWARE") don't always match the category filter buttons.
- @main in Raverse_iosApp.swift boots HomeView() directly; RootView() + auth flow commented out.
- ViewModels own their own @State in each View (no shared injection except AuthViewModel via .environment in the currently-unused RootView).

Conventions: Chrome Noir palette in Color+Theme.swift (rvRed, rvBackground, etc). Prices are Int rupees, rendered `₹\(price)` with no grouping. Fonts via Font+Theme rvDisplay/rvBody/rvMono (system fonts for now).
