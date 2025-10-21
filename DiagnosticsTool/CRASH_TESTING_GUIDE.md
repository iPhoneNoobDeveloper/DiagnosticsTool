# Crash Testing Guide for Sentry Integration

## 🎯 Overview

This guide explains how to properly test crash reporting with Sentry in DiagnosticsTool. Understanding how different crash types behave is crucial for verifying your Sentry integration works correctly.

## ⚠️ Important: How Sentry Captures Crashes

### NSException Crashes (Handled Exceptions)
- **Captured**: Immediately when thrown
- **Uploaded**: Immediately to Sentry
- **Stack Trace**: Available right away in Sentry dashboard
- **App State**: May continue running (if caught) or terminate gracefully

### Native Crashes (EXC_BAD_ACCESS, SIGSEGV, etc.)
- **Captured**: At crash time, saved to disk
- **Uploaded**: **On next app launch** (not immediately!)
- **Stack Trace**: Requires dSYMs for symbolication
- **App State**: App terminates immediately

### NSAssert Crashes
- **Debug builds**: Crashes the app
- **Release builds**: Usually ignored (unless NS_BLOCK_ASSERTIONS is not defined)
- **Best for**: Development-time checks, not production crash testing

## 📋 Testing Procedure

### Step 1: Clean Slate
Before testing, ensure a clean environment:

```bash
# 1. Clean and rebuild
⌘ + Shift + K (Clean Build Folder in Xcode)
⌘ + B (Build)

# 2. Check build log for dSYM upload success
# Look for: "✅ dSYM upload complete for release 1.0-1"

# 3. Verify in Sentry
# Go to: Settings → Projects → diagnosticstool → Debug Files
# You should see uploaded dSYMs with UUID matching your build
```

### Step 2: Test NSException Crash (Immediate Upload)

This is the **best crash type to test first** because it uploads immediately.

**How to test:**
1. Launch the app
2. Click **"Crashes"** tab
3. Click **"Test NSException"** button
4. App will crash immediately

**Expected Sentry behavior:**
- Crash appears in Sentry within **30 seconds**
- Stack trace shows:
  ```
  -[CrashViewController crashNSException] at CrashViewController.m:45
  ```
- Breadcrumb visible: "User triggered NSException crash"
- Release: `1.0-1`
- Environment: `debug` (or `production` for Release builds)

**If crash doesn't appear:**
- Check Console.app for Sentry debug logs
- Verify network entitlements are present in DiagnosticsTool.entitlements
- Ensure Sentry DSN is correct in CrashReporterAdapter.m:17

### Step 3: Test Native Crash (Delayed Upload)

Native crashes require **app restart** to upload.

**How to test:**
1. Launch the app
2. Click **"Crashes"** tab
3. Click **"Test EXC_BAD_ACCESS"** button
4. App will crash immediately and terminate
5. **Relaunch the app** (this uploads the crash)
6. Wait 30 seconds for upload to complete

**Expected Sentry behavior:**
- Crash appears in Sentry **after relaunch**
- Stack trace shows (symbolicated):
  ```
  -[CrashViewController crashBadAccess] at CrashViewController.m:XX
  ```
- If you see memory addresses instead (`0x0000000104abc123`), dSYM symbolication failed

**If symbolication fails (shows addresses instead of file:line):**
- Wait 5-10 minutes (Sentry processing delay)
- Check dSYM UUID matches: `dwarfdump --uuid /path/to/DiagnosticsTool.app/Contents/MacOS/DiagnosticsTool`
- Compare with uploaded dSYMs in Sentry dashboard
- Verify release version matches (`1.0-1`)

### Step 4: Test "Test Sentry (No Crash)" Button

This button tests Sentry connectivity without crashing.

**How to test:**
1. Launch the app
2. Click **"Crashes"** tab
3. Click **"Test Sentry (No Crash)"** button
4. Check Sentry dashboard

**Expected Sentry behavior:**
- Message appears: "Sentry connectivity test - no crash"
- Shows up as **Message** (not Error) in Sentry
- Should appear within 30 seconds

## 🔍 Verifying Stack Traces

### Good Stack Trace (Symbolicated)
```
Thread 0 Crashed:
0  DiagnosticsTool  -[CrashViewController crashNSException] + 123  (CrashViewController.m:45)
1  DiagnosticsTool  -[NSButton sendAction:to:] + 456
2  AppKit           -[NSControl sendAction:to:] + 789
```

### Bad Stack Trace (Not Symbolicated)
```
Thread 0 Crashed:
0  DiagnosticsTool  0x0000000104abc123 0x104ab0000 + 49443
1  DiagnosticsTool  0x0000000104abd456 0x104ab0000 + 54358
2  AppKit           0x00007ff81234abcd 0x7ff812340000 + 43981
```

