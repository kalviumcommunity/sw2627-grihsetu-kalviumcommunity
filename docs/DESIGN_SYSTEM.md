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
