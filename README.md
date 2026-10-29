# PALS — Friendship-first social network

A Flutter Android starter app for platonic friendships, interest-based communities, friendly posts, and safe social interaction. No dating, romance, swipe matching, or romantic recommendations.

## Features in this local demo
- Feed with sample posts and story previews
- Create a post locally and like/unlike posts
- Discover sample profiles and toggle friend-request state
- Join or leave interest communities
- Demo conversations and local message composer
- Edit display name and bio
- Privacy/safety screens with report/block flow previews
- Central app branding configuration

## Scope and production readiness
This is a runnable local demo/starter, not a deployed production social network. Sample profiles, posts, groups and chats use local demo data. Messages are not sent to other devices, and friend requests/moderation are not server-enforced. A production release needs authentication, a backend/database, real-time messaging, media storage, server-side authorization, moderation tools, rate limits, privacy policy and account deletion.

## Rename the app
Edit `lib/config/app_config.dart` and change `AppConfig.appName`. The Android launcher label is set by the GitHub Actions workflow from that setting.

## Run locally
Install Flutter stable and Android Studio / Android SDK, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Build locally

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## GitHub Actions
`.github/workflows/android-apk.yml` installs Flutter, resolves dependencies, analyzes and tests the project, builds a release APK, and uploads it as an artifact. Open the **Actions** tab and run **Build Android APK** after the workflow is pushed.

## Suggested production next step
Add a backend such as Supabase or Firebase. Never put privileged service keys in the Android app. Add database security rules, server-enforced blocking/reporting, moderation, abuse controls and data deletion support before public release.
