# Career Booster

A Flutter portfolio app that compares a resume with a job and suggests matching
keywords, resume bullets, and a cover letter. Create an account with your name,
email, username and password, then paste or upload a PDF, DOCX or TXT resume and
provide a job URL or description.

The match score is an AI estimate, not a hiring prediction. Review all generated
text and keep only claims that are true. Some job sites block automated access;
in that case, paste the job description. Scanned PDFs need OCR first.

## Download the Android app

1. Go to the [latest release](https://github.com/Tireni/career-booster/releases/latest).
2. Under **Assets**, download `career-booster-android.apk` to your phone.
3. Open the downloaded file and follow the installation steps. Your phone may
   ask you to allow your browser or file manager to install apps.
4. Open **Career Booster**, create an account, and try it with a sample resume.

The APK is a test build for 64-bit ARM Android phones running Android 7.0 or
newer. It uses a development signing key, not a production app-store key.
The APK connects to the project owner's temporary ngrok address. It only works
while their computer, XAMPP, API, and tunnel are running; the address can change.
While that tunnel is running, anyone with the APK can create an account and use
the owner's Gemini API, which may incur charges. The owner can stop the tunnel
when testing is finished.
For your own independent setup, follow the steps below and build the app using
your own API address. The server operator and Google Gemini receive the details
you submit, so use sample information unless you trust the server operator.

## How it works

- **Flutter, Provider and Dio:** the mobile app, state management and API calls.
- **FastAPI and Gemini:** the backend sends the resume and job text to Gemini;
  the Gemini key stays on the server and users consent before analysis.
- **XAMPP MySQL/MariaDB:** account details and one-way password hashes are
  stored locally. Resume submissions and results are not saved in the database.
- **ngrok:** provides an HTTPS address so a phone can reach the local API.
- **Docker:** provides a repeatable backend test environment.

The app follows MVVM and a simple clean architecture: screens display data,
view models manage their state, and repositories and services handle API calls.
The Gemini key is used only by the backend, never by the Flutter app.

```text
lib/                       Flutter app
  presentation/            Screens and Provider view models
  models/                  App data and repository interfaces
  data/                    API services and repository implementations
backend/app/               FastAPI routes, account and analysis services
backend/tests/             Backend tests
test/                      Flutter tests
```

## Local setup on Windows

1. Install [Flutter](https://docs.flutter.dev/get-started/install), Android
   Studio, [XAMPP](https://www.apachefriends.org/), Python 3.12, and
   [ngrok](https://ngrok.com/download). This project was tested with Flutter
   3.47.7 and Java 21. Start **MySQL** in the XAMPP Control Panel.
   For Android builds, use Android Studio's SDK Manager to install NDK
   `27.0.12077973`, and run `flutter doctor --android-licenses` if prompted.
2. Clone the project:

   ```powershell
   git clone https://github.com/Tireni/career-booster.git
   cd career-booster
   ```

3. Create a database named `career_booster` and a dedicated user using
   phpMyAdmin or the MySQL command line. For a local XAMPP setup, the SQL below
   is an example; replace the password with your own:

   ```sql
   CREATE DATABASE career_booster CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'career_booster_user'@'localhost' IDENTIFIED BY 'choose-a-strong-password';
   GRANT ALL PRIVILEGES ON career_booster.* TO 'career_booster_user'@'localhost';
   ```

   Do not expose the database port through ngrok or use your MySQL root account
   in the app. If the database or user already exists, use the existing values
   or choose a different name instead of recreating them.
4. Copy `.env.example` to `.env` in the project root. Fill in your Gemini API key,
   database name, username and password. Generate a long random value for
   `JWT_SECRET` using the command below. Never commit or share `.env`. Get a
   Gemini key from [Google AI Studio](https://aistudio.google.com/apikey).

   ```powershell
   Copy-Item .env.example .env
   py -3.12 -c "import secrets; print(secrets.token_urlsafe(48))"
   notepad .env
   ```

   Paste the generated value into `JWT_SECRET`. Keep `APP_API_KEY` empty unless
   you have deliberately configured the same optional test key in the app.
   Set `GEMINI_MODEL` to a model available to your Google account; this phone
   test used `gemini-2.5-flash`. Google may charge for Gemini API usage.
5. In PowerShell, from this project folder:

   ```powershell
   py -3.12 -m venv backend\.venv
   backend\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
   backend\.venv\Scripts\python.exe backend\init_db.py
   backend\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000
   ```

   Leave this window open. Check `http://127.0.0.1:8000/health` to see whether
   the API is running. Gemini usage may incur charges depending on your plan.
6. In another window, configure ngrok with your own account token if needed
   using `ngrok config add-authtoken YOUR_NGROK_TOKEN`, then run
   `ngrok http 8000 --inspect=false`. The `--inspect=false` option turns
   off ngrok's local request inspection for sensitive resume and password data.
   Copy the HTTPS forwarding URL. The tunnel is public while it is running.
7. In a third window, connect your Android phone with USB debugging enabled and
   run the following, replacing the example with your current ngrok URL:

   ```powershell
   flutter pub get
   flutter run --dart-define=API_BASE_URL=https://YOUR-NGROK-ADDRESS
   ```

   The ngrok address may change when restarted. If it does, restart the app
   with the new address. The computer, API, MySQL and tunnel must remain on
   while the phone uses the app. Android emulators can instead use
   `http://10.0.2.2:8000` in debug mode.

## Testing

```sh
flutter analyze
flutter test
docker build -f backend/Dockerfile.test -t career-booster-tests backend
docker run --rm career-booster-tests
```

Automated tests use a fake Gemini service and do not need a real key or database.
A live analysis sends the provided resume and job description to Google. Use
sample information when testing if you do not want to share personal details.

The included Compose API container is optional. To connect that container to
XAMPP on the host, set `DB_HOST=host.docker.internal` and configure a dedicated
MySQL account and firewall rule for the Docker connection; `127.0.0.1` inside
the container refers to the container itself. The Windows steps above run the
API directly and keep MySQL on localhost.

## Before sharing publicly

This is a portfolio/testing app. Rotate any key that has been shared or exposed
before a public release, use a new secret in the deployment environment, and
never add keys or `.env` to Git or the Flutter app. An API key cannot be reliably
hidden inside a mobile app. The shared `APP_API_KEY` option is only for local
testing; user accounts use signed sessions. Passwords are hashed with scrypt,
and tokens are stored with the phone's secure storage.

For a public service, add email verification, password reset, durable account
recovery, stronger distributed rate limiting and abuse monitoring, review Google
data terms, use a secured hosted database and HTTPS backend, configure your own
app identifier and signing keys, and perform security and real-device testing.
The current process-local rate limits are for a single test server only.
