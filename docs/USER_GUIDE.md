# Tiffin — User Guide (v3)

For the people running the canteen day to day. Tiffin is one **app** installed
on every phone. The canteen's records live in its own **Firebase** project, so
every phone sees the same members and balances — and every phone **keeps
working without internet**, syncing when the connection comes back. The
product rules (units, meal windows, grace allowance, scan reversal, billing)
are unchanged; see `docs/PRD.md` §5–§8.

The app speaks **English, हिन्दी and मराठी** — each phone picks its own under
**Settings ▸ Appearance ▸ Language**.

---

## 1. Roles

| Role | Who | Can do |
|---|---|---|
| **Admin** | The contractor | Everything: members, top-ups & billing, top-up history & reversal, QR codes, menu planning, kitchen setup (ingredients + recipes), purchase schedule, expenses, refunds, settings, scan reversal, accounts, phones. |
| **Counter** | Billing-counter staff | Scan, top-ups & billing, and the shared purchase schedule. Nothing else. |
| **Scanner** | Meal-serving staff | Scan only. |

Students and staff are **records**, not logins — they carry a QR code and get
scanned.

**Phones have a role too.** An admin approves each phone as an admin, counter
or scanner phone, and that caps who can sign in on it: an admin phone allows
everyone, a counter phone allows counter and scanner accounts, a scanner phone
allows scanner accounts only. Approve each phone with the narrowest role it
needs — the gate phone as a scanner phone.

---

## 2. First-time setup

### 2.1 The Firebase project (once, by whoever sets the canteen up)

Follow **Firebase setup** in the README: create the project, turn on the
sign-in methods, create the database, deploy the rules, and download the
**config file** for the app. That file is the only thing the app is ever
configured with.

### 2.2 The first phone

1. Install and open the app. It asks you to **connect to your Firebase
   project** — tap **Choose config file** and pick the file you downloaded.
2. **Set up this phone**: give it a name you'll recognise (e.g. "Office") and
   tap **Join this canteen**. This needs internet once.
3. Nobody has used the project yet, so it offers **Start the canteen on this
   phone**. This phone becomes the first **admin phone**.
4. **Create the admin account**: choose a username and password. **Suggest a
   strong one** fills both boxes and shows the password so you can write it
   down — it's stored only as a one-way hash.
   - *Moving from the earlier version of Tiffin?* Instead of creating an
     account, tap **Bring over existing records?** and pick the `.tiffin`
     backup you made on the old host phone. Members keep their QR codes and
     everyone keeps their old password.

### 2.3 Every other phone

1. Install the app and pick the **same config file**.
2. Name the phone ("Counter 1", "Gate") and tap **Join this canteen**. It
   shows **Waiting for approval** with a short **phone code**.
3. On the admin phone: **Settings ▸ Devices**, find the phone (match the
   code), tap **Approve**, and pick its role. The waiting phone moves on by
   itself.
4. Sign in with an account. Accounts are made under **Settings ▸ Users**.

A phone that's lost or replaced: **Settings ▸ Devices ▸ Remove**. It can ask
again later, and has to be approved again.

### 2.4 Online accounts (optional)

**Settings ▸ Online accounts ▸ Allow online accounts** adds a second kind of
account: an **email and password** that works on *any* phone without
approving the phone first — handy for the owner's own phone. On a phone that
hasn't joined, tap **Sign in with an online account instead**. Online accounts
need internet to sign in; "Email me a reset link" handles a forgotten
password. Turn one off from the same screen. Offline accounts keep working
either way.

### 2.5 Scanning

Scanning uses the phone camera directly — grant the camera permission when
asked. While the scan screen is open the phone stays awake.

---

## 3. Daily use

### 3.1 Scan (counter / scanner / admin)

Open **Scan**, point at the QR. The verdict fills the screen:

- **Green ACCEPTED** — name, meal, units left. A yellow **ON GRACE ALLOWANCE**
  badge means the balance went negative.
- **Red REJECTED** — the reason in plain words (unknown code, inactive member,
  no meal being served now, already collected today, no units left).

Tap **Next** for the next person. A member can only be scanned once per meal
per day.

**No internet?** Keep scanning. A yellow **Offline — changes will sync**
banner shows on the scan screen (a cloud-off icon on other screens), and every
scan goes up when the connection returns. If the same person was served the
same meal on another offline phone, the later scan is dropped when it syncs —
their unit is given back — and a **Offline scan not counted** notification
says who.

### 3.2 Top-up & bill (counter / admin)

