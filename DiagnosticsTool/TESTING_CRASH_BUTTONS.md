# Testing Crash Buttons - Step-by-Step Guide

## 🎯 Overview

This guide shows you how to test each crash button in CrashViewController, including how to set breakpoints, what to expect, and how to verify the crash appears in Sentry.

## ⚙️ Before You Start

1. **Build the app** with the latest fixes:
   ```
   ⌘ + Shift + K (Clean Build Folder)
   ⌘ + B (Build)
   ```

2. **Check build log** for dSYM upload:
   - Look for: `✅ dSYM upload complete for release 1.0-1`
   - If not present, check DSYM_TROUBLESHOOTING.md

3. **Launch the app** in Xcode (⌘ + R)

4. **Navigate to Crashes tab** in the app

## 🧪 Test 1: "Test Sentry (No Crash)" Button

**Purpose**: Verify Sentry connectivity without crashing the app.

### Steps:
1. Click **"Test Sentry (No Crash)"** button
2. You should see an alert dialog immediately
3. Click "OK" to dismiss

### Setting Breakpoint:
```
File: CrashViewController.m
Line: 50 (inside testSentry method)
```

**In Xcode:**
- Open CrashViewController.m
- Click on line number 50 (the `os_log_with_type` line)
- Blue breakpoint marker appears
- Click the button in your app
- Xcode pauses at breakpoint
- Press ⌘ + Y to continue (or F6 to step through)

### Expected Behavior:
- ✅ Button click works
- ✅ Breakpoint hits (if set)
- ✅ Alert dialog appears
- ✅ App does NOT crash
- ✅ Message appears in Sentry within 30 seconds

### Verify in Sentry:
1. Go to: https://sentry.io/organizations/individual-f56/issues/
2. Look for: "Test message from CrashViewController - Sentry is working!"
3. Level: Info (not Error)
4. Should appear within 30 seconds

### Troubleshooting:
- **Breakpoint doesn't hit**: Make sure you rebuilt after fixing AppCoordinator.m
- **No message in Sentry**: Check network entitlements (see CRASH_TESTING_GUIDE.md)
- **App crashes**: This shouldn't happen anymore after removing `[SentrySDK crash]`

---

## 🧪 Test 2: "Throw NSException" Button

**Purpose**: Test exception-based crash (immediate upload to Sentry).

### Steps:
1. Click **"Throw NSException"** button
2. App will crash **immediately**
3. Xcode shows exception in console
4. App terminates

### Setting Breakpoint:
```
File: CrashViewController.m
Line: 63 (inside crashNSException method)
```

**To test with breakpoint:**
- Set breakpoint on line 63
- Click "Throw NSException" button
- Xcode pauses at breakpoint
- Press ⌘ + Y to continue
- App crashes on line 65 (`@throw`)

### Expected Console Output (Xcode):
```
About to throw NSException intentionally
*** Terminating app due to uncaught exception 'DemoException'
*** First throw call stack:
(0x... 1x... 2x...)
```

### Expected Behavior:
- ✅ Breakpoint hits (if set)
- ✅ App crashes immediately
- ✅ Xcode shows exception in console
- ✅ Crash appears in Sentry within 30 seconds (NO RELAUNCH NEEDED)

### Verify in Sentry:
1. Go to: https://sentry.io/organizations/individual-f56/issues/
2. Look for: "DemoException" or "Intentional NSException"
3. Click on the issue
4. Check stack trace should show:
   ```
   -[CrashViewController crashNSException] at CrashViewController.m:65
   ```
5. Check breadcrumbs: Should see "User triggered NSException crash"

### What Makes This Special:
- **Uploads immediately** - doesn't need app relaunch
- **Best for testing** - fast feedback loop
- **Symbolication works** - if dSYMs uploaded correctly

---

## 🧪 Test 3: "EXC_BAD_ACCESS" Button

**Purpose**: Test native crash (requires relaunch to upload).

### ⚠️ IMPORTANT: This crash requires TWO launches to see in Sentry!

### Steps:
1. Click **"EXC_BAD_ACCESS"** button
2. App crashes **immediately** (dereferencing null pointer)
3. Xcode shows: `Thread 1: EXC_BAD_ACCESS`
4. Crash saved to disk
5. **Relaunch the app** (⌘ + R)
6. During relaunch, Sentry uploads the saved crash
7. Wait 30 seconds after relaunch
8. Check Sentry

