# How to Install My Echo (Without an App Store Certificate)

**My Echo** is an open-source, self-distributed Swift 6 / SwiftUI app. Because GitHub releases are **not signed with a paid Apple Developer ID / App Store notarization certificate**, macOS Gatekeeper (and iOS on iPhone/iPad) requires one quick one-time approval step on first launch.

This guide walks through installing the prebuilt **macOS release**, building locally from source, and installing the optional **iPhone & iPad companion app** using a free Apple ID.

---

## 1. macOS Release Install (Apple Silicon, macOS 14+)

### Step 1 — Download & Unzip
1. Go to the [**GitHub Releases**](https://github.com/baardove/my-echo/releases/latest) page.
2. Download the latest macOS archive (for example, `My-Echo-v1.3.0-macOS-arm64.zip`) and optionally its `.sha256` checksum file.
3. *(Optional)* Verify the download integrity in Terminal:
   ```bash
   cd ~/Downloads
   shasum -a 256 -c My-Echo-v1.3.0-macOS-arm64.zip.sha256
   ```
   You should see `My-Echo-v1.3.0-macOS-arm64.zip: OK`.
4. Double-click the `.zip` file to extract **`My Echo.app`**, then drag **`My Echo.app`** into your **`/Applications`** folder.

---

### Step 2 — Bypass macOS Gatekeeper (Choose Option A or Option B)

When downloading an un-notarized app from the internet, macOS attaches a `com.apple.quarantine` flag and shows one of these messages:
- *"My Echo cannot be opened because Apple cannot check it for malicious software."*
- *"My Echo is damaged and can't be opened. You should move it to the Trash."* *(Note: the app is not actually damaged — this is the standard macOS Sonoma/Sequoia/Tahoe message for an ad-hoc / un-notarized bundle downloaded from the web.)*

#### Option A — Recommended: Clear Quarantine in Terminal (Fastest, 1 Command)
Open **Terminal** (`⌘ + Space` → type `Terminal`) and run:

```bash
xattr -cr "/Applications/My Echo.app"
```

If macOS still asks to re-sign locally on Apple Silicon, run an ad-hoc re-sign as well:

```bash
codesign --force --deep --sign - "/Applications/My Echo.app"
```

Now double-click **`My Echo.app`** in `/Applications` — it will open normally from now on.

#### Option B — Using System Settings (No Terminal Needed)
1. Try opening **`My Echo.app`** once from `/Applications` and click **Done** or **Cancel** (do **not** click *Move to Trash*).
2. Open **System Settings** → **Privacy & Security**.
3. Scroll down to the **Security** section — you will see:
   > *"My Echo" was blocked to protect your Mac.*
4. Click **Open Anyway**, enter your Mac login password (or Touch ID), and click **Open**.

*(On macOS 15 Sequoia and newer, Control-click → Open no longer overrides Gatekeeper; use **Option A** or **System Settings → Privacy & Security → Open Anyway** above.)*

---

### Step 3 — First-Launch macOS Permissions

Depending on which features you use, macOS may prompt once for:
- **Removable Volumes:** Required to sync music/playlists/podcasts to USB FiiO/Snowsky DAPs, MP3 players, and SD cards.
- **Network Volumes:** Required if you index music stored on a mounted SMB/NFS NAS share (`/Volumes/...`).
- **Local Network:** Required if you pair the **My Echo iPhone / iPad** app over Wi-Fi (Bonjour `_myecho._tcp`).

You can review or re-enable any of these anytime under **System Settings → Privacy & Security**.

---

## 2. Alternative: Build & Sign Locally on Your Mac (Zero Gatekeeper Warnings)

If you prefer compiling straight from source on your own Mac (takes ~20–40 seconds):

### Requirements
- macOS 14 (Sonoma) or newer
- Xcode Command Line Tools (`xcode-select --install`) or Xcode

### Build Steps
```bash
git clone https://github.com/baardove/my-echo.git
cd my-echo
./build-app.sh
```

What `./build-app.sh` does:
- Compiles the Swift 6 release binary (`swift build -c release`).
- Packages `build/My Echo.app` with `Info.plist`, TCC usage descriptions, and the generated neon cassette `AppIcon.icns`.
- Signs `My Echo.app` automatically with your personal `Apple Development` certificate if present in Keychain (so macOS remembers privacy permissions across rebuilds), or ad-hoc signs locally if none is found.

Copy the freshly built app to `/Applications` or launch it directly:

```bash
cp -R "build/My Echo.app" "/Applications/My Echo.app"
open "/Applications/My Echo.app"
```

---

## 3. Installing the iPhone & iPad Companion App (Free Apple ID, No Paid Developer Account)

The Universal **My Echo iOS** app (`iOS/MyEchoiOS.xcodeproj`) can be installed on your own iPhone and iPad using a **free personal Apple ID** and **Xcode** on macOS:

1. **Connect** your iPhone or iPad to your Mac with a USB cable and tap **Trust This Computer** on the device.
2. **Enable Developer Mode** on your iPhone/iPad:
   - Go to **Settings → Privacy & Security → Developer Mode** → toggle **ON** and restart the device.
3. **Open the Xcode project** on your Mac:
   ```bash
   open iOS/MyEchoiOS.xcodeproj
   ```
4. **Sign with your Apple ID:**
   - In Xcode, go to **Xcode → Settings → Accounts** and sign in with your Apple ID (`+` → Apple ID).
   - Select the **MyEchoiOS** project in the left navigator → select the **MyEchoiOS** target → open **Signing & Capabilities**.
   - Check **Automatically manage signing**, choose your **Personal Team**, and change the **Bundle Identifier** to something unique (e.g. `com.yourname.myecho.ios`).
5. **Build & Run:**
   - Pick your connected iPhone or iPad from the device selector at the top of Xcode and press **`⌘R`** (Run).
6. **Trust the app on your iPhone/iPad (first time only):**
   - Open **Settings → General → VPN & Device Management** → tap your Apple ID under *Developer App* → tap **Trust**.
   - Launch **My Echo** on your iPhone/iPad!

> **Note on Free Apple ID Expiration:** Apple limits apps signed with a free personal Apple ID to **7 days** per signing. To refresh after 7 days, simply reconnect your device to Xcode and press **`⌘R`** (your synced music, playlists, podcasts, and settings stay intact). With a paid Apple Developer membership, builds remain valid for **1 year**.

---

## Troubleshooting

| Issue | Fix |
| --- | --- |
| **"My Echo is damaged and can't be opened"** | Run `xattr -cr "/Applications/My Echo.app"` in Terminal, then open again. |
| **macOS asks for Removable / Local Network permissions after every update** | Install locally with `./build-app.sh` using a consistent Apple Development signing certificate in Keychain, or toggle the permission off/on once in **System Settings → Privacy & Security**. |
| **iPhone/iPad cannot find Mac over Wi-Fi** | Ensure both devices are on the same Wi-Fi network (or enter your Mac's Tailscale IP in the iOS Sync tab → *Settings → Mac Connection & Pairing*) and verify **Local Network** permission is enabled for **My Echo** on both Mac and iOS. |
| **Updating to a newer macOS release** | Quit **My Echo**, replace `/Applications/My Echo.app` with the new version, and run `xattr -cr "/Applications/My Echo.app"`. Your SQLite database (`~/Library/Application Support/Echo/echo.sqlite`), playlists, stats, and device profiles are preserved automatically. |
