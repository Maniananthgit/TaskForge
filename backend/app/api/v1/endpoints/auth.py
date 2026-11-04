from typing import Optional
from fastapi import APIRouter, Depends, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user, oauth2_scheme
from app.models.user import User
from app.schemas.user import (
    UserCreate, UserUpdate, UserResponse, Token, UserLogin,
    RefreshTokenRequest, ChangePasswordRequest, LogoutRequest
)
from app.schemas.common import MessageResponse
from app.services.auth_service import auth_service
from app.core.rate_limiter import auth_rate_limiter, password_rate_limiter

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED, dependencies=[Depends(auth_rate_limiter)])
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """Register a new user account."""
    user = auth_service.register_user(db, user_in=user_in)
    return user


@router.post("/login", response_model=Token, dependencies=[Depends(auth_rate_limiter)])
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Authenticate with email and password to receive JWT tokens."""
    return auth_service.authenticate_user(db, email=login_data.email, password=login_data.password)


@router.post("/login/oauth", response_model=Token, include_in_schema=False)
def login_oauth(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """OAuth2 compatible token login endpoint for Swagger UI."""
    return auth_service.authenticate_user(db, email=form_data.username, password=form_data.password)


@router.post("/refresh", response_model=Token)
def refresh_token(token_in: RefreshTokenRequest, db: Session = Depends(get_db)):
    """Generate new access token using a valid refresh token."""
    return auth_service.refresh_access_token(db, refresh_token=token_in.refresh_token)


@router.post("/logout", response_model=MessageResponse)
def logout(
    logout_in: Optional[LogoutRequest] = None,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    """Invalidate current JWT access token (and optional refresh token) via revocation blacklist."""
    refresh_token = logout_in.refresh_token if logout_in else None
    auth_service.logout_token(db, token=token, refresh_token=refresh_token)
    return MessageResponse(message="Successfully logged out and session invalidated.")


@router.post("/change-password", response_model=MessageResponse, dependencies=[Depends(password_rate_limiter)])
def change_password(
    pwd_in: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Secure password change with validation of current password."""
    auth_service.change_password(
        db,
        user=current_user,
        current_password=pwd_in.current_password,
        new_password=pwd_in.new_password
    )
    return MessageResponse(message="Password successfully updated.")


@router.get("/me", response_model=UserResponse)
def read_current_user(current_user: User = Depends(get_current_user)):
    """Retrieve authenticated user's profile."""
    return current_user


@router.put("/me", response_model=UserResponse)
def update_current_user(
    update_in: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update authenticated user's profile information."""
    return auth_service.update_profile(db, user=current_user, update_in=update_in)
