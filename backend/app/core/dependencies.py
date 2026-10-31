from typing import Generator, List, Optional
from datetime import datetime, timezone
from fastapi import Depends, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.database import get_db
from app.core.security import decode_token
from app.core.exceptions import AuthenticationFailedException, PermissionDeniedException
from app.models.user import User
from app.models.revoked_token import RevokedToken
from app.models.enums import UserRole
from app.core.logging import logger

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/auth/login"
)


def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    try:
        payload = decode_token(token)
        token_type = payload.get("type")
        if token_type != "access":
            raise AuthenticationFailedException("Invalid token type for access.")
        
        user_id_str: str = payload.get("sub")
        jti: str = payload.get("jti")
        if user_id_str is None:
            raise AuthenticationFailedException("User identity missing from token.")
        user_id = int(user_id_str)
    except JWTError:
        raise AuthenticationFailedException("Token is invalid or expired.")

    # Check database/cache for revoked token (logout strategy)
    if jti:
        revoked = db.query(RevokedToken).filter(RevokedToken.jti == jti).first()
        if revoked:
            raise AuthenticationFailedException("This token has been revoked / logged out.")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise AuthenticationFailedException("User no longer exists.")
    if not user.is_active:
        raise AuthenticationFailedException("User account is inactive.")

    return user


def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    if not current_user.is_active:
        raise AuthenticationFailedException("Inactive user account.")
    return current_user


def require_roles(allowed_roles: List[UserRole]):
    def role_checker(current_user: User = Depends(get_current_active_user)) -> User:
        if current_user.role not in allowed_roles:
            logger.warning(
                f"Unauthorized access attempt by user {current_user.id} ({current_user.role}) "
                f"to resource requiring {allowed_roles}"
            )
            raise PermissionDeniedException(
                f"Action requires one of the following roles: {[r.value for r in allowed_roles]}"
            )
        return current_user
    return role_checker
