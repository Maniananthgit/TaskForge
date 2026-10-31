from typing import Optional, List
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.enums import UserRole
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self):
        super().__init__(User)

    def get_by_email(self, db: Session, *, email: str) -> Optional[User]:
        return db.query(User).filter(User.email.ilike(email)).first()

    def get_by_role(self, db: Session, *, role: UserRole) -> List[User]:
        return db.query(User).filter(User.role == role).all()

    def search_users(self, db: Session, *, query: str, skip: int = 0, limit: int = 50) -> List[User]:
        pattern = f"%{query}%"
        return (
            db.query(User)
            .filter((User.full_name.ilike(pattern)) | (User.email.ilike(pattern)))
            .offset(skip)
            .limit(limit)
            .all()
        )


user_repo = UserRepository()
