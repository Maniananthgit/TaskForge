import hashlib
import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.user import User
from app.models.enums import UserRole, UserStatus
from app.models.project import Project
from app.models.project_member import ProjectMember
from app.models.user_invitation import UserInvitation
from app.models.password_reset_token import PasswordResetToken
from app.models.user_audit_log import UserAuditLog
from app.models.revoked_token import RevokedToken
from app.schemas.user import (
    UserInviteRequest, UserInviteResponse,
    UserUpdate, UserRoleUpdate, UserStatusUpdate,
    UserSummaryMetrics, UserDetailResponse, UserProjectAssignment,
    UserAuditLogResponse, PasswordResetInitiateResponse,
    AcceptInvitationRequest
)
from app.core.security import get_password_hash
from app.core.exceptions import (
    EntityNotFoundException, DuplicateEntityException,
    BusinessRuleViolationException, AuthenticationFailedException
)
from app.services.audit_service import audit_service
from app.worker.tasks import send_invitation_email, send_password_reset_email
from app.core.logging import logger


class UserService:
    @staticmethod
    def _hash_token(raw_token: str) -> str:
        return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    def get_users_paginated(
        self,
        db: Session,
        *,
        skip: int = 0,
        limit: int = 20,
        search: Optional[str] = None,
        role: Optional[UserRole] = None,
        status: Optional[UserStatus] = None,
        project_id: Optional[int] = None,
        include_deleted: bool = False
    ) -> Tuple[List[User], int]:
        query = db.query(User)

        if not include_deleted:
            query = query.filter(User.status != UserStatus.DELETED, User.deleted_at.is_(None))

        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter((User.full_name.ilike(pattern)) | (User.email.ilike(pattern)))

        if role:
            query = query.filter(User.role == role)

        if status:
            query = query.filter(User.status == status)

        if project_id:
            query = query.join(ProjectMember, ProjectMember.user_id == User.id).filter(
                ProjectMember.project_id == project_id
            )

        total = query.count()
        users = query.order_by(User.created_at.desc()).offset(skip).limit(limit).all()
        return users, total

    def get_summary_metrics(self, db: Session) -> UserSummaryMetrics:
        # Exclude soft-deleted from active/inactive stats
        base_query = db.query(User)
        total_users = base_query.filter(User.status != UserStatus.DELETED).count()
        active_users = base_query.filter(User.status == UserStatus.ACTIVE).count()
        inactive_users = base_query.filter(User.status == UserStatus.INACTIVE).count()
        suspended_users = base_query.filter(User.status == UserStatus.SUSPENDED).count()
        pending_invitations = base_query.filter(User.status == UserStatus.PENDING_INVITATION).count()

        admins_count = base_query.filter(User.role == UserRole.ADMIN, User.status != UserStatus.DELETED).count()
        pms_count = base_query.filter(User.role == UserRole.PROJECT_MANAGER, User.status != UserStatus.DELETED).count()
        devs_count = base_query.filter(User.role == UserRole.DEVELOPER, User.status != UserStatus.DELETED).count()

        return UserSummaryMetrics(
            total_users=total_users,
            active_users=active_users,
            inactive_users=inactive_users,
            suspended_users=suspended_users,
            pending_invitations=pending_invitations,
            admins_count=admins_count,
            project_managers_count=pms_count,
            developers_count=devs_count,
        )

    def get_user_detail(self, db: Session, user_id: int) -> UserDetailResponse:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise EntityNotFoundException("User", user_id)

        # Build project assignments
        memberships = (
            db.query(ProjectMember, Project.title)
            .join(Project, Project.id == ProjectMember.project_id)
            .filter(ProjectMember.user_id == user_id)
            .all()
        )
        assigned_projects = [
            UserProjectAssignment(
                project_id=m[0].project_id,
                project_title=m[1],
                role_in_project=m[0].role_in_project,
                joined_at=m[0].joined_at
            )
            for m in memberships
        ]

        latest_invitation = (
            db.query(UserInvitation)
            .filter(UserInvitation.user_id == user_id)
            .order_by(UserInvitation.created_at.desc())
            .first()
        )
        is_pending = user.status == UserStatus.PENDING_INVITATION
        expires_at = latest_invitation.expires_at if latest_invitation else None

        return UserDetailResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            is_active=user.is_active,
            phone_number=user.phone_number,
            department=user.department,
            job_title=user.job_title,
            avatar_url=user.avatar_url,
            last_login_at=user.last_login_at,
            deleted_at=user.deleted_at,
            created_at=user.created_at,
            updated_at=user.updated_at,
            assigned_projects=assigned_projects,
            invitation_pending=is_pending,
            invitation_expires_at=expires_at,
        )

    def invite_user(
        self,
        db: Session,
        *,
        current_admin: User,
        invite_in: UserInviteRequest,
        ip_address: Optional[str] = None
    ) -> UserInviteResponse:
        # Check unique email
        existing = db.query(User).filter(User.email.ilike(invite_in.email.strip())).first()
        if existing:
            if existing.status == UserStatus.DELETED:
                raise BusinessRuleViolationException(
                    "A soft-deleted user with this email already exists. Please restore the account instead."
                )
            raise DuplicateEntityException("User", f"email '{invite_in.email}'")

        # Generate temporary placeholder password (cannot be used directly without activation)
        temp_secret = secrets.token_urlsafe(32)
        user = User(
            email=invite_in.email.strip().lower(),
            full_name=invite_in.full_name.strip(),
            hashed_password=get_password_hash(temp_secret),
            role=invite_in.role,
            status=UserStatus.PENDING_INVITATION,
            is_active=False,
            phone_number=invite_in.phone_number,
            department=invite_in.department,
            job_title=invite_in.job_title,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        # Assign projects if requested
        if invite_in.assigned_project_ids:
            for p_id in invite_in.assigned_project_ids:
                proj = db.query(Project).filter(Project.id == p_id).first()
                if proj:
                    member = ProjectMember(project_id=p_id, user_id=user.id, role_in_project="Member")
                    db.add(member)
            db.commit()

        # Generate invitation token
        raw_token = secrets.token_urlsafe(32)
        token_hash = self._hash_token(raw_token)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

        invitation = UserInvitation(
            user_id=user.id,
            token_hash=token_hash,
            invited_by_id=current_admin.id,
            expires_at=expires_at,
        )
        db.add(invitation)
        db.commit()

        # Queue async email notification
        try:
            send_invitation_email.delay(
                recipient_email=user.email,
                recipient_name=user.full_name,
                invitation_link=f"/accept-invitation?token={raw_token}"
            )
        except Exception as e:
            logger.warning(f"Celery task dispatch skipped: {e}")

        # Audit
        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action="user_invited",
            details={
                "email": user.email,
                "role": user.role.value,
                "department": user.department,
                "assigned_projects": invite_in.assigned_project_ids
            },
            ip_address=ip_address
        )

        return UserInviteResponse(
            user_id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            invitation_expires_at=expires_at,
            invitation_token=raw_token,
            email_delivery_status="Invitation created. Email delivery is pending configuration (SMTP / SES)."
        )

    def accept_invitation(
        self,
        db: Session,
        *,
        token: str,
        password: str,
        ip_address: Optional[str] = None
    ) -> User:
        token_hash = self._hash_token(token)
        invitation = (
            db.query(UserInvitation)
            .filter(UserInvitation.token_hash == token_hash)
            .first()
        )
        if not invitation:
            raise AuthenticationFailedException("Invalid invitation token.")

        if not invitation.is_valid:
            if invitation.accepted_at:
                raise BusinessRuleViolationException("Invitation token has already been used.")
            if invitation.revoked_at:
                raise BusinessRuleViolationException("Invitation token has been revoked by an administrator.")
            raise BusinessRuleViolationException("Invitation token has expired. Please request a new invitation.")

        user = db.query(User).filter(User.id == invitation.user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", invitation.user_id)

        # Set user password and activate
        user.hashed_password = get_password_hash(password)
        user.status = UserStatus.ACTIVE
        user.is_active = True
        invitation.accepted_at = datetime.now(timezone.utc)

        db.commit()
        db.refresh(user)

        audit_service.log_action(
            db,
            actor_id=user.id,
            target_user_id=user.id,
            action="invitation_accepted",
            details={"email": user.email},
            ip_address=ip_address
        )
        return user

    def resend_invitation(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        ip_address: Optional[str] = None
    ) -> UserInviteResponse:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", user_id)

        if user.status != UserStatus.PENDING_INVITATION:
            raise BusinessRuleViolationException(f"Cannot resend invitation. User status is '{user.status.value}'.")

        # Revoke existing open invitations
        open_invitations = (
            db.query(UserInvitation)
            .filter(
                UserInvitation.user_id == user_id,
                UserInvitation.accepted_at.is_(None),
                UserInvitation.revoked_at.is_(None)
            )
            .all()
        )
        now = datetime.now(timezone.utc)
        for inv in open_invitations:
            inv.revoked_at = now

        # Create fresh invitation token
        raw_token = secrets.token_urlsafe(32)
        token_hash = self._hash_token(raw_token)
        expires_at = now + timedelta(hours=24)

        new_inv = UserInvitation(
            user_id=user.id,
            token_hash=token_hash,
            invited_by_id=current_admin.id,
            expires_at=expires_at,
        )
        db.add(new_inv)
        db.commit()

        try:
            send_invitation_email.delay(
                recipient_email=user.email,
                recipient_name=user.full_name,
                invitation_link=f"/accept-invitation?token={raw_token}"
            )
        except Exception as e:
            logger.warning(f"Celery task dispatch skipped: {e}")

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action="invitation_resent",
            details={"email": user.email},
            ip_address=ip_address
        )

        return UserInviteResponse(
            user_id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            invitation_expires_at=expires_at,
            invitation_token=raw_token,
            email_delivery_status="New invitation token issued. Email delivery is pending configuration (SMTP / SES)."
        )

    def update_user_profile(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        update_in: UserUpdate,
        ip_address: Optional[str] = None
    ) -> User:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", user_id)

        changes = {}
        if update_in.role is not None and update_in.role != user.role:
            if user.id == current_admin.id and update_in.role != UserRole.ADMIN:
                raise BusinessRuleViolationException("Administrators cannot demote their own account.")
            if user.role == UserRole.ADMIN and update_in.role != UserRole.ADMIN:
                active_admin_count = (
                    db.query(User)
                    .filter(User.role == UserRole.ADMIN, User.status == UserStatus.ACTIVE)
                    .count()
                )
                if active_admin_count <= 1:
                    raise BusinessRuleViolationException(
                        "Cannot demote the last remaining active Administrator in the system."
                    )
            changes["role"] = {"old": user.role.value, "new": update_in.role.value}
            user.role = update_in.role

        if update_in.full_name is not None and update_in.full_name.strip() != user.full_name:
            changes["full_name"] = {"old": user.full_name, "new": update_in.full_name.strip()}
            user.full_name = update_in.full_name.strip()

        if update_in.phone_number is not None and update_in.phone_number != user.phone_number:
            changes["phone_number"] = {"old": user.phone_number, "new": update_in.phone_number}
            user.phone_number = update_in.phone_number

        if update_in.department is not None and update_in.department != user.department:
            changes["department"] = {"old": user.department, "new": update_in.department}
            user.department = update_in.department

        if update_in.job_title is not None and update_in.job_title != user.job_title:
            changes["job_title"] = {"old": user.job_title, "new": update_in.job_title}
            user.job_title = update_in.job_title

        if update_in.avatar_url is not None and update_in.avatar_url != user.avatar_url:
            user.avatar_url = update_in.avatar_url

        if update_in.password is not None:
            user.hashed_password = get_password_hash(update_in.password)
            changes["password"] = "password_manually_updated"

        db.commit()
        db.refresh(user)

        if changes:
            audit_service.log_action(
                db,
                actor_id=current_admin.id,
                target_user_id=user.id,
                action="user_updated",
                details=changes,
                ip_address=ip_address
            )
        return user

    def update_user_role(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        role_in: UserRoleUpdate,
        ip_address: Optional[str] = None
    ) -> User:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", user_id)

        # 1. Prevent admin self-demotion
        if user.id == current_admin.id and role_in.role != UserRole.ADMIN:
            raise BusinessRuleViolationException("Administrators cannot demote their own account.")

        # 2. Prevent removing the last active admin
        if user.role == UserRole.ADMIN and role_in.role != UserRole.ADMIN:
            active_admin_count = (
                db.query(User)
                .filter(User.role == UserRole.ADMIN, User.status == UserStatus.ACTIVE)
                .count()
            )
            if active_admin_count <= 1:
                raise BusinessRuleViolationException(
                    "Cannot demote the last remaining active Administrator in the system."
                )

        old_role = user.role
        user.role = role_in.role
        db.commit()
        db.refresh(user)

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action="role_changed",
            details={"old_role": old_role.value, "new_role": user.role.value},
            ip_address=ip_address
        )
        return user

    def update_user_status(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        status_in: UserStatusUpdate,
        ip_address: Optional[str] = None
    ) -> User:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", user_id)

        # Prevent changing own status
        if user.id == current_admin.id:
            raise BusinessRuleViolationException("Administrators cannot change their own account status.")

        # Prevent deactivating the last active Admin
        if user.role == UserRole.ADMIN and status_in.status != UserStatus.ACTIVE:
            active_admin_count = (
                db.query(User)
                .filter(User.role == UserRole.ADMIN, User.status == UserStatus.ACTIVE)
                .count()
            )
            if active_admin_count <= 1:
                raise BusinessRuleViolationException(
                    "Cannot deactivate or suspend the last active Administrator in the system."
                )

        old_status = user.status
        user.status = status_in.status
        user.is_active = (status_in.status == UserStatus.ACTIVE)

        db.commit()
        db.refresh(user)

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action=f"status_changed_to_{user.status.value}",
            details={"old_status": old_status.value, "new_status": user.status.value},
            ip_address=ip_address
        )
        return user

    def soft_delete_user(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        ip_address: Optional[str] = None
    ) -> User:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise EntityNotFoundException("User", user_id)

        if user.status == UserStatus.DELETED:
            raise BusinessRuleViolationException("User is already deleted.")

        # Prevent deleting self
        if user.id == current_admin.id:
            raise BusinessRuleViolationException("Administrators cannot delete their own account.")

        # Prevent deleting last active admin
        if user.role == UserRole.ADMIN:
            active_admin_count = (
                db.query(User)
                .filter(User.role == UserRole.ADMIN, User.status == UserStatus.ACTIVE)
                .count()
            )
            if active_admin_count <= 1:
                raise BusinessRuleViolationException(
                    "Cannot soft-delete the last active Administrator in the system."
                )

        user.status = UserStatus.DELETED
        user.is_active = False
        user.deleted_at = datetime.now(timezone.utc)

        db.commit()
        db.refresh(user)

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action="user_soft_deleted",
            details={"email": user.email, "role": user.role.value},
            ip_address=ip_address
        )
        return user

    def restore_user(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        ip_address: Optional[str] = None
    ) -> User:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise EntityNotFoundException("User", user_id)

        if user.status != UserStatus.DELETED:
            raise BusinessRuleViolationException(f"User is not deleted (current status: '{user.status.value}').")

        user.status = UserStatus.INACTIVE
        user.is_active = False
        user.deleted_at = None

        db.commit()
        db.refresh(user)

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action="user_restored",
            details={"email": user.email},
            ip_address=ip_address
        )
        return user

    def initiate_password_reset(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        ip_address: Optional[str] = None
    ) -> PasswordResetInitiateResponse:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", user_id)

        # Invalidate old unused reset tokens
        old_tokens = (
            db.query(PasswordResetToken)
            .filter(PasswordResetToken.user_id == user_id, PasswordResetToken.used_at.is_(None))
            .all()
        )
        now = datetime.now(timezone.utc)
        for t in old_tokens:
            t.used_at = now

        raw_token = secrets.token_urlsafe(32)
        token_hash = self._hash_token(raw_token)
        expires_at = now + timedelta(hours=24)

        reset_record = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        db.add(reset_record)
        db.commit()

        try:
            send_password_reset_email.delay(
                recipient_email=user.email,
                recipient_name=user.full_name,
                reset_link=f"/reset-password?token={raw_token}"
            )
        except Exception as e:
            logger.warning(f"Celery task dispatch skipped: {e}")

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user.id,
            action="password_reset_initiated",
            details={"email": user.email},
            ip_address=ip_address
        )

        return PasswordResetInitiateResponse(
            message=f"Password reset initiated for user '{user.email}'.",
            expires_at=expires_at,
            reset_token=raw_token,
            email_delivery_status="Password reset token issued. Email delivery is pending configuration (SMTP / SES)."
        )

    def confirm_password_reset(
        self,
        db: Session,
        *,
        token: str,
        new_password: str,
        ip_address: Optional[str] = None
    ) -> User:
        token_hash = self._hash_token(token)
        reset_record = (
            db.query(PasswordResetToken)
            .filter(PasswordResetToken.token_hash == token_hash)
            .first()
        )
        if not reset_record:
            raise AuthenticationFailedException("Invalid password reset token.")

        if not reset_record.is_valid:
            if reset_record.used_at:
                raise BusinessRuleViolationException("Password reset token has already been used.")
            raise BusinessRuleViolationException("Password reset token has expired.")

        user = db.query(User).filter(User.id == reset_record.user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", reset_record.user_id)

        user.hashed_password = get_password_hash(new_password)
        reset_record.used_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user)

        audit_service.log_action(
            db,
            actor_id=user.id,
            target_user_id=user.id,
            action="password_reset_completed",
            details={"email": user.email},
            ip_address=ip_address
        )
        return user

    def assign_user_to_project(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        project_id: int,
        role_in_project: str = "Member",
        ip_address: Optional[str] = None
    ) -> ProjectMember:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or user.status == UserStatus.DELETED:
            raise EntityNotFoundException("User", user_id)

        project = db.query(Project).filter(Project.id == project_id).first()
        if not project:
            raise EntityNotFoundException("Project", project_id)

        existing = (
            db.query(ProjectMember)
            .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == user_id)
            .first()
        )
        if existing:
            raise BusinessRuleViolationException(f"User is already a member of project '{project.title}'.")

        member = ProjectMember(
            project_id=project_id,
            user_id=user_id,
            role_in_project=role_in_project
        )
        db.add(member)
        db.commit()
        db.refresh(member)

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user_id,
            action="project_assigned",
            details={"project_id": project_id, "project_title": project.title, "role": role_in_project},
            ip_address=ip_address
        )
        return member

    def remove_user_from_project(
        self,
        db: Session,
        *,
        current_admin: User,
        user_id: int,
        project_id: int,
        ip_address: Optional[str] = None
    ) -> None:
        member = (
            db.query(ProjectMember)
            .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == user_id)
            .first()
        )
        if not member:
            raise EntityNotFoundException("ProjectMember", f"user={user_id}, project={project_id}")

        proj = db.query(Project).filter(Project.id == project_id).first()
        proj_title = proj.title if proj else str(project_id)

        db.delete(member)
        db.commit()

        audit_service.log_action(
            db,
            actor_id=current_admin.id,
            target_user_id=user_id,
            action="project_removed",
            details={"project_id": project_id, "project_title": proj_title},
            ip_address=ip_address
        )

    def get_user_activity(self, db: Session, user_id: int) -> List[UserAuditLogResponse]:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise EntityNotFoundException("User", user_id)

        logs = (
            db.query(UserAuditLog, User.full_name)
            .outerjoin(User, User.id == UserAuditLog.actor_id)
            .filter(UserAuditLog.target_user_id == user_id)
            .order_by(UserAuditLog.created_at.desc())
            .limit(100)
            .all()
        )

        return [
            UserAuditLogResponse(
                id=entry[0].id,
                actor_id=entry[0].actor_id,
                actor_name=entry[1] if entry[1] else ("System" if entry[0].actor_id is None else "User"),
                target_user_id=entry[0].target_user_id,
                action=entry[0].action,
                details=entry[0].details,
                ip_address=entry[0].ip_address,
                created_at=entry[0].created_at
            )
            for entry in logs
        ]


user_service = UserService()