**Top-up & bill** → tap the member field to open a searchable picker (name,
class, roll number or staff ID). Not on the list yet? **+ New member** adds a
walk-up member without leaving the screen. Then set units per meal type with
+/− → pick **Cash** or **UPI**. The amount is calculated from the unit prices
in Settings — you never type it. **Charge & generate bill** credits the
balance immediately and shows the bill; **Share bill** sends it as a PDF
(WhatsApp, email, print) in this phone's language. For UPI it also shows a payment QR for
the payer to scan; once the money lands, tap **Mark received**.

The **History** tab (same screen) lists every top-up, newest first.
**Reverse** on a top-up subtracts the units it credited back off the member
and records the reversal (who, when). The row stays, marked reversed — it is
never deleted. A reversal is refused once any of those units have been used;
process a **Refund** instead.

### 3.3 Members (admin)

**Members** → **New** for a student (class + roll) or staff (staff ID), and
pick a **category** (Jain / Normal / Staff… — the same list as menu
categories; defaults to Normal). Tap a member to edit — including switching
student ↔ staff and changing the category — set them inactive, or set a
per-member grace override. The category is what lets a scan count against
that group's planned plates. **Credit** adds units without a bill. **QR**
shows the printable code — it never changes, so reprinting a lost card is
safe.

### 3.4 Scan log & reversal (admin)

**Scan log** lists recent scans. **Reverse** on an accepted scan within the
configured window (Settings → reversal window) restores the unit. The scan
row stays in the log, marked reversed.

### 3.5 Menu, kitchen setup, purchase schedule (admin; counter co-manages the schedule)

- **Menu calendar** — tap a day, then **Add** one entry per **category**:
  pick the meal, pick the **category** (or add one on the spot), enter
  **approx plates**, and the items one plate of that category gets. "Monday
  lunch" for 3 groups is 3 entries. Tap an entry to edit its plates/headcount;
  the `(date, meal, category)` combination is unique so you edit rather than
  duplicate. Manage the category list from the **⊞** button in the top bar or
  **Settings ▸ Menu categories**.
- **Recipes** hold **per-plate** quantities. The purchase schedule multiplies
  them by each entry's headcount.
- **Ingredients = inventory.** Each row shows on-hand **stock** and a **LOW**
  badge when it's at or below its alert threshold. Set stock and the threshold
  on the ingredient form; use the **⚙ tune** icon for a quick correction
  (delivery, spoilage) with a reason. Stock goes **down** automatically on
  each accepted scan (the person's meal's recipes) and **up** when you mark a
  purchase-schedule item bought.

- **Kitchen setup** — two tabs, done once at setup:
  - **Ingredients** — your master shopping list. Each has a name and the
    **unit** you buy it in, chosen from a short list (kg, litre, packet…) or
    **Custom**.
  - **Recipes** — "when the menu says *Veg Pulao*, that needs Rice 2, Onion
    1…". A dish name linked to the ingredients it uses, each with a **quantity
    number** in that ingredient's unit. You can create a missing ingredient
    without leaving the recipe form.
- **Purchase schedule** — the ↻ / generate action reads the menu calendar for
  a date range and, for each entry, multiplies its per-plate recipes by the
  **headcount**, sums per ingredient per date, and rounds up to 2 dp. Safe to
  re-run — changing a headcount and regenerating updates the un-purchased
  lines; purchased and one-off lines are left alone. If it adds nothing it
  tells you which link is missing. Ticking an item **bought** asks for the
  actual quantity received (→ ingredient stock) and, optionally, what it cost
  (→ Expenses); un-ticking rolls both back. Add one-off items with the **+**
  button.

