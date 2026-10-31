# Five-minute demo flow

Use the deterministic dataset from [DEMO_SETUP.md](DEMO_SETUP.md). Start from
the 6 October 2026 fixture state and keep the window at 1280x800. Passwords are
environment-managed and are intentionally not stored in the repository.

The three provisioned staff accounts are:

- Riya Sharma — `riya.sharma@grihsetu.com` — Complaint Operations
- Aman Verma — `aman.verma@grihsetu.com` — Technician
- Vikram Malhotra — `vikram.m@grihsetu.com` — Property Operations

For the tenant and owner portions, use the locally supplied Tenant and Property
Owner demo profiles. The fixture tenant is Kabir Mehta
(`kabir.mehta@example.com`); cloud authentication for tenant and owner profiles
must be provisioned by the demo environment because `DEMO_SETUP.md` deliberately
defines only trusted staff accounts.

## 0:00–0:45 — Tenant raises a complaint

1. Sign in with the Kabir Mehta tenant profile.
2. Select **Complaints** in the navigation bar, then **Raise complaint**.
3. On **Where is the issue?**, verify **Green Heights · Flat A-204**, then select
   **Continue**.
4. On **What needs attention?**, select **Plumbing**, enter a short title and
   description, choose **High**, then select **Continue**.
5. Continue through **Add evidence** and **Plan the visit**.
6. On **Review complaint**, select **Submit complaint** and call out the stable
   complaint ID on **Complaint submitted**.

## 0:45–1:30 — Staff assigns the complaint

1. Sign out and sign in as Riya Sharma.
2. Select **Complaints**, search for the new complaint ID, and open it.
3. Select **Assign technician**, choose **Aman Verma**, then confirm the
   assignment.
4. Point out the **Assigned** status and the new assignment entry in **Audit
   timeline**.

## 1:30–2:40 — Technician completes the visit

1. Sign out and sign in as Aman Verma.
2. Select **Assigned Work**, then open the newly assigned complaint.
3. Select **Start visit** and advance the enabled steps in order: travel,
   arrival, inspection, and repair.
4. Open the completion form, choose **Resolved**, fill every required finding,
   repair, notes, parts, and after-photo field, then submit.
5. On the success state, select **Back to queue** and show that the item is no
   longer active work.

## 2:40–3:15 — Tenant confirms the repair

1. Sign out and return to the Kabir Mehta tenant profile.
2. Select **Complaints**, open the same complaint, and select **Confirm fixed**.
3. Call out the closed status and tenant-confirmation entry in the timeline.

## 3:15–4:00 — Owner reviews the portfolio

1. Sign out and use the Property Owner demo profile.
2. Select **Overview** and review the property summary and complaint totals.
3. Open **Complaints**, search for **Persistent kitchen pipe leakage under
   sink**, and point out the **Reopened** badge and repeat-visit count.
4. Return to **Overview** and show the same recurring issue reflected in the
   read-only summary.

## 4:00–5:00 — Staff records a rent follow-up

1. Sign out and sign in as Vikram Malhotra.
2. Select **Rent**, filter to **October 2026**, and open Kabir Mehta's
   `rnt_3004` record for **Flat A-204**.
3. Select **Add follow-up**, choose **Call** and **Promised to pay**, enter the
   promised date and amount, add a short note, then save.
4. Show the new follow-up in history and the updated promised status.

## Recovery

Restart the local app to restore in-memory fixtures. For a connected Firebase
demo, use the documented debug seeding flow before the session; developer tools
are intentionally absent from release builds.
