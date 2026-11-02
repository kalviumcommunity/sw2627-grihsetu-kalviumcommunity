# Accessibility and Responsive Regression

Run on 31 October 2026 with Flutter widget tests and the deterministic demo dataset.

## Matrix

- Viewports: 360x640, 390x844, 768x1024, 1280x800, 1920x1080
- Themes: light and dark
- Text scales: 1.0, 1.3, 2.0
- Guideline viewports: 390x844 and 1280x800 in both themes
- Rules: overflow/layout exceptions, Android and iOS tap targets, labeled tap targets, text contrast, and icon-button labels

## Triage

| Screen | Size / scale / theme | Rule | Severity | Result |
| --- | --- | --- | --- | --- |
| Role workspace roots | Full matrix | Overflow / layout exception | Blocker | Pass |
| Tenant and operations roots | 390x844 and 1280x800, both themes | Tap targets / labels / contrast | Blocker | Pass |
| Complaint creation actions | 390x844 / 1.0 / light | Horizontal RenderFlex overflow | Blocker | Pass after responsive action layout fix |
| Legacy assignment workflow fixture | 1000x1400 / 1.0 / light | Assign action not reachable in fixture | Blocker | Known issue inherited from GRIH-049 |

## Counts

Before: 2 blockers, 0 major, 0 minor.

After: 1 known blocker, 0 major, 0 minor. The remaining blocker is isolated to
the legacy assignment fixture; the production role roots and complaint flow
pass the regression checks.

## Reproduction

```text
flutter test test/a11y/responsive_matrix_test.dart
flutter test test/a11y/accessibility_guidelines_test.dart
flutter test test/workflows/complaint_creation_workflow_test.dart
```

The suites print a consolidated table before failing so all detected configurations can be triaged in one run.
