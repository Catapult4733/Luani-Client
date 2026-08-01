---
name: luani-full-pipeline
description: Complete build, test, auto-diagnosis, and deployment workflow for Luani across Linux client, Android APK, Raspberry Pi 5 backend, and Ubuntu Laptop server daemon over Tailscale SSH.
---

# Luani Master Architecture & Auto-Diagnostic Skill

When asked to build, update, or ship features for Luani, execute the full pipeline below.

---

## Phase 1: Build & Version Configuration
1. **Target Version Check**:
   - Read expected `version/code` and `version/name` from `client_and_studio/export_presets.cfg`.
2. **Local Code Audit**:
   - `node --check web_backend/src/index.js`
   - `node --check web_backend/public/app.js`
   - `godot --headless --path client_and_studio --script scripts/test_phase2.gd`

---

## Phase 2: Binary Export
1. **Linux Executable**:
   - `godot --headless --path client_and_studio --export-release "Linux x86_64" ../bin/LuaniClient.x86_64`
   - `chmod +x bin/LuaniClient.x86_64`
2. **Android APK**:
   - `export JAVA_HOME=/home/username/.android/tools/jdk-17.0.10+7 && export ANDROID_HOME=/home/username/Android/Sdk && cd client_and_studio/android/build && ./gradlew assembleRelease && cd ../../.. && godot --headless --path client_and_studio --export-release "Android" ../bin/LuaniClient.apk`
3. **Sync Web Downloads**:
   - `cp bin/LuaniClient.apk web_backend/public/downloads/LuaniClient.apk`
   - `cp bin/LuaniClient.x86_64 web_backend/public/downloads/LuaniClient.x86_64`

---

## Phase 3: Automated Diagnostic & Screenshot Verification

### A. Android APK Auto-Diagnosis
1. **Install & Launch**:
   - `adb install -r --user 0 bin/LuaniClient.apk`
   - `adb shell am start --user 0 -n com.luani.client/com.godot.game.GodotApp`
2. **Version Log Verification**:
   - Read initial startup logs: `adb logcat -d -s godot:I godot:E GODOT_APP:I | grep -i "version"`
   - **Cache Check**: Compare printed log version string against `export_presets.cfg`. If the versions **do not match**, flag as a **Cached/Stale APK Build**, purge local app storage (`adb shell pm clear com.luani.client`), reinstall, and re-check.
3. **10-Second Visual Inspection**:
   - `sleep 10`
   - Capture device screen: `adb exec-out screencap -p > android_screen.png`
4. **Visual & Error Auto-Fix Loop**:
   - Inspect `android_screen.png` and `adb logcat -d`.
   - If a gray screen, black screen, or error label is detected:
     a. Extract exact error from logcat (`CRASH`, `ERROR`, `gl_compatibility`, or `add_child`).
     b. Apply code or scene fixes in `client_and_studio/`.
     c. Re-export APK, reinstall, launch, and verify again.

### B. Linux Binary Auto-Diagnosis
1. **Launch Test Instance**:
   - Run `bin/LuaniClient.x86_64 "luani://join?server=127.0.0.1:7777&username=TestDiagnostic" &`
2. **Version Log Verification**:
   - Check stdout for version string match. If mismatched, clean `client_and_studio/.godot/` cache and recompile.
3. **10-Second Visual Inspection**:
   - `sleep 10`
   - Take desktop screenshot / window dump to verify GUI render pipeline.
4. **Cleanup**:
   - Close diagnostic client process.

---

## Phase 4: Remote Server Deployment (Tailscale SSH)
1. **Git Commit & Push**:
   - `git add .`
   - `git commit -m "feat: automated build update with verified diagnostics"`
   - `git push origin main`
2. **Deploy to Ubuntu Laptop Server Daemon**:
   - `ssh server123421532q "cd ~/Luani-Client && git pull origin main && sudo systemctl restart luani-daemon.service"`
3. **Deploy to Raspberry Pi 5 Web Host**:
   - `ssh raspberrypi "cd ~/Luani-Client && git pull origin main && sudo systemctl restart luani-backend.service"`
4. **Final Status**:
   - Confirm services active and notify user: *"Build verified, diagnostic passed, and servers deployed!"*
