# SubBox — Subscription Management App

SubBox is a Flutter app that tracks recurring subscriptions such as streaming services, software, gyms and cloud storage. It records what each one costs and when it renews, so users can avoid unwanted charges.

Built by **Javeria Tahir** for the Zynvex Solutions Internship Program (Batch 4, Mobile App Development).

---

## Features

### Module 1: Project Setup, Firebase Integration & Authentication
- Sign up and sign in with email and password
- **Continue with Google** (a popup on web, the Google account picker on Android)
- **Email verification:** new email accounts must click a link sent to their inbox before they can use the app
- Forgot password (reset link sent by email)
- User profile saved to Cloud Firestore
- Users stay signed in until they sign out

### Module 2: Subscription Management, Categories & Firestore CRUD
- **Add, edit and delete** subscriptions, with these fields:
  - name, category, price, currency
  - billing cycle and next renewal date
  - free trial, payment method, cancellation link
- **7 categories:** Entertainment, Software & AI, Productivity, Utilities, Fitness, Education, Other
- **Fast-fill presets** for 11 popular services (Netflix, Spotify, ChatGPT, YouTube, Figma, Adobe, GitHub Copilot, Notion, Disney+, iCloud+, Gym), each with its brand logo
- **Dashboard:**
  - monthly and yearly totals, active count, and renewals due within 3 days
  - a category filter and countdown badges
- **Notifications bell** listing renewals due soon
- **Real-time sync:** changes appear instantly on every signed-in device
- **Responsive layout:** one column on phones, a wider layout on web

### Module 3: Payment Tracking, Renewals & Notifications
- **Mark as Paid:** records the payment and moves the next renewal forward one billing cycle (month-end and leap-year safe)
- **Payment history** for each subscription, with the total paid
- **Deadlines tab:** a 7-day runway total, then renewals grouped as Critical (under 24h, with a live countdown), This week and Later
- **Renewal reminders:** phone notifications at 9:00 AM, 7 days / 3 days / 1 day before or on the day (chosen per subscription)
- **One-tap cancellation link** that opens the service's cancel page

### Module 4: Dashboard, Expense Analytics & Smart Subscription Insights
- **New navigation** (matching the design): Dashboard · Deadlines · **+** · Alerts · Analytics on phones, and a sidebar on web
- **Dashboard:**
  - search box, an **Upcoming 7-Day Runway** timeline and an **Optimization Insights** preview
  - **Saved to date** total, and a "Price up" tag on subscriptions whose price went up
- **Analytics & Runway tab:**
  - monthly run-rate, projected annual cost, average cost and money saved
  - **spending by category** donut chart
  - **12-month cash flow:** what will actually be charged each month (yearly/quarterly plans land in their renewal month)
  - **payment history:** paid per month for the last 6 months, compared with last month
  - **biggest costs** ranking
  - **currency switcher** (amounts are never mixed or converted between currencies)
  - **export to CSV** (copied to the clipboard, ready to paste into Excel or Google Sheets)
- **Smart insights** (rule-based, most urgent first):
  - trial converting soon
  - renewal overdue
  - **price increase detected** (with yearly impact)
  - pay yearly instead of monthly
  - overlapping services in the same category
  - one subscription taking 40%+ of the budget
- **Alerts tab:**
  - **Urgent:** due within 3 days, overdue or price went up, with Cancel page / Mark paid / Accept new rate actions
  - **Scheduled:** every upcoming reminder
  - **History:** all payments
  - **Reminder settings:** turn reminders on or off and choose the time of day (synced to the phone)
- **Cancel vs. delete:** removing a subscription asks "I cancelled it" (counts towards savings) or "Added by mistake"

### Module 5: Testing, Security, UI/UX Refinement & Deployment
- **Tests:** 39 automated tests for costs, dates, the 12-month projection, insights, reminders, CSV export and validators, plus widget tests that render the Analytics screen on phone and web sizes
- **Security:**
  - [firestore.rules](firestore.rules): users can only access their own data, every write is checked for allowed fields, types and limits, and payment records cannot be edited
  - input validation: amount limits, name length, http(s)-only cancel links (blocks `javascript:` links), and full card numbers are rejected in "payment method"
  - CSV export guards against spreadsheet formula injection
  - web hosting security headers (HSTS, no framing, nosniff)
- **Account settings:** change password (reset email), sign out, and **delete account** (removes all data, then the account; needs a recent sign-in)
- **UI/UX:** empty states with a clear next step, retry on connection errors, consistent cards and tags, responsive phone and web layouts
- **Deployment:** release builds for web (Firebase Hosting) and Android (APK)

---

## Tech Stack

| Area | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Authentication | Firebase Authentication (Email/Password, Google) |
| Database | Cloud Firestore |
| State management | Riverpod |
| Fonts | Google Fonts (Hanken Grotesk, Geist) |
| Notifications | flutter_local_notifications (scheduled reminders) |
| Platforms | Android, iOS, Web |

---

## Project Structure