**The chain:** Menu calendar (what's cooked) + Recipes (what each dish needs)
→ Purchase schedule (what to buy).

### 3.6 Expenses, refunds (admin)

- **Expenses & revenue** — log expenses; the top strip shows revenue
  (confirmed top-ups), expenses, and profit for the period.
- **Refunds** — deduct units from a leaving member and record it. Units
  pre-fill from their balance and can't exceed it. The actual payout happens
  outside the app.

### 3.7 Notifications

The bell in the top bar shows: prep reminders (before a planned meal's
window), purchase-due reminders, **low stock** (an ingredient at or below its
threshold — also shown to the scanner), and **headcount overrun** (accepted
scans for a category/meal have reached the planned plate count). **Offline scan
not counted** appears when a scan made without internet turned out to be a
duplicate (3.1). Dismissing one only hides it for you. The scan screen also
flags an overrun inline — "Planned about 15 Jain — this is plate 16".

### 3.8 Settings (admin)

Settings is a short menu of rows, not one long form. Each opens its own screen:

- **Canteen configuration** — app name, unit prices, meal windows, timezone,
  grace allowance, scan-reversal window, reminder lead times, UPI. All runtime,
  no reinstall; one **Save** button, kept in reach at the bottom.
- **Users & access** — see 3.9.
- **Menu categories** — the tag list for menu entries (also editable from the
  menu planner's top bar).
- **Appearance** — see 3.10.
- **Devices** — approve, re-role and remove phones (2.3).
- **Online accounts** — the optional email accounts (2.4).
- **Reports** — see 3.11.
- **Backup & restore** — see 3.11.
- **Sign out** — ends this session on this phone.
- **Firebase project** — which project this phone uses. *Change* signs out
  and forgets this phone's copy of the data (nothing is deleted in Firebase);
  changes not yet synced from this phone are lost, so do it online.
- **Reset all data** — deletes every record in the project (accounts too),
  then asks for a new admin. Needs internet. No undo — take a backup first.

**Counter and scanner** open the same Settings screen from the **⚙ gear** in
the top bar. Their version shows **Appearance**, **Sign out** and **Firebase
project** — same layout, fewer rows.

### 3.9 Users & access (admin — inside Settings)

Add **offline accounts** (username + password), change usernames, change
roles, reset passwords, deactivate. You can't deactivate or delete your own
account. A forgotten admin password can be reset from **Forgot the password?**
on the sign-in screen of an *admin phone*.

### 3.10 Appearance (everyone, per device)

**Settings ▸ Appearance** — reached from the admin dashboard's Settings tile,
or the **⚙ gear** in the top bar for counter and scanner.

- **Theme** — Neobrutal, Clean, Frost or Clay, each previewed live.
- **Light or dark** — or follow the phone's own setting.
- **Animations** — turn them off entirely. Your phone's own "reduce motion"
  accessibility setting always wins, whatever is chosen here.

Each phone keeps its own choice. An admin can make every device match: turn on
**Use this look everywhere** at the bottom of the screen. Every phone then shows
that look, and says so rather than quietly ignoring taps.

The same screen lists **saved logins** and clears them.

### 3.11 Reports, and Backup & restore (admin — two screens under Settings)

**Reports** — an `.xlsx` for Excel or Google Sheets, with a tab per area
(summary, members, balances, scans, top-ups, refunds, expenses, menu). Pick a
date range and which tabs you want, then it goes out through the normal share
sheet, with headings in this phone's language. It is for reading and printing; it is *not* a way to put data back —
that is what **Backup & restore** is for.

**Backup** — a complete copy of the canteen in one `.tiffin` file: members,
balances, history, settings and accounts. The data already lives safely in
Firebase; this is *your* copy, outside Google's, and the way to move to a new
Firebase project.

- Leave **Protect with a password** on unless you have a reason not to. The
  file holds member names and account details. Write the password down —
  without it the backup cannot be opened by anyone, including you.
- **Restore from a backup** replaces *everything* in the project, for every
  phone. It shows what the file contains first and asks you to type the
  confirmation word (REPLACE, or its translation). The whole file is read and
  checked before anything is deleted. Needs internet.

Take a backup now and then, and keep it somewhere off the phone.

### 3.12 Staying signed in

A phone remembers who signs in on it, so the next launch skips the sign-in
form until the session ends (12 hours) or someone signs out. Usernames are
always remembered; a password is only kept if you tick **Remember password on
this device**. Clear any of it from **Appearance ▸ Saved logins**.

---

## 4. If something's wrong

- **"Waiting for approval" never moves on** — the admin phone needs
  internet to approve, and so does the waiting phone to notice. Check both are
  online, and that the admin approved the right phone code.
- **"This phone isn't allowed to do that"** — the phone's role is narrower
  than the job. Change it in **Settings ▸ Devices** on an admin phone.
- **Offline for a long time** — fine for scanning and top-ups. Balances other
  phones changed meanwhile aren't seen until this phone syncs, so a person
  could be served on their last unit at two offline counters; reports show any
  balance that went negative.
- **Check offline sync before a real shift:** approve two phones, turn on
  airplane mode on both, scan the same person for the same meal on each, turn
  airplane mode off. One scan stays, the other is dropped with a notification,
  and the balance goes down once.
- **"That file is for a different app"** on the connect screen — the config
  file was downloaded for another app id. Add an app with the id the message
  names in the Firebase console and download its file.
- **Camera won't open** — grant the camera permission in the phone's settings
  for Tiffin.
- **Logs** — every phone writes a rolling log (`logs/app.log` under the app's
  documents directory) of scans, top-ups, refunds, admin actions and anything
  the server refused.
