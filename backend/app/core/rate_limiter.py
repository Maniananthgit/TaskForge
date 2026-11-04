import time
import threading
from collections import defaultdict
from typing import Optional
from fastapi import Request, HTTPException, status
from app.core.config import settings
from app.core.logging import logger


class SlidingWindowRateLimiter:
    """Thread-safe in-memory sliding-window rate limiter for sensitive endpoints.

    Prevents brute-force credential stuffing, invitation abuse, and DoS.
    """

    def __init__(self, requests_per_minute: int = 15, name: str = "default"):
        self.requests_per_minute = requests_per_minute
        self.window_seconds = 60
        self.name = name
        self._history = defaultdict(list)
        self._lock = threading.Lock()

    def __call__(self, request: Request):
        # In test environments, disable throttling to ensure deterministic test execution
        if settings.ENVIRONMENT == "testing":
            return

        client_ip = request.client.host if request.client else "unknown"
        # Support trusted reverse proxies (Cloud Run / Nginx / Load Balancer)
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            client_ip = forwarded.split(",")[0].strip()

        now = time.time()
        with self._lock:
            # Purge entries outside sliding window
            timestamps = [t for t in self._history[client_ip] if now - t < self.window_seconds]
            if len(timestamps) >= self.requests_per_minute:
                retry_after = int(self.window_seconds - (now - timestamps[0])) + 1
                logger.warning(
                    f"Rate limit exceeded on '{self.name}' by client {client_ip}. "
                    f"Attempts: {len(timestamps)}/{self.requests_per_minute} in 60s."
                )
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Too many requests on {self.name}. Please wait {retry_after} seconds.",
                    headers={"Retry-After": str(max(retry_after, 1))}
                )

            timestamps.append(now)
            self._history[client_ip] = timestamps


# Preconfigured rate limiters for sensitive endpoints
auth_rate_limiter = SlidingWindowRateLimiter(requests_per_minute=20, name="Authentication")
invite_rate_limiter = SlidingWindowRateLimiter(requests_per_minute=30, name="User Invitation")
password_rate_limiter = SlidingWindowRateLimiter(requests_per_minute=10, name="Password Operations")