```
lib/
├── main.dart                          # App start: Firebase init + routing (Login → Verify Email → Home)
├── firebase_options.dart              # Firebase keys (generated by FlutterFire, do not edit)
├── theme.dart                         # Colors and styles from the SubBox design system
│
├── models/
│   └── subscription.dart              # Subscription model, categories, cycles, presets, formatting helpers
│
├── services/
│   ├── auth_service.dart              # Sign up / sign in / Google / email verification / reset / delete account
│   ├── subscription_service.dart      # Firestore CRUD, mark as paid, payments, cancellations, settings
│   ├── analytics.dart                 # Spending analytics, projections, smart insights, CSV (pure functions)
│   └── notification_service.dart      # Plans and schedules renewal reminders on the phone
│
├── screens/
│   ├── login_screen.dart              # Email + password login, Google button
│   ├── signup_screen.dart             # Create account
│   ├── verify_email_screen.dart       # Step 2 for new email accounts
│   ├── forgot_password_screen.dart    # Send password reset link
│   ├── home_screen.dart               # Navigation + Dashboard tab
│   ├── deadlines_screen.dart          # Deadlines tab: critical / this week / later, countdowns
│   ├── alerts_screen.dart             # Alerts tab: urgent / scheduled / history + reminder settings
│   ├── analytics_screen.dart          # Analytics tab: charts, top costs, smart insights
│   ├── account_sheet.dart             # Account settings: password, sign out, delete account
│   └── subscription_form_screen.dart  # Add / edit / remove a subscription
│
├── widgets/
│   ├── app_widgets.dart               # Shared widgets (layout, fields, buttons, stat cards, badges)
│   └── charts.dart                    # Donut, bar and meter charts (drawn by hand, no package)
│
└── utils/
    └── validators.dart                # Form validation (name, email, password)

assets/
├── images/logo.png                # SubBox logo
└── icons/                         # Service logos + Google "G"

test/
├── widget_test.dart               # Unit tests (validators, costs, dates, logos, formatting)
├── analytics_test.dart            # Analytics, insights, reminders, CSV, input validation
└── screens_test.dart              # Widget tests for the Analytics screen (phone + web)

firestore.rules                    # Firestore security rules (deployed with the Firebase CLI)
firebase.json                      # Firebase Hosting + Firestore config
```

### How it fits together

```
main.dart ──► Login / Sign Up / Google ──► Verify Email (new email accounts) ──► Home
                     │                                                          │
              auth_service.dart                                 subscription_service.dart
                     │                                                          │
           Firebase Authentication                  Firestore: users/{uid}/subscriptions
```

### Firestore data

```
users/{uid}                          # name, email, createdAt
users/{uid}/subscriptions/{id}       # name, category, price, currency, cycle, reminders,
                                     # nextRenewal, isTrial, paymentMethod, cancelUrl
users/{uid}/subscriptions/{id}/payments/{id}  # amount, currency, paidAt, forRenewal
users/{uid}/cancelled/{id}           # name, monthlyCost, currency, cancelledAt (for "saved to date")
```
`users/{uid}` also stores `reminderSettings` (on/off and hour), and subscriptions store `previousPrice` after a price change.

---

## Getting Started

### 1. Requirements
- Flutter SDK (stable channel)
- A Firebase project

### 2. Firebase setup
1. **Authentication → Sign-in method:** enable **Email/Password** and **Google**.
2. **Firestore Database:** create the `(default)` database (we used `asia-south1`).
3. **Firestore rules:** deploy [firestore.rules](firestore.rules). Each user can only access their own data, and every write is validated.
   ```bash
   firebase deploy --only firestore:rules
   ```
4. **Android Google sign-in:**
   - Add your SHA-1 fingerprint under Project settings → Your apps → Android.
   - Download `google-services.json` into `android/app/`.
   - To get the debug SHA-1, run:
     ```
     keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
     ```

### 3. Run
```bash
flutter pub get
flutter run            # pick an Android device or Chrome
```

### 4. Test
```bash
flutter test
flutter analyze
```

### 5. Deploy
```bash
# Web → Firebase Hosting (https://subscription-box-app-9ad03.web.app)
flutter build web --release
firebase deploy --only hosting,firestore:rules

# Android → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release
```
For the web build, add the hosting domain under **Authentication → Settings → Authorized domains** if Google sign-in shows an "unauthorized domain" error.

> **Windows note:** `android/gradle.properties` sets `kotlin.incremental=false` because the project (D:) and the pub cache (C:) are on different drives, which breaks Kotlin's incremental build cache.

---

## Roadmap

| Module | Scope | Deadline | Status |
|---|---|---|---|
| 1 | Project Setup, Firebase Integration & User Authentication | Sep 27, 2026 | ✅ Done |
| 2 | Subscription Management, Categories & Firestore CRUD | Oct 04, 2026 | ✅ Done |
| 3 | Payment Tracking, Renewals & Notifications | Oct 11, 2026 | ✅ Done |
| 4 | Dashboard, Expense Analytics & Smart Subscription Insights | Oct 18, 2026 | ✅ Done |
| 5 | Testing, Security, UI/UX Refinement & Final Deployment | Oct 25, 2026 | ✅ Done |

---

## Credits
- App logo icon by [bqlqn](https://www.flaticon.com/authors/bqlqn) from [Flaticon](https://www.flaticon.com/)
- Service logos are trademarks of their respective owners and are used only to identify the services.
