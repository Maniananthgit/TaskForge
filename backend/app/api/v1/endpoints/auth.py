from fastapi import APIRouter, Depends, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_user, oauth2_scheme
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate, UserResponse, Token, UserLogin
from app.schemas.common import MessageResponse
from app.services.auth_service import auth_service

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """Register a new user account."""
    user = auth_service.register_user(db, user_in=user_in)
    return user


@router.post("/login", response_model=Token)
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Authenticate with email and password to receive JWT tokens."""
    return auth_service.authenticate_user(db, email=login_data.email, password=login_data.password)


@router.post("/login/oauth", response_model=Token, include_in_schema=False)
def login_oauth(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """OAuth2 compatible token login endpoint for Swagger UI."""
    return auth_service.authenticate_user(db, email=form_data.username, password=form_data.password)


@router.post("/refresh", response_model=Token)
def refresh_token(token: Token, db: Session = Depends(get_db)):
    """Generate new access token using a valid refresh token."""
    return auth_service.refresh_access_token(db, refresh_token=token.refresh_token)


@router.post("/logout", response_model=MessageResponse)
def logout(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """Invalidate current JWT access token via revocation blacklist."""
    auth_service.logout_token(db, token=token)
    return MessageResponse(message="Successfully logged out and token invalidated.")


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
