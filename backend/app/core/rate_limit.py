"""
In-process sliding-window rate limiter.

Per worker process; good enough for a single small instance. When scaling
horizontally, swap for a shared store (Redis / Upstash) behind the same API.
"""
from __future__ import annotations

import threading
import time
from collections import OrderedDict, deque


class SlidingWindowLimiter:
    def __init__(self, max_requests: int, window_seconds: int = 60, max_keys: int = 50_000):
        self.max_requests = max_requests
        self.window = window_seconds
        self.max_keys = max(1, max_keys)
        # Least recently seen key first. Keeping keys in access order makes
        # eviction O(1): idle keys collect at the front, so pruning never has to
        # scan the whole table (it used to, on *every* request once there were
        # more than max_keys keys — and it could never shrink below max_keys
        # while all keys were fresh, so memory was unbounded too).
        self._hits: OrderedDict[str, deque[float]] = OrderedDict()
        self._lock = threading.Lock()

    def hit(self, key: str) -> bool:
        """Record a request for `key`. Returns False if the key is over its limit."""
        now = time.monotonic()
        cutoff = now - self.window
        with self._lock:
            q = self._hits.get(key)
            if q is None:
                q = self._hits[key] = deque()
            else:
                self._hits.move_to_end(key)
            while q and q[0] <= cutoff:
                q.popleft()
            allowed = len(q) < self.max_requests
            if allowed:
                q.append(now)
            self._evict(cutoff)
            return allowed

    def _evict(self, cutoff: float) -> None:
        """Drop idle keys from the front, and the least recently seen ones beyond max_keys."""
        while self._hits:
            oldest = next(iter(self._hits.values()))
            if len(self._hits) > self.max_keys or not oldest or oldest[-1] <= cutoff:
                self._hits.popitem(last=False)
            else:
                break