### Setting Breakpoint:
```
File: CrashViewController.m
Line: 70 (inside crashBadAccess method)
```

**To test with breakpoint:**
- Set breakpoint on line 70
- Click "EXC_BAD_ACCESS" button
- Xcode pauses at breakpoint
- **Option 1**: Step through with F6 (app crashes on line 72)
- **Option 2**: Press ⌘ + Y to continue (app crashes immediately)

### Expected Console Output (Xcode):
```
About to trigger EXC_BAD_ACCESS intentionally
Thread 1: EXC_BAD_ACCESS (code=2, address=0x1)
```

### Expected Behavior:
- ✅ Breakpoint hits (if set)
- ✅ App crashes immediately on line 72
- ✅ Xcode shows `EXC_BAD_ACCESS`
- ✅ **Crash does NOT appear in Sentry yet**
- ✅ After relaunch: Crash uploads automatically
- ✅ Appears in Sentry 30 seconds after relaunch

### Verify in Sentry (After Relaunch):
1. **Relaunch the app first!** (⌘ + R)
2. Wait 30 seconds
3. Go to: https://sentry.io/organizations/individual-f56/issues/
4. Look for: "EXC_BAD_ACCESS" or "SIGSEGV"
5. Stack trace should show:
   ```
   -[CrashViewController crashBadAccess] at CrashViewController.m:72
   ```
6. Breadcrumbs: "User triggered EXC_BAD_ACCESS crash"

### Why Does This Need Relaunch?

Native crashes (EXC_BAD_ACCESS, SIGSEGV, SIGABRT) terminate the app **immediately** before Sentry can upload over the network. Sentry saves the crash to disk, then uploads it on the next app launch.

**Timeline:**
```
Launch 1: Click button → Crash → Save to disk → App terminates
Launch 2: App starts → Sentry detects saved crash → Upload → Continue running
Sentry:   30 seconds after Launch 2 → Crash appears in dashboard
```

### Troubleshooting:
- **Crash not in Sentry after relaunch**:
  - Make sure you relaunched (not just resumed)
  - Check Console.app for Sentry upload logs
  - Wait up to 60 seconds

- **Stack trace shows addresses not file:line**:
  - Check dSYM upload succeeded in build log
  - Wait 5-10 minutes for Sentry to process dSYMs
  - See CRASH_TESTING_GUIDE.md section on symbolication

---

## 🧪 Test 4: "Abort via NSAssert" Button

**Purpose**: Test assertion-based crash (Debug builds only).

### ⚠️ IMPORTANT: NSAssert only crashes in Debug builds!

### Steps:
1. Verify you're in **Debug** configuration:
   - Product → Scheme → Edit Scheme → Run → Build Configuration = Debug
2. Click **"Abort via NSAssert"** button
3. App crashes with assertion failure
4. **Relaunch the app** (⌘ + R)
5. Wait 30 seconds
6. Check Sentry

### Setting Breakpoint:
```
File: CrashViewController.m
Line: 77 (inside crashAssert method)
```

### Expected Console Output (Xcode):
```
About to trigger NSAssert crash intentionally
Assertion failure in -[CrashViewController crashAssert]
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException'
*** Assertion failure in -[CrashViewController crashAssert], CrashViewController.m:78
```

### Expected Behavior:
- ✅ Breakpoint hits (if set)
- ✅ App crashes on line 78 (NSAssert)
- ✅ Xcode shows assertion failure
- ✅ **Crash saved to disk**
- ✅ After relaunch: Uploads to Sentry
- ✅ Appears in Sentry 30 seconds after relaunch

### Release Build Behavior:
If you switch to Release configuration:
- Product → Scheme → Edit Scheme → Run → Build Configuration = Release
- NSAssert statements are **disabled** (compiled out)
- Clicking the button does **nothing** (no crash)
- This is normal behavior for assertions

### Verify in Sentry (After Relaunch):
1. **Relaunch the app first!** (⌘ + R)
2. Wait 30 seconds
3. Go to: https://sentry.io/organizations/individual-f56/issues/
4. Look for: "NSInternalInconsistencyException" or "Intentional assert fail"
5. Stack trace should show:
   ```
   -[CrashViewController crashAssert] at CrashViewController.m:78
   ```
6. Breadcrumbs: "User triggered NSAssert crash"

---

## 🎓 Summary Table

