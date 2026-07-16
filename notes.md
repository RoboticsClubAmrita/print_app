# Tour Fixes – 16 Jul 2026

## Completed

### Tour Flow
- Fixed cross-tab showcase overlay issue caused by `IndexedStack` keeping inactive tabs mounted.
- Added a generation token to prevent stale asynchronous tour starts after tab switches.
- Dismiss active showcase before every tab switch to prevent lingering overlays.
- Centralized guided tour scheduling in `ShellScreen`.
- Converted tab-specific tour starts to synchronous `startTourNow()` methods.
- Fixed Back navigation to restore the previous tab's tour from its first step.
- Preserved forward tour progression after resuming from Back navigation.
- Prevented completed tours from restarting when users revisit pages.

### UI Updates
- Added **Today's Prints** to the Home screen guided tour.
- Added **Total Due / Pending Payments** to the Billing screen guided tour.
- Updated the guided tour sequence to include the newly added UI components.

## Files Modified

- `lib/screens/shell_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/orders_screen.dart`
- `lib/screens/billing_screen.dart`

## Verification

- ✅ Cross-tab showcase overlays no longer persist.
- ✅ Back navigation resumes the correct tour flow.
- ✅ Newly added Home and Billing widgets are included in the tour.
- ✅ Completed tours do not restart when revisiting screens.
- ✅ Guided tour progression remains consistent across all tabs.