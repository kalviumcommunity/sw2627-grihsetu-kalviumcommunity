# Demo capture shot list

Capture PNG images at the exact logical window size below. Use the deterministic
6 October 2026 fixture state, hide browser chrome, and avoid personal data not
already present in the demo fixtures.

| Filename | Screen | Role | Window | Required state |
| --- | --- | --- | --- | --- |
| `01-tenant-home.png` | Tenant home | Tenant · Kabir Mehta | 390x844 | Signed in, navigation and home summary visible |
| `02-complaint-review.png` | Raise complaint · Review | Tenant · Kabir Mehta | 390x844 | Green Heights / A-204, Plumbing, High, submit action visible |
| `03-complaint-submitted.png` | Complaint submitted | Tenant · Kabir Mehta | 390x844 | Stable complaint ID and Open badge visible |
| `04-staff-assignment.png` | Assign technician sheet | Complaint Operations · Riya Sharma | 1280x800 | Aman Verma selected as best available match |
| `05-assigned-audit.png` | Complaint details | Complaint Operations · Riya Sharma | 1280x800 | Assigned badge and assignment audit event visible |
| `06-technician-visit.png` | Technician Visit | Technician · Aman Verma | 390x844 | Active inspection/repair step with progress visible |
| `07-visit-resolved.png` | Visit completion success | Technician · Aman Verma | 390x844 | Resolved outcome and Back to queue action visible |
| `08-tenant-confirm.png` | Complaint details | Tenant · Kabir Mehta | 390x844 | Resolution confirmation prompt visible |
| `09-owner-summary.png` | Operations overview | Property Owner | 1280x800 | Read-only portfolio summary and recurring issue visible |
| `10-owner-print.png` | Owner summary print view | Property Owner | 1920x1080 | `printMode` summary with no interactive controls |
| `11-rent-follow-up.png` | Rent detail / follow-up | Property Operations · Vikram Malhotra | 1280x800 | October 2026 promise details and follow-up history visible |
| `12-dark-dashboard.png` | Operations overview | Complaint Operations · Riya Sharma | 1280x800 | Dark theme, attention items populated |

Video cannot be recorded by this automated workflow. A human should follow
`docs/DEMO_FLOW.md` with screen recording enabled if a narrated capture is
required.