If you see memory addresses, your dSYMs aren't working correctly.

## 🛠️ Troubleshooting

### Issue: "No crashes appearing in Sentry"

**Check 1: Network access**
```bash
# Verify entitlements include network access
cat DiagnosticsTool/DiagnosticsTool.entitlements | grep network
# Should show: com.apple.security.network.client
```

**Check 2: Console logs**
```bash
# Open Console.app, filter for "Sentry"
# Look for:
# ✅ "Sentry SDK started"
# ✅ "Successfully sent event"
# ❌ "Failed to send event" (indicates network/auth issues)
```

**Check 3: Correct DSN**
```bash
# Verify DSN in CrashReporterAdapter.m matches your Sentry project
grep "options.dsn" DiagnosticsTool/Core/CrashReporterAdapter.m
```

### Issue: "Crashes appear but stack traces show memory addresses"

**Fix 1: Wait for processing**
- Sentry can take 5-10 minutes to process dSYMs
- Refresh the issue page after waiting

**Fix 2: Verify dSYM upload**
1. Go to Sentry: Settings → Projects → diagnosticstool → Debug Files
2. Check for dSYMs uploaded today
3. Verify UUID matches your build:
   ```bash
   # Get app UUID
   dwarfdump --uuid ~/Library/Developer/Xcode/DerivedData/DiagnosticsTool-*/Build/Products/Debug/DiagnosticsTool.app/Contents/MacOS/DiagnosticsTool

   # Get dSYM UUID
   dwarfdump --uuid ~/Library/Developer/Xcode/DerivedData/DiagnosticsTool-*/Build/Products/Debug/DiagnosticsTool.app.dSYM

   # These UUIDs must match!
   ```

**Fix 3: Verify release version**
```bash
# Check version in Sentry crash vs. uploaded dSYMs
# Both should show: 1.0-1
# If different, rebuild and ensure dSYM upload succeeds
```

### Issue: "Crash from CrashViewController shows wrong file in stack trace"

This was likely caused by the removed test message. After removing it:

1. Clean build folder (⌘ + Shift + K)
2. Rebuild (⌘ + B)
3. Verify dSYM upload succeeds in build log
4. Test again with NSException crash
5. Check Sentry - should now show correct file:line

### Issue: "Native crash doesn't upload even after relaunch"

**Check:**
1. Ensure you fully relaunched the app (not just resumed)
2. Check Console.app for "Sending crash report" message
3. Verify Sentry debug logs show upload attempt
4. If using Release build, check `options.debug = NO` isn't suppressing logs

## 📊 Expected Timeline

| Action | When Appears in Sentry | Notes |
|--------|------------------------|-------|
| NSException crash | 30 seconds | Immediate upload |
| Native crash (EXC_BAD_ACCESS) | After relaunch + 30s | Saved to disk first |
| Test message (no crash) | 30 seconds | Message type, not error |
| Symbolication processing | 5-10 minutes | For first upload of dSYM |

## 🎓 Best Practices

1. **Always test NSException first** - it's the fastest feedback loop
2. **Clean build before testing** - ensures fresh dSYMs are uploaded
3. **Check build log** - verify "✅ dSYM upload complete" before testing crashes
4. **Wait for symbolication** - first crash with new dSYMs takes longer
5. **Use breadcrumbs** - they're already added to all crash buttons, use them to trace user actions
6. **Remove test code** - the test message in CrashReporterAdapter has been removed to avoid confusion

## 🔗 Quick Links

- **Sentry Dashboard**: https://sentry.io/organizations/individual-f56/projects/diagnosticstool/
- **Debug Files**: https://sentry.io/organizations/individual-f56/projects/diagnosticstool/settings/debug-symbols/
- **Releases**: https://sentry.io/organizations/individual-f56/projects/diagnosticstool/releases/

## ✅ Verification Checklist

Before reporting issues, verify:

- [ ] Build succeeds with "✅ dSYM upload complete for release 1.0-1"
- [ ] Network entitlements present in DiagnosticsTool.entitlements
- [ ] Sentry DSN is correct in CrashReporterAdapter.m
- [ ] Test message removed from CrashReporterAdapter.m (line 34 should be comment)
- [ ] Tested NSException crash (appears immediately)
- [ ] Tested native crash (relaunched app, appears after relaunch)
- [ ] Stack traces show file:line (not memory addresses)
- [ ] Breadcrumbs visible in crash reports
- [ ] Release version is 1.0-1 in Sentry

## 🆘 Still Having Issues?

If crashes still show wrong stack traces after following this guide:

1. Share the full stack trace from Sentry
2. Run `dwarfdump --uuid` on both app binary and dSYM (commands above)
3. Check Sentry Debug Files page - share screenshot
4. Share build log showing dSYM upload section
5. Share Console.app logs filtered for "Sentry"
