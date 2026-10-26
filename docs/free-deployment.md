# Free demo deployment: Render + Vercel + Supabase + Android

This guide deploys the existing application with one Render web service running both API and worker, Supabase for durable state, Vercel for the compiled Flutter website, and a signed APK using the same API. Inngest is not required for this topology. This is a sleeping portfolio/demo deployment, not always-on production infrastructure.

Render Free sleeps after 15 minutes without inbound traffic and loses local files on restart. The next visit can take about a minute to wake it. AI processing, reminders, calendar actions and retention cleanup stop while asleep. A killed job resumes after its database lease expires (default up to 15 minutes), subject to retry limits and provider availability. Keep the app open while testing processing. Do not use synthetic keep-alive traffic as an availability guarantee. Two Python processes share a small free instance; memory/OOM and model latency must be measured on Render. Optional local speech/OCR engines remain disabled.

Official references: [Render free limits](https://render.com/docs/free), [Render web services](https://render.com/docs/web-services), [Supabase connections](https://supabase.com/docs/guides/database/connecting-to-postgres), [Vercel CLI](https://vercel.com/docs/cli/deploy), [Flutter Android deployment](https://docs.flutter.dev/deployment/android).

## 1. Prepare accounts and repository

Use GitHub, Render, Vercel, the existing Supabase development project, and your Gemini API account. Install Flutter (Android toolchain included), Git, Node.js/npm and a JDK with keytool. From the repository root:

```powershell
Set-Location D:\shreya\projects\lifescript
flutter doctor -v
git status --short
git check-ignore backend/.env frontend/android/key.properties frontend/android/app/lifescript-release.jks
```

Review all files before making your own initial commit and pushing to your GitHub repository. Do not upload backend/venv, .env files, .local data, keystores, journals or database dumps. The supplied .gitignore and backend/.dockerignore exclude local credentials/data. This guide does not itself commit, push or create external services.

## 2. Confirm Supabase, without rerunning migrations blindly

The selected project was audited at schema 12. If using that project, do not replay migrations over it. For another project, first reconcile its schema and apply ordered 0001 through 0012 only as appropriate; see implementation-runbook.md. Never execute legacy supabase_migrations.sql as another migration system.

In Supabase Project Settings / API collect the project URL, public publishable key (frontend), and secret/service-role key (backend only). In Connect choose **Session pooler**, copy the exact host/username, port **5432**, and use the database password. URL-encode password special characters. Add `sslmode=require` to the connection URI (use `&` if it already has query parameters). This encrypts traffic; for certificate identity verification use the project's trusted CA with `sslmode=verify-full` and a mounted sslrootcert. Do not select the transaction pooler on 6543 for the current private checkpointer.

This connection becomes CHECKPOINT_DATABASE_URL, not a Flutter setting. Checkpoints use lifescript_private created by migration 0006; keep that schema out of Supabase's exposed API schemas. Do not create checkpoint tables in public. Keep uploads in the private journal-assets bucket. Keep Supabase Free separate from Render's temporary free PostgreSQL offering.

## 3. Deploy the complete backend on Render

In Render select **New > Blueprint**, connect your GitHub repository and use root `render.yaml`. Confirm the plan is **Free**, then fill the prompted variables:

| Variable | Value |
| --- | --- |
| SUPABASE_URL | Your existing Supabase project URL |
| SUPABASE_SECRET_KEY | Backend secret/service-role key |
| GEMINI_API_KEY | Your private model API key |
| GENERATION_MODEL | An available generation model; current local config is gemini-2.5-flash |
| EMBEDDING_MODEL | Same model used to index your data; current config is gemini-embedding-2, requiring 768 output dimensions |
| CHECKPOINT_DATABASE_URL | Private Session pooler PostgreSQL URI from step 2 |
| CORS_ORIGINS | Initially `["http://localhost:8080","http://127.0.0.1:8080"]`; replace/add the final Vercel origin in step 5 |

Paste secrets only into Render's environment form. Do not put quote marks around a whole URI or secret. CORS_ORIGINS must be a valid JSON array, with origins containing no trailing slash or path. The Blueprint sets Gemini, disables optional speech/OCR and traces, and polls every ten seconds. Render supplies PORT.

If creating manually instead: New Web Service, Docker runtime, repository root directory blank, Dockerfile `./backend/Dockerfile`, Docker context `./backend`, Docker command `python -m app.hosted`, Free instance, health path `/health/ready`. Do not deploy the Dockerfile default command alone: that runs only the API. Do not create a second paid worker for this free topology.

After deployment, copy the actual service URL, for example https://lifescript-api-xxxx.onrender.com. Check:

```powershell
$apiOrigin = 'https://YOUR-SERVICE.onrender.com'
Invoke-RestMethod "$apiOrigin/health/live"
Invoke-RestMethod "$apiOrigin/health/ready"
```

Both must return success. Inspect Render logs for worker_ready as well. The supervisor exits if either API or worker exits, allowing Render to restart the entire service. Readiness confirms schema/API access, not model quota or successful generation. A checkpoint connection failure prevents worker startup and fails this deployment rather than silently using ephemeral SQLite. No schema changes are applied at container startup.

## 4. Build and publish Flutter web on Vercel

Build locally: Vercel does not need Flutter installed. Replace ALL placeholders. Use the public Supabase key, never the backend secret:

```powershell
Set-Location D:\shreya\projects\lifescript\frontend
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build web --release `
  --dart-define=API_URL=https://YOUR-SERVICE.onrender.com `
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLIC-KEY
npx vercel login
npx vercel deploy ./build/web --prod
```

At the first CLI setup choose your personal account, create a project such as lifescript-web, use framework **Other**, and keep build command empty with the uploaded folder as the output. If prompted to modify build settings, ensure no npm/framework build is configured. This uploads only compiled public files, not the backend or .env. Do not pass `--prebuilt`: that flag expects Vercel Build Output API files, not a Flutter build/web folder. Reuse the same linked project for future uploads; rebuilding Flutter is required when Dart defines change. The app uses hash routes, so no SPA rewrite is needed.

Copy the stable production URL from the Vercel dashboard (not a changing preview URL). You can open the deployed site after step 5. The web OAuth redirect defaults to the site's actual origin; do not compile a localhost AUTH_REDIRECT_URL into it.

## 5. Connect CORS and sign-in redirects

In Render Environment change CORS_ORIGINS to `["https://YOUR-PROJECT.vercel.app"]` (include your exact custom domain too if used), save and redeploy. In Supabase Authentication > URL Configuration:

- Site URL: `https://YOUR-PROJECT.vercel.app/`
- Redirect URLs: `https://YOUR-PROJECT.vercel.app/` and `com.lifescript.frontend://login-callback/`
- Retain localhost redirects only if you still use local development.

In the Google OAuth Web client used by Supabase, the authorized redirect URI is `https://YOUR-PROJECT.supabase.co/auth/v1/callback`, not the Render URL. Configure the Google provider client ID/secret inside Supabase, and add test users if the Google consent screen is in testing mode. See [Supabase redirect configuration](https://supabase.com/docs/guides/auth/redirect-urls).

Test sign-in, sign-out, refresh and reauthentication on the final origin. Never use a wildcard CORS origin to work around a wrong hostname.

## 6. Create a private Android release signing key

From frontend (run once; preserve the keystore for all future updates):

```powershell
keytool -genkeypair -v -keystore android/app/lifescript-release.jks -alias lifescript -keyalg RSA -keysize 2048 -validity 10000
```

Enter passwords interactively. Create ignored `frontend/android/key.properties` locally with these fields, replacing placeholders privately:

```properties
storePassword=YOUR_PRIVATE_STORE_PASSWORD
keyPassword=YOUR_PRIVATE_KEY_PASSWORD
keyAlias=lifescript
storeFile=lifescript-release.jks
```

The relative storeFile path resolves from android/app. Back up both signing material and passwords securely outside Git. Existing Gradle configuration signs release builds only when this file exists; otherwise release artifacts are unsigned.

## 7. Build and install the APK

From frontend:

```powershell
flutter doctor -v
flutter build apk --release `
  --dart-define=API_URL=https://YOUR-SERVICE.onrender.com `
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLIC-KEY `
  --dart-define=AUTH_REDIRECT_URL=com.lifescript.frontend://login-callback/
```

Output: `frontend/build/app/outputs/flutter-apk/app-release.apk`. Verify its signing using your installed Android SDK build-tools `apksigner verify --verbose --print-certs` against that APK; check the expected release certificate, not a debug certificate. Copy it to your phone and allow installation from the selected file source, or with a USB-debugging device run `adb install -r build/app/outputs/flutter-apk/app-release.apk`. No Play Store account is needed for direct APK sharing. Play Store publication is a separate process with its own requirements/costs. Increment pubspec.yaml version/build number for later releases and keep the same signing key.

## 8. Verify the actual deployed app

1. Let the API wake before starting the demo; check both health endpoints and worker_ready.
2. Sign in on the website, create a goal/project, save a synthetic journal with a clear future action.
3. Confirm the saved entry progresses to review, and no task appears before approval. Approve once; refresh and ensure no duplicate tasks.
4. Link the task to the project, mark it complete, and confirm it remains complete after reload.
5. Ask the assistant a question about the synthetic journal; inspect the source quote. Model failure must show an honest error.
6. Sign in with a second test account; confirm it cannot see the first account's data.
7. Repeat sign-in and the core journal/review flow on the signed APK using mobile data with your laptop off.
8. Restart/redeploy Render while an entry awaits review. Confirm the review can resume from PostgreSQL checkpoints. Interrupted running jobs may wait for lease expiry.
9. Allow the backend to sleep, reopen the app, and verify wake-up/retry behavior. Never claim instant first requests or on-time sleeping automation.

Gemini generation previously returned HTTP 429 in this development account. Fix/reset quota or select an actually available compatible model before claiming live AI works. An available embedding endpoint and green health checks do not verify generation. Do not change the embedding model without a reindex strategy. Free tiers have usage limits and changing policies; set spending controls where supported and monitor provider dashboards.

## Troubleshooting and updates

- Queued forever: check worker_ready, model quota, schema 12 and Render sleep/lease status. Deploying only uvicorn omits the worker.
- Backend restarts: inspect safe startup errors, database credentials/5432 session pooler, and memory usage. Optional OCR/audio must remain disabled on this small host. More memory/always-on hosting may be required if measurements show OOM.
- Browser CORS failure: compare the exact Vercel origin with JSON CORS_ORIGINS and redeploy Render.
- OAuth opens localhost: correct Supabase Site URL/allowlist, rebuild without a localhost redirect define, and clear the old browser app cache.
- APK cannot reach API: rebuild with the public HTTPS API_URL, not 127.0.0.1/10.0.2.2. Verify native redirect allowlist and internet permission.
- Unsigned APK: check key.properties location, keystore path and passwords; inspect with apksigner.
- Backend updates: review, commit/push yourself and deploy Render. Web updates: rebuild and upload the same build/web folder to the linked Vercel project. APK updates: rebuild, sign with the same key and distribute the new APK.

For always-on use, move to separate paid API/worker services with private PostgreSQL checkpoints, or implement a durable externally triggered job architecture. This free single-container setup does not claim those availability properties. Docker build, cloud deployment and real Android signing/device checks remain unverified until executed on your accounts/toolchain.
