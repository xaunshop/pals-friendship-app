# LAMA — Friendship-first social network

LAMA is a Flutter Android social app focused on **platonic friendships**, shared interests and safe community participation. It has no dating, romantic matching or swipe-to-date features.

## Features

- Email/password sign-up and sign-in through Supabase Auth
- Google sign-in/sign-up through Supabase OAuth (requires provider setup below)
- Required name, unique reserved username, phone number, date of birth and consent during account creation
- Minimum age of 12 enforced in the app and by a database function/constraint
- Phone number and date of birth stored in a separate table with row-level security allowing only the account owner to read them
- Shared feed with posts, likes and comments
- Discover members, send friend requests, join interest communities and chat with accepted friends
- A “Ghost” post action that submits a report for moderation
- GitHub Actions release APK workflow

## Backend setup

### 1. Create a Supabase project

Create a project at https://supabase.com/dashboard. Copy the Project URL and the public anon/publishable key from the project settings. Never use the service-role/secret key in this Android app or GitHub Actions.

### 2. Create the database

1. Open Supabase **SQL Editor**.
2. Run the complete `supabase/schema.sql` file first if this is a fresh project.
3. Then run `supabase/migrations/20261029_lama_private_profile_and_username.sql`. This adds the private details table, secure username availability/reservation and profile-completion functions.
4. Keep row-level security enabled. Do not expose the private profile table through custom APIs or views.

If you already ran the original schema, run only the migration file in step 3. Do not skip this migration: the updated app requires the new private table and RPC functions.

### 3. Configure Google OAuth

Google sign-in requires your own OAuth credentials; the app cannot activate the provider just from code.

1. In Supabase, open **Authentication → Sign In / Providers → Google** and enable Google.
2. Create a Google OAuth client in Google Cloud Console. Add the Supabase callback URL shown in the Supabase Google provider settings as an **Authorized redirect URI**. It normally looks like `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`.
3. Copy the Google Client ID and Client Secret into the Supabase Google provider settings and save.
4. In Supabase **Authentication → URL Configuration**, add this exact redirect URL to the allowed redirect URLs: `io.supabase.flutter://login-callback/`.
5. Rebuild the APK after the workflow change has completed.

Never put the Google Client Secret into Flutter code or GitHub Actions.

### 4. Add GitHub Actions repository secrets

Open the GitHub repository → **Settings → Secrets and variables → Actions → New repository secret** and create:

- `SUPABASE_URL` — your Supabase Project URL
- `SUPABASE_ANON_KEY` — your public anon/publishable key

The workflow injects these values at build time. Do not commit credentials into Dart files. The publishable/anon key is intended for client apps; database security depends on correctly configured row-level security policies.

### 5. Build the Android APK

1. Open **Actions → Build Android APK**.
2. Wait for the workflow to finish successfully.
3. Download the `pals-android-release-apk` artifact and extract the APK from the ZIP.

## Privacy and safety notes

Phone number and date of birth are not stored in the public `profiles` table. They are stored in `private_profile_details`, protected by RLS policies tied to `auth.uid()`. The app only fetches these fields for the signed-in owner.

The 12+ age rule is enforced in the client and database onboarding function. A production service should still review applicable child privacy, parental-consent, data-retention and safeguarding requirements for every country in which it operates. The consent checkbox is an acknowledgement UI, not a substitute for a published Terms of Service and Privacy Policy.

The Ghost action submits a report record; it does not automatically remove content or provide a moderator dashboard. Configure a real moderation process before public launch.

## Local development

Install Flutter stable and Android SDK, then run:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

## Tech stack

- Flutter / Dart
- Supabase Auth and OAuth
- Supabase PostgreSQL + Row Level Security
- Supabase Realtime for chat messages
- GitHub Actions for Android release builds
