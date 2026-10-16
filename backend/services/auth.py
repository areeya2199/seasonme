"""Firebase authentication for API requests; credentials stay outside code."""

import logging
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
_logger = logging.getLogger("uvicorn.error")


def _safe_auth_reason(error):
    # Inspect messages only to select fixed labels; never log their contents.
    for error_type, reason in (
        (auth.ExpiredIdTokenError, "token_expired"),
        (auth.RevokedIdTokenError, "token_revoked"),
        (auth.UserDisabledError, "user_disabled"),
        (auth.CertificateFetchError, "certificate_fetch_failed"),
        (GoogleAuthError, "admin_credentials_error"),
        (OSError, "auth_io_error"),
    ):
        if isinstance(error, error_type):
            return reason
    message = str(error).lower()
    for marker, reason in (
        ('incorrect "aud"', "audience_mismatch"),
        ('incorrect "iss"', "issuer_mismatch"),
        ("token used too early", "token_used_too_early"),
        ("token expired", "token_expired"),
        ("failed to determine project id", "project_id_unavailable"),
        ("could not verify token signature", "invalid_signature"),
    ):
        if marker in message:
            return reason
    return "token_or_configuration_invalid"


def _log_auth_failure(stage, error):
    _logger.warning(
        "[SeasonMe Auth] stage=%s exception_type=%s reason=%s",
        stage, type(error).__name__, _safe_auth_reason(error),
    )


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
        _logger.warning("[SeasonMe Auth] stage=bearer reason=missing_or_invalid_bearer")
        raise _unauthorized()

    try:
        firebase_app = _get_firebase_app()
    except (ValueError, OSError, GoogleAuthError) as error:
        _log_auth_failure("admin_init", error)
        raise HTTPException(
            status_code=503, detail="Authentication service unavailable"
        ) from error

    try:
        # Checks signature, expiry, issuer and audience against the Firebase project.
        return auth.verify_id_token(credentials.credentials, app=firebase_app)
    except auth.CertificateFetchError as error:
        _log_auth_failure("verify", error)
        raise HTTPException(
            status_code=503, detail="Authentication service unavailable"
        ) from error
    except (
        auth.InvalidIdTokenError,
        auth.RevokedIdTokenError,
        auth.UserDisabledError,
        ValueError,
    ) as error:
        _log_auth_failure("verify", error)
        raise _unauthorized() from error
    except (FirebaseError, GoogleAuthError, OSError) as error:
        _log_auth_failure("verify", error)
        raise HTTPException(
            status_code=503, detail="Authentication service unavailable"
        ) from error
