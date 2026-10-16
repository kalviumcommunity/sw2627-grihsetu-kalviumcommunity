# GrihSetu design system

## Colour tokens

Use `context.palette` from `lib/theme/app_palette.dart`; widgets should not define local colors.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| canvas | `#F6F2EA` | `#101917` | Page background |
| surface | `#FFFDFA` | `#192421` | Cards and panels |
| raised | `#FFFFFF` | `#22312D` | Hovered surfaces |
| ink | `#172522` | `#EAF2EF` | Primary text |
| muted | `#53635E` | `#B4C3BE` | Supporting text |
| border | `#D5DCD5` | `#42534D` | Dividers and outlines |
| accent | `#0F4C45` | `#8FD2C2` | Primary actions and highlights |
| accentSoft | `#E2F0E9` | `#29463F` | Soft accent backgrounds |
| success | `#246B36` | `#9BD7A5` | Positive states |
| warning | `#805400` | `#FFD18A` | Attention states |
| danger | `#9B2921` | `#FFB4AB` | Error states |
| shimmer | `#E4E9E3` | `#33443E` | Loading placeholders |

Pair ink/muted/accent text with surfaces and accentSoft, respectively. Keep body text at 4.5:1 contrast or higher.

## Type scale

| Style | Size | Use |
| --- | --- | --- |
| displayLarge | 40 | Marketing hero |
| headlineMedium | 28 | Page title |
| titleLarge | 22 | Section title; use Fraunces |
| titleMedium | 18 | Card and timeline title |
| bodyLarge | 16 | Primary reading |
| bodyMedium | 14 | Standard body |
| bodySmall | 12 | Metadata |
| labelMedium | 12 | Compact labels |

Use the theme's text styles and allow wrapping at 1.3 text scale.

## Spacing and radii

Use a 4px base: `4, 8, 12, 16, 20, 24, 32, 40`. Standard card padding is 20px; page padding is 24px. Use 12px card radius, 8px controls, and fully round icon circles. Tap targets are at least 48px square.

## Reusable widgets

```dart
AppCard(onTap: openComplaint, child: const Text('Kitchen sink leak'));
SectionHeader(title: 'Open work', trailing: TextButton(onPressed: seeAll, child: const Text('See all')));
StatTile(label: 'Open complaints', value: '12', delta: '3 resolved today');
EmptyState(icon: Icons.inbox_outlined, title: 'All caught up', message: 'New updates appear here.');
ErrorState(message: 'Try again in a moment.', onRetry: reload);
SkeletonBox(width: 160, height: 20);
const SkeletonList(itemCount: 3);
AuditTimeline(events: events); // Oldest first; newest event receives the pulse.
```

AppCard supports optional tap/hover feedback. SectionHeader accepts an optional trailing action. StatTile accepts an optional delta. EmptyState accepts an optional action label and callback. ErrorState always offers Retry. SkeletonBox pulses without shimmer; SkeletonList repeats a card placeholder. AuditTimeline supports 1–30 events with actor, role, timestamp, optional note, and optional tone.

## Status, priority, and category chips

Prefer these strongly-typed components over ad-hoc containers or bespoke badge implementations:

- **`ComplaintStatusChip`** (from `lib/widgets/complaint_chips.dart`):
  Covers all 8 operational statuses (`open`, `assigned`, `inProgress`, `waitingForParts`, `resolved`, `closed`, `reopened`, `cancelled`). Maps each status to a distinct semantic tone (`context.palette`) and intuitive iconography (`Icons.check_circle_outline`, `Icons.hourglass_top_outlined`, `Icons.cancel_outlined`, etc.). Provides backwards-compatible `ComplaintStatusBadge` alias.
- **`ComplaintPriorityChip`** (from `lib/widgets/complaint_chips.dart`):
  Covers all 4 operational priorities (`low`, `medium`, `high`, `urgent`). Maps each priority to an appropriate semantic tone (neutral, accent, warning, danger) and directional/warning iconography. Provides backwards-compatible `ComplaintPriorityBadge` alias.
- **`ComplaintCategoryChip`** (from `lib/widgets/complaint_chips.dart`):
  Covers all 8 complaint categories (`plumbing`, `electrical`, `structural`, `appliance`, `security`, `cleaning`, `commonArea`, `other`). Renders trade-specific outlined icons alongside the category display label with compact contrast-safe styling.
- **`StatusBadge`** (from `lib/widgets/status_badge.dart`):
  A generic primitive for arbitrary text badges that accept any `StatusBadgeTone` (`neutral`, `accent`, `success`, `warning`, `danger`).

```dart
// Usage examples
ComplaintStatusChip(status: complaint.status);
ComplaintPriorityChip(priority: complaint.priority);
ComplaintCategoryChip(category: complaint.category);

// Safe parsing constructor with fallback
ComplaintStatusChip.fromValue(rawStatusString, fallback: ComplaintStatus.open);
```

## Action feedback and dialogs

Prefer `ActionFeedback` from `lib/utils/action_feedback.dart` over raw, inline `ScaffoldMessenger.of(context).showSnackBar` calls or ad-hoc alert dialogs.

- **Unified replacement policy**: Automatically clears any existing floating SnackBar to prevent stack-up during rapid user taps.
- **Accessible & theme-aware**: Uses `context.palette` to tint the floating surface and apply semantic icons and border colors with high contrast in both light and dark themes.
- **Safety**: Guards against unmounted `BuildContext` invocations.

```dart
// Success feedback (e.g. after successful technician assignment or photo upload)
ActionFeedback.showSuccess(context, 'Assigned to Ramesh Meena');

// Error feedback (e.g. when network or Firestore call fails)
ActionFeedback.showError(context, 'Failed to update visit step');

// Warning feedback (e.g. photo limit validation)
ActionFeedback.showWarning(context, 'Maximum 5 photos allowed');

// Informational feedback (e.g. action stubs or status tips)
ActionFeedback.showInfo(context, 'Calling technician stub...');

// Standard confirmation dialog (returns Future<bool?>)
final confirmed = await ActionFeedback.showConfirmationDialog(
  context,
  title: 'Confirm Completion',
  message: 'Are you sure you want to mark this visit as resolved?',
  confirmLabel: 'Confirm',
  cancelLabel: 'Cancel',
  isDestructive: false,
);
```

### Guidance & exceptions
Always use `ActionFeedback` and the shared chips across operational complaint workflows, queues, detail pages, and visit steps. Direct inline `SnackBar` implementations or custom dialogs are reserved solely for dev/debug tools (e.g., reference data seeder) or deeply customized full-screen modal flows.