| Button | Crashes Immediately? | Needs Relaunch? | Best For | Sentry Upload |
|--------|---------------------|-----------------|----------|---------------|
| **Test Sentry (No Crash)** | ❌ No | ❌ No | Testing connectivity | Immediate |
| **Throw NSException** | ✅ Yes | ❌ No | Quick testing | Immediate |
| **EXC_BAD_ACCESS** | ✅ Yes | ✅ **Yes** | Real crash simulation | After relaunch |
| **Abort via NSAssert** | ✅ Yes (Debug only) | ✅ **Yes** | Debug assertions | After relaunch |

## 🔍 Debugging Tips

### How to Set Breakpoints in Xcode:
1. Open CrashViewController.m
2. Click on the line number where you want to pause
3. Blue marker appears
4. Run app and trigger the action
5. Xcode pauses at that line
6. **F6** = Step over (next line)
7. **F7** = Step into (go inside method)
8. **⌘ + Y** = Continue execution

### How to View Console Output:
1. Run app in Xcode (⌘ + R)
2. Bottom panel shows debug console
3. Look for `os_log` messages
4. Shows crash information when app terminates

### How to Check Which Breakpoints Are Active:
1. **⌘ + 8** = Show Breakpoint Navigator
2. Shows all breakpoints in your project
3. Toggle on/off by clicking checkbox
4. Delete by right-click → Delete

### How to Continue After Crash:
1. After crash, Xcode shows the crash point
2. Click **Stop** button (⌘ + .)
3. Click **Run** button again (⌘ + R) to relaunch

## 🧪 Recommended Testing Order

### First Time Testing:
1. **"Test Sentry (No Crash)"** - Verify Sentry works without crashing
2. **"Throw NSException"** - Test immediate crash upload (no relaunch)
3. **"EXC_BAD_ACCESS"** - Test native crash (requires relaunch)
4. **"Abort via NSAssert"** - Test assertion crash (requires relaunch)

### Daily Development Testing:
- Use **"Throw NSException"** for quick Sentry testing (fastest feedback)
- Use **"EXC_BAD_ACCESS"** for realistic production-like crashes

### Before Team Demo:
1. Clean build (⌘ + Shift + K)
2. Rebuild (⌘ + B)
3. Verify dSYM upload in build log
4. Test "Throw NSException"
5. Wait for it to appear in Sentry (30 seconds)
6. Show symbolicated stack trace to team

## ✅ Verification Checklist

Before testing crashes, ensure:

- [ ] **Built successfully** with no errors
- [ ] **dSYM upload succeeded** (check build log)
- [ ] **AppCoordinator fixed** (view controllers retained)
- [ ] **`[SentrySDK crash]` removed** from testSentry method
- [ ] **Network entitlements** present in .entitlements file
- [ ] **Sentry DSN correct** in CrashReporterAdapter.m
- [ ] **Running in Debug mode** (for NSAssert to work)

## 🆘 Common Issues

### "Breakpoint doesn't hit when I click button"
- **Fix**: Rebuild the project (⌘ + B)
- **Fix**: Make sure AppCoordinator.m has the fixes (strong references)
- **Check**: Blue breakpoint marker should be solid (not gray)

### "App doesn't crash when I click button"
- **Fix**: Make sure you're clicking the correct button
- **Check**: Look at Xcode console for any output
- **Check**: For NSAssert, verify you're in Debug configuration

### "Crash not appearing in Sentry"
- **For NSException**: Should appear immediately - check network entitlements
- **For native crashes**: Did you relaunch the app?
- **For all crashes**: Wait at least 60 seconds, check CRASH_TESTING_GUIDE.md

### "Stack trace shows memory addresses not file names"
- **Fix**: Wait 5-10 minutes for Sentry to process dSYMs
- **Fix**: Run `bash scripts/verify-dsyms.sh` to check UUIDs match
- **Fix**: Rebuild to re-upload dSYMs

## 📚 Related Documentation

- **CRASH_TESTING_GUIDE.md** - Comprehensive crash testing and Sentry verification
- **DSYM_TROUBLESHOOTING.md** - dSYM upload issues and symbolication
- **PROJECT_OVERVIEW.md** - Full project architecture and file structure

## 🔗 Quick Links

- **Sentry Issues**: https://sentry.io/organizations/individual-f56/issues/
- **Sentry Debug Files**: https://sentry.io/organizations/individual-f56/projects/diagnosticstool/settings/debug-symbols/

---

**Pro Tip**: Start with "Test Sentry (No Crash)" to verify connectivity, then move to "Throw NSException" for the fastest crash testing feedback loop!
