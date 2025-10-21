# DiagnosticsTool

A macOS diagnostic and crash reporting application built with Objective-C and integrated with Sentry for comprehensive crash monitoring.

## 🎯 Features

### 📊 Three Main Views

1. **Crashes** - Test crash reporting with multiple crash types (NSException, EXC_BAD_ACCESS, NSAssert)
2. **Logging** - Real-time network monitoring with live status updates
3. **Diagnostics** - Collect and export system logs with automatic PII redaction

### 🔧 Technical Stack

- **Language:** Objective-C
- **Framework:** macOS AppKit
- **Crash Reporting:** Sentry SDK with MetricKit
- **Dependencies:** CocoaPods
- **Logging:** Unified Logging (OSLog)
- **Network:** Network framework (NWPathMonitor)

## 🚀 Quick Start

### Prerequisites

```bash
# Install CocoaPods
sudo gem install cocoapods

# Install Sentry CLI (for dSYM uploads)
brew install getsentry/tools/sentry-cli
```

### Setup

```bash
# 1. Clone and navigate to project
cd /path/to/DiagnosticsTool

# 2. Install dependencies
pod install

# 3. Open workspace (not .xcodeproj!)
open DiagnosticsTool.xcworkspace

# 4. Build and run
⌘ + B (Build)
⌘ + R (Run)
```

## 📱 Usage

### Crashes Tab
- **Test Sentry (No Crash)** - Verify Sentry connectivity
- **Throw NSException** - Test exception crash (uploads immediately)
- **EXC_BAD_ACCESS** - Test native crash (uploads after relaunch)
- **Abort via NSAssert** - Test assertion crash (Debug builds only)

### Logging Tab
- View live network status
- Monitor connectivity changes
- Track network conditions (expensive, constrained)

### Diagnostics Tab
- **Collect logs** - Export unified logs to ZIP
- **Collect logs + sysdiagnose** - Full diagnostic bundle
- Automatic PII redaction (emails, IPs, credit cards)
- Saves to Desktop with timestamp

## 🔑 Configuration

### Sentry Setup

Update your Sentry credentials in:
```objc
// DiagnosticsTool/Core/CrashReporterAdapter.m
options.dsn = @"YOUR_SENTRY_DSN";
```

## 📖 Documentation

- **PROJECT_OVERVIEW.md** - Comprehensive architecture and file structure
- **TESTING_CRASH_BUTTONS.md** - Step-by-step crash testing guide
- **CRASH_TESTING_GUIDE.md** - Sentry integration and verification
- **DSYM_UPLOAD_SETUP.md** - dSYM configuration guide
- **DSYM_TROUBLESHOOTING.md** - Debugging dSYM upload issues
- **PROJECT_EMAIL.md** - Executive summary for team presentations

## 🛠️ Build Configuration

### Entitlements

Required for Sentry network access:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

## 🧪 Testing

### Quick Test

1. Build the project (⌘ + B)
2. Run the app (⌘ + R)
3. Go to **Crashes** tab
4. Click **"Throw NSException"**
5. Check [Sentry Dashboard](https://sentry.io) in 30 seconds
6. Verify stack trace shows `CrashViewController.m:65`


## 📂 Project Structure

```
DiagnosticsTool/
├── Core/
│   ├── CrashReporterAdapter.m    # Sentry SDK initialization
│   ├── MetricsListener.m          # MetricKit integration
│   ├── DiagnosticBundleBuilder.m  # Log collection
│   └── Redactor.m                 # PII redaction
├── UI/
│   ├── AppCoordinator.m           # Navigation coordinator
│   ├── CrashViewController.m      # Crash testing UI
│   ├── LogsViewController.m       # Network monitoring
│   └── DiagnosticsViewController.m # Log collection UI

```

## 🐛 Troubleshooting

### Crashes not appearing in Sentry
- Check network entitlements in `.entitlements` file
- Verify DSN is correct in `CrashReporterAdapter.m`
- For native crashes (EXC_BAD_ACCESS), relaunch the app

## 🔗 Links

- **Sentry Dashboard:** [View Issues](https://sentry.io)
- **Sentry Docs:** https://docs.sentry.io/platforms/apple/

## 📝 License

This is a diagnostic tool for internal development and testing purposes.

---

**Quick Commands:**

```bash
# Build
⌘ + B

# Clean build
⌘ + Shift + K

# Run
⌘ + R

# Install dependencies
pod install

**Need Help?** Check the documentation files or run the verification script for diagnostics.
