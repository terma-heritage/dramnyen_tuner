# Dranyen — Google Play submission pack

Everything to paste into the Google Play Console for the MVP (Tuner + Learn).
Mirrors the App Store pack in `APP-STORE-LISTING.md`; differences are noted.

- **Package (applicationId):** `net.termaheritage.dramnyen_tuner`
- **App type / category:** App · **Music & Audio**
- **Default language:** English (United States)

---

## URLs

- **Privacy Policy URL (required):** https://termafoundation.org/privacy
- **Support email (required):** info@termafoundation.org
- **Website (optional):** https://termafoundation.org/

## Store listing text

- **App name (≤30):** `Dranyen: Tibetan Lute Tuner` (27 chars)
- **Short description (≤80):**
```
A precise tuner and offline cited guide for the dranyen, the Tibetan lute.
```
- **Full description (≤4000):**
```
Dranyen is a tuner and learning companion for the dranyen (sgra-snyan), the Tibetan lute that has been the heart of Tibetan music for a thousand years. Built by the Terma Heritage Foundation to help keep a living tradition alive.

TUNER
• Tune by the instrument's three open courses — La · Re · So — the way the dranyen is actually tuned, in D major (A = 440 Hz).
• Real-time pitch detection that listens through your microphone and shows, at a glance, whether your string is sharp or flat.
• Calibrate the reference pitch, or "tune to your own La," for instruments that sit a little high or low.
• A clear, glowing gauge with the note in both solfège and numbered notation — and a gentle confirmation when you land in tune.

LEARN
A built-in, offline guide to the instrument and its world, drawn from cited scholarship:
• History & origins — from 7th-century Tibet to survival in exile.
• The instrument — how it's built, and its La·Re·So tuning.
• Notation — the seven notes once named for animal cries, and today's numbers.
• Music & genres — courtly Gharlu, the classical Nangma-Toeshey, and folk songs.
• Sources — the scholarship behind it all.

PRIVATE BY DESIGN
Dranyen collects no personal data. No accounts, no tracking, no ads. The microphone is used only to detect pitch, live, on your device — your audio is never recorded, saved, or sent anywhere. The app works fully offline.

The dranyen's sounds in this app come from recordings by TIPA performer Tenzin Norbu. Corrections from scholars and tradition-holders are warmly welcomed.
```

## Content rating (IARC questionnaire)

- Category: **Utility / Productivity / Communication / Other** → "Reference, News, or Educational."
- Answer **No / None** to every content question (violence, sexuality, language, controlled substances, gambling, user interaction, shares location, etc.).
- Result: **Everyone / PEGI 3 / Rated for 3+**.

## Data safety form

- **Does your app collect or share any user data?** → **No.**
- Microphone: it's a runtime **permission**, not collected data — audio is processed live on-device and never stored or transmitted, so it is **not** declared as data collection.
- **Is all data encrypted in transit?** N/A (no data leaves the device).
- **Do you provide a way to request data deletion?** N/A (no data collected).

## App access

- All functionality is available without login. (No credentials needed for review.)

## Ads

- **Contains ads: No.**

## Target audience & content

- Target age group: 13+ is fine (no child-directed treatment needed), or "All ages" — the app is benign. If you select under-13, extra Families Policy steps apply, so prefer **13 and over** to keep it simple.

---

## Graphic assets

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512 PNG (32-bit) | ✅ `assets/branding/play-icon-512.png` |
| Feature graphic | 1024 × 500 PNG/JPG | ✅ `assets/branding/play-feature-graphic.png` |
| Phone screenshots | 2–8, PNG/JPG, 16:9 or 9:16, each side 320–3840px | ⬜ **needs capture** (see below) |
| 7" / 10" tablet shots | optional | ⬜ optional |

### Screenshots to capture (portrait — app is portrait-locked)
1. Tuner showing a note **in tune** (green glow + strobe frozen) — hero shot.
2. Tuner mid-tuning with the **La · Re · So** course pills.
3. The **Learn** list (five topics).
4. A **Learn article** — "The instrument" (tuning table) or "Notation" (animal-voice scale).
5. (Optional) Calibration sheet ("tune to your own La").

A clean phone size is **1080 × 1920**. Capture on an Android device/emulator, or
ask me to grab a draft set from the running app in Chrome resized to phone size.

---

## ⚠️ Android release signing — REQUIRED before you can upload

`android/app/build.gradle.kts` currently signs the release build with the **debug
key** (`signingConfig = signingConfigs.getByName("debug")`). Google Play will
**reject** a debug-signed bundle. Before the first upload you must:

1. **Create an upload keystore** (do this on your machine, keep it safe — losing it is painful):
   ```
   keytool -genkey -v -keystore dranyen-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Put the secrets in `android/key.properties` (git-ignored — never commit it):
   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=../../dranyen-upload.jks
   ```
3. Wire a real `signingConfig` into `build.gradle.kts` that reads `key.properties`.
4. Enroll in **Play App Signing** (Play manages the app signing key; your upload
   key just signs what you send).

> I can do steps 2–3 (the gradle wiring + a git-ignored `key.properties` template)
> once you've generated the keystore in step 1. I can't create the keystore for
> you securely.

## Build the bundle to upload

Play takes an **App Bundle (.aab)**, not an APK:
```
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```
(Our CI only builds a debug APK today. If you want, I can add a GitHub Actions
job that builds and uploads the signed `.aab` to Play's internal track, mirroring
the iOS TestFlight workflow.)

---

## Submission checklist

- [x] App icon 512 (`play-icon-512.png`)
- [x] Feature graphic (`play-feature-graphic.png`)
- [x] Listing text / short + full description (this doc)
- [x] Privacy Policy URL
- [ ] **Set up release signing** (above) — the main blocker
- [ ] Build signed `.aab`
- [ ] Phone screenshots (2+) uploaded
- [ ] Data safety form: No data collected
- [ ] Content rating questionnaire: Everyone
- [ ] Category Music & Audio, contact email, store settings
- [ ] Create internal-testing release, upload `.aab`, roll out
