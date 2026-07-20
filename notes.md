# Tour & Upload UX Fixes – 16 Jul 2026

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

### Document Upload UX
- Replaced the blocking full-screen upload overlay with an inline upload state.
- Added an animated glowing border to the document upload widget during upload.
- Kept the document icon and content visible while uploading.
- Disabled upload interactions (and send action) until upload completes while keeping the rest of the UI interactive.
- Added a remove action for uploaded documents.
- Clearing a document now resets all dependent upload state (pages, analysis, cached results, etc.) and restores the upload widget to its default state.

## Files Modified

- `lib/screens/shell_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/orders_screen.dart`
- `lib/screens/billing_screen.dart`
- `lib/widgets/fx.dart`
- `lib/widgets/field_chip.dart`
- `lib/widgets/upload_progress.dart` *(removed from active flow / optional cleanup)*

## Verification

- ✅ Cross-tab showcase overlays no longer persist.
- ✅ Back navigation resumes the correct tour flow.
- ✅ Newly added Home and Billing widgets are included in the tour.
- ✅ Completed tours do not restart when revisiting screens.
- ✅ Guided tour progression remains consistent across all tabs.
- ✅ Uploads display an inline animated loading border instead of a blocking overlay.


# Tour & Upload UX Fixes – 17 Jul 2026

## Completed

### Document Upload UX
- Added a remove (X) action to the uploaded document chip.
- Users can now remove an uploaded document without placing an order.
- Extracted document reset logic into a shared helper to avoid duplicated state-clearing code.
- Removing a document now clears all document-derived state (selected file, uploaded file ID, detected pages, selected pages, file size, etc.) while preserving independent print settings.
- Upload widget immediately returns to its default "Tap to upload a file" state after removal.
- Users can immediately upload another document after removing the current one.

### Upload Animation
- Updated the animated upload glow border from white to black.
- Preserved the existing animation timing, sweep effect, border thickness, radius, and upload behaviour.

## Files Modified

- `lib/screens/home_screen.dart`
- `lib/widgets/fx.dart`

## Verification

- ✅ Uploaded documents can be removed using the new X action.
- ✅ Removing a document resets all document-derived state.
- ✅ Print settings remain unchanged after document removal.
- ✅ Upload widget returns to its default state after removal.
- ✅ Users can immediately upload another document.
- ✅ Upload glow now uses a black sweep while preserving the existing animation.
- ✅ Existing upload flow remains unchanged.
- ✅ Guided tour behaviour remains unaffected.
