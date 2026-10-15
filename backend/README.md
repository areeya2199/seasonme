# Local Firebase authentication

`GET /` remains public. `POST /analyze` requires a Firebase ID token in
`Authorization: Bearer <token>`. Missing, invalid and expired tokens return 401
before image decoding or analysis. Successful analysis JSON is unchanged.
Credential/configuration and certificate-fetch failures return 503 and never
allow analysis through.

## Credentials on Windows

Use a Firebase Admin service-account JSON for the same project as Flutter
(`seasonme-977e3`). Keep the file **outside this repository**, for example
`C:\Users\Gim\seasonme-secrets\firebase-admin.json`. Android's
`google-services.json` and iOS's `GoogleService-Info.plist` are client
configuration, not Admin credentials. Never embed an Admin private key in Flutter
or commit it to Git.

In the PowerShell session that starts the backend:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\Users\Gim\seasonme-secrets\firebase-admin.json'
$env:FIREBASE_PROJECT_ID = 'seasonme-977e3'
Set-Location C:\Users\Gim\seasonme\backend
# .venv is the isolated environment used to verify this change locally.
.\.venv\Scripts\python.exe -m pip install firebase-admin==7.7.0 python-multipart==0.0.32
.\.venv\Scripts\python.exe -B -m uvicorn main:app --host 0.0.0.0 --port 8000
```

The credentials variable is a **file path**, not JSON text. This change does not
generate or supply credentials. The local `.venv` was created with
`--system-site-packages` to reuse the working analysis dependencies without
changing the global Python environment. On a fresh machine create a virtualenv
and install `requirements.txt`. Existing requirements include both OpenCV
packages; that pre-existing dependency issue is outside this auth change.

The Admin app initializes on the first authenticated request through Application
Default Credentials (ADC). A health check does not validate credential setup.
Firebase's `getIdToken()` refreshes expired client ID tokens; the backend still
validates each submitted token independently. Default SDK verification does not
perform an additional user revocation lookup on every request.

## Tests and manual verification

From `backend`, install test dependencies in an isolated environment and run:

```powershell
python -m pip install -r requirements-test.txt
python -B -m unittest discover -s tests -v
```

Automated auth tests mock the Admin SDK boundary and need no real credentials.
They send multipart HTTP requests through FastAPI and verify that auth failures
block image decoding and analysis, while successful JSON stays unchanged.

For a real local check, start the backend with the variables above, sign into
Flutter, and analyze a photo. Check that unauthenticated requests return 401,
signed-in requests succeed, and a signed-out app cannot upload. The existing API
URL must be reachable from your phone. Use a trusted local test network with the
existing HTTP URL; ID tokens are bearer credentials. Future internet-facing
operation requires HTTPS. Never log tokens or show them in screenshots/reports.

## Future Cloud setup

Keep this verification code. On Google-hosted runtimes use ADC with the runtime
service-account identity. Elsewhere mount credentials through the provider's
secret facility and set `GOOGLE_APPLICATION_CREDENTIALS` to the runtime file path.
Set `FIREBASE_PROJECT_ID` to the Flutter project. Never copy credentials into a
Docker image. This change does not deploy or configure any Cloud provider.

Official references:
- https://firebase.google.com/docs/auth/admin/verify-id-tokens
- https://firebase.google.com/docs/admin/setup
