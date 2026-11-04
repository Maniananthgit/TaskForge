from datetime import datetime, timezone
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token
)
from app.core.exceptions import (
    ConflictException,
    AuthenticationFailedException,
    EntityNotFoundException
)
from app.models.user import User
from app.models.revoked_token import RevokedToken
from app.models.enums import UserRole, UserStatus
from app.schemas.user import UserCreate, UserUpdate, Token, UserResponse
from app.repositories.user_repository import user_repo
from app.core.logging import logger


class AuthService:
    def register_user(self, db: Session, user_in: UserCreate) -> User:
        existing = user_repo.get_by_email(db, email=user_in.email)
        if existing:
            raise ConflictException(f"User with email '{user_in.email}' already exists.")

        user_data = user_in.model_dump()
        password = user_data.pop("password")
        user_data["hashed_password"] = get_password_hash(password)

        user = user_repo.create(db, obj_in=user_data)
        logger.info(f"Registered new user {user.email} (ID: {user.id}) with role {user.role}")
        return user

    def authenticate_user(self, db: Session, email: str, password: str) -> Token:
        user = user_repo.get_by_email(db, email=email)
        if not user:
            raise AuthenticationFailedException("Invalid email or password.")
        if not verify_password(password, user.hashed_password):
            raise AuthenticationFailedException("Invalid email or password.")
        if not user.is_active or user.status != UserStatus.ACTIVE:
            if user.status == UserStatus.PENDING_INVITATION:
                raise AuthenticationFailedException("Account is pending invitation acceptance. Please check your invitation email.")
            if user.status == UserStatus.SUSPENDED:
                raise AuthenticationFailedException("Account has been suspended. Please contact an administrator.")
            if user.status == UserStatus.DELETED:
                raise AuthenticationFailedException("Account no longer exists.")
            raise AuthenticationFailedException("User account is inactive.")

        user.last_login_at = datetime.now(timezone.utc)
        db.commit()

        access_token = create_access_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, 'value') else str(user.role),
            email=user.email
        )
        refresh_token = create_refresh_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, 'value') else str(user.role),
            email=user.email
        )

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            user=UserResponse.model_validate(user)
        )

    def refresh_access_token(self, db: Session, refresh_token: str) -> Token:
        try:
            payload = decode_token(refresh_token)
            if payload.get("type") != "refresh":
                raise AuthenticationFailedException("Invalid token type. Refresh token required.")

            jti = payload.get("jti")
            if jti:
                revoked = db.query(RevokedToken).filter(RevokedToken.jti == jti).first()
                if revoked:
                    raise AuthenticationFailedException("Refresh token has been revoked.")

            user_id = int(payload.get("sub"))
        except Exception:
            raise AuthenticationFailedException("Refresh token is invalid or expired.")

        user = user_repo.get(db, id=user_id)
        if not user or not user.is_active:
            raise AuthenticationFailedException("User does not exist or is inactive.")

        new_access_token = create_access_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, 'value') else str(user.role),
            email=user.email
        )
        new_refresh_token = create_refresh_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, 'value') else str(user.role),
            email=user.email
        )

        # Invalidate previous refresh token
        if jti:
            exp_ts = payload.get("exp", 0)
            revoked_entry = RevokedToken(
                jti=jti,
                token_type="refresh",
                expires_at=datetime.fromtimestamp(exp_ts, tz=timezone.utc).replace(tzinfo=None)
            )
            db.add(revoked_entry)
            db.commit()

        return Token(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
            token_type="bearer",
            user=UserResponse.model_validate(user)
        )

    def logout_token(self, db: Session, token: str, refresh_token: Optional[str] = None) -> None:
        try:
            payload = decode_token(token)
            jti = payload.get("jti")
            token_type = payload.get("type", "access")
            exp_ts = payload.get("exp", 0)

            if jti:
                revoked = RevokedToken(
                    jti=jti,
                    token_type=token_type,
                    expires_at=datetime.fromtimestamp(exp_ts, tz=timezone.utc).replace(tzinfo=None)
                )
                db.add(revoked)
                db.commit()
                logger.info(f"Revoked token {jti} of type {token_type}")
        except Exception as e:
            logger.warning(f"Failed to cleanly revoke access token: {e}")

        if refresh_token:
            try:
                rf_payload = decode_token(refresh_token)
                rf_jti = rf_payload.get("jti")
                rf_exp = rf_payload.get("exp", 0)
                if rf_jti:
                    revoked_rf = RevokedToken(
                        jti=rf_jti,
                        token_type="refresh",
                        expires_at=datetime.fromtimestamp(rf_exp, tz=timezone.utc).replace(tzinfo=None)
                    )
                    db.add(revoked_rf)
                    db.commit()
                    logger.info(f"Revoked refresh token {rf_jti}")
            except Exception as e:
                logger.warning(f"Failed to cleanly revoke refresh token: {e}")

    def change_password(self, db: Session, user: User, current_password: str, new_password: str) -> None:
        if not verify_password(current_password, user.hashed_password):
            raise AuthenticationFailedException("Current password is incorrect.")
        if len(new_password) < 6:
            raise AuthenticationFailedException("New password must be at least 6 characters.")
        user.hashed_password = get_password_hash(new_password)
        db.commit()
        logger.info(f"User {user.id} ({user.email}) changed their password successfully.")

    def update_profile(self, db: Session, user: User, update_in: UserUpdate) -> User:
        update_data = update_in.model_dump(exclude_unset=True)
        if "password" in update_data and update_data["password"]:
            update_data["hashed_password"] = get_password_hash(update_data.pop("password"))
        
        updated_user = user_repo.update(db, db_obj=user, obj_in=update_data)
        return updated_user


auth_service = AuthService()
