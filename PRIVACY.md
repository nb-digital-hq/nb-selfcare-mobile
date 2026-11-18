# Privacy

NB SelfCare Mobile is built so that your health data never needs to leave your phone. This is the short, binding
statement; the detailed audit is in [docs/audit/privacy.md](docs/audit/privacy.md) (Spanish).

## What the app does not do

* No account, sign-in, licence check or registration of any kind.
* No telemetry, analytics, crash reporting or usage tracking, including "anonymous" or opt-out variants.
* No advertising and no third-party SDK that reports to anyone.
* No log files: nothing about your meals, weight, medicines or symptoms is written to the system log.
* No cloud backup: Android's automatic backup is disabled (`android:allowBackup="false"`).

## Where your data lives

Everything is stored in a single SQLite database inside the app's private storage. It leaves the phone only if you
export a backup yourself (a `.sqlite` file you choose where to send) or print or share the PDF report.

## The only two connections to the internet

Every network connection is built in `lib/core/network/`, and an automated check rejects any HTTP client or
socket anywhere else. There are exactly two destinations, and both start with a tap:

| Destination | When | What is sent |
|---|---|---|
| Open Food Facts (`world.openfoodfacts.org`) | You scan a barcode that is not in your catalogue, or tap "Search on Open Food Facts" | The barcode or the search words. No personal data. The result is saved on the phone |
| GitHub (`api.github.com`, `github.com`) | Android only: you tap "Check for updates" | A request for the latest release. No personal data |

## Health Connect (Android)

If you connect it, the app reads steps, sleep, resting heart rate, weight, body fat, hydration and, only for the
devices you declare, blood pressure, glucose, oxygen saturation and temperature. It writes your weigh-ins, body fat,
water and guided breathing sessions so other apps you choose can see them. Health Connect is part of Android and
keeps that data on the device. You can withdraw any permission at any time.

## Camera, microphone and Bluetooth

* **Camera:** only for the barcode scanner, decoded on the phone with the open-source zxing-cpp library. No image
  is stored.
* **Microphone:** only for meal dictation, and only when the phone offers offline speech recognition.
* **Bluetooth:** only to read the Xiaomi Mi Scale 2 if you declare one. The app reads the scale's broadcast; it
  never connects to anything else.

## Medicines and reminders

Dose reminders are discreet by default: they do not show the medicine's name, and the lock screen only shows that
you have a reminder.

## Not a medical device

NB SelfCare Mobile is not a medical device. Bioimpedance values and fasting phases are estimates, and the app does
not diagnose or treat any condition.
