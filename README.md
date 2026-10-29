# PALS — Friendship-first social network

PALS is a Flutter Android social app focused on **platonic friendships**, shared interests and safe community participation. It has no dating, romantic matching or swipe-to-date features.

## Current app features

- Email/password sign-up and sign-in through Supabase Auth
- Profiles with display name, username, bio and private-profile setting
- Shared feed with posts, likes and comments
- Discover authenticated members and send friend requests
- Interest-based communities and membership
- Direct chat UI with Supabase Realtime message updates
- Report content, block records and basic safety guidance
- Polished Material 3 UI with responsive layouts and pull-to-refresh
- Central app name and backend build configuration
- GitHub Actions release APK workflow

## Important: connect the backend before public use

The Android project can compile without credentials, but it will show a setup screen until a Supabase project is configured. Real online features require a Supabase project.

### 1. Create a Supabase project

1. Create a project at https://supabase.com/dashboard.
2. In **Project Settings → API**, copy the Project URL and the public anon/publishable key.
3. Never use the service-role/secret key in this Android app or GitHub Actions build.

### 2. Create the database

1. Open the Supabase project **SQL Editor**.
2. Open `supabase/schema.sql` in this repository.
3. Paste the complete SQL into the editor and run it.
4. In Supabase **Authentication → URL Configuration**, set the site URL to a URL you control. For email confirmation, configure your intended email flow before releasing.

The schema creates the profiles, posts, likes, comments, friendships, communities, memberships, conversations, messages, blocks and reports tables with row-level security policies. It also creates starter communities and a secure RPC for creating direct chats between accepted friends.

Review the schema and policies against your moderation, privacy and legal requirements before production deployment.

### 3. Add GitHub Actions repository secrets

Open your GitHub repository → **Settings → Secrets and variables → Actions → New repository secret** and create:

- `SUPABASE_URL` — your Supabase Project URL
- `SUPABASE_ANON_KEY` — your public anon/publishable key

The workflow injects these values at build time. Do not commit credentials into Dart files. These are public client credentials, so database security depends on correctly configured row-level security policies.

### 4. Build the Android APK

1. Open **Actions → Build Android APK**.
2. Run the workflow, or push a commit to `main`.
3. Wait for the build to succeed.
4. Download the `pals-android-release-apk` artifact and extract the APK from the ZIP.

### 5. Run locally

Install Flutter stable and Android SDK, then run:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Change `AppConfig.appName` in `lib/config/app_config.dart` to rename the app.

## Production readiness checklist

Before inviting the public, test account confirmation/password reset, RLS as multiple test accounts, friend request acceptance/decline, block enforcement, reporting moderation, chat authorization, privacy and account deletion. Configure storage buckets and storage policies before adding avatar/image uploads. Add a moderator/admin workflow, rate limits, abuse monitoring and a privacy policy. The current schema includes report records but does not provide a moderation dashboard or automated human review.

## Tech stack

- Flutter / Dart
- Supabase Auth
- Supabase PostgreSQL + Row Level Security
- Supabase Realtime for chat messages
- GitHub Actions for Android release builds
