"""Firebase authentication for API requests; credentials stay outside code."""

import os
from threading import Lock

import firebase_admin
from firebase_admin import auth
from firebase_admin.exceptions import FirebaseError
from google.auth.exceptions import GoogleAuthError
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


bearer_scheme = HTTPBearer(auto_error=False)
_app_lock = Lock()
_app_name = "seasonme-api"


def _get_firebase_app():
    # Lazy initialization keeps the public health check independent of secrets.
    # ADC reads local GOOGLE_APPLICATION_CREDENTIALS or a future runtime identity.
    with _app_lock:
        try:
            return firebase_admin.get_app(_app_name)
        except ValueError:
            project_id = os.environ.get("FIREBASE_PROJECT_ID")
            options = {"projectId": project_id} if project_id else None
            return firebase_admin.initialize_app(options=options, name=_app_name)


def _unauthorized():
    return HTTPException(
        status_code=401,
        detail="A valid Firebase ID token is required",
        headers={"WWW-Authenticate": "Bearer"},
    )


def require_firebase_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
):
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()

    try:
        firebase_app = _get_firebase_app()
    except (ValueError, OSError, GoogleAuthError) as error:
        raise HTTPException(
            status_code=503, detail="Authentication service unavailable"
        ) from error

    try:
        # Checks signature, expiry, issuer and audience against the Firebase project.
        return auth.verify_id_token(credentials.credentials, app=firebase_app)
    except auth.CertificateFetchError as error:
        raise HTTPException(
            status_code=503, detail="Authentication service unavailable"
        ) from error
    except (
        auth.InvalidIdTokenError,
        auth.RevokedIdTokenError,
        auth.UserDisabledError,
        ValueError,
    ) as error:
        raise _unauthorized() from error
    except (FirebaseError, GoogleAuthError, OSError) as error:
        raise HTTPException(
            status_code=503, detail="Authentication service unavailable"
        ) from error
