import base64
import hashlib
import hmac
import json
import os
import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from fastapi import HTTPException

from app.core import auth, rate_limit
from app.core.rate_limit import SlidingWindowLimiter

SECRET = os.environ["SUPABASE_JWT_SECRET"]


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _forge_hmac_token(claims: dict, secret: bytes, alg: str = "HS256") -> str:
    """Hand-rolled HS* JWT (PyJWT refuses to sign with a PEM key, which is the point of the attack)."""
    digest = {"HS256": hashlib.sha256, "HS512": hashlib.sha512}[alg]
    header = _b64(json.dumps({"alg": alg, "typ": "JWT", "kid": "k1"}).encode())
    signing_input = f"{header}.{_b64(json.dumps(claims).encode())}"
    return f"{signing_input}.{_b64(hmac.new(secret, signing_input.encode(), digest).digest())}"


def _hs(claims: dict) -> str:
    return jwt.encode(claims, SECRET, algorithm="HS256")


def _claims(**overrides) -> dict:
    base = {"sub": "user-1", "aud": "authenticated", "exp": int(time.time()) + 3600, "role": "authenticated"}
    base.update(overrides)
    return {k: v for k, v in base.items() if v is not None}


def test_valid_hs256_token_accepted():
    assert auth.decode_token(_hs(_claims()))["sub"] == "user-1"


@pytest.mark.parametrize(
    "claims",
    [
        _claims(aud="anon"),                      # anon key / wrong audience
        _claims(exp=int(time.time()) - 10),       # expired
        _claims(sub=None),                        # no subject
    ],
)
def test_bad_tokens_rejected(claims):
    with pytest.raises(HTTPException) as exc:
        auth.decode_token(_hs(claims))
    assert exc.value.status_code == 401


def test_wrong_secret_rejected():
    token = jwt.encode(_claims(), "another-secret-that-is-long-enough-for-hs256", algorithm="HS256")
    with pytest.raises(HTTPException):
        auth.decode_token(token)


def test_es256_token_verified_via_jwks(monkeypatch):
    key = ec.generate_private_key(ec.SECP256R1())
    token = jwt.encode(_claims(), key, algorithm="ES256", headers={"kid": "k1"})

    class FakeJwk:
        def get_signing_key_from_jwt(self, _token):
            return type("K", (), {"key": key.public_key()})()

    monkeypatch.setattr(auth, "_get_jwk_client", lambda: FakeJwk())
    assert auth.decode_token(token)["sub"] == "user-1"


def test_garbage_token_rejected():
    with pytest.raises(HTTPException):
        auth.decode_token("not-a-jwt")


def test_sliding_window_limiter():
    lim = SlidingWindowLimiter(max_requests=2, window_seconds=60)
    assert lim.hit("a") and lim.hit("a")
    assert not lim.hit("a")
    assert lim.hit("b")  # keys are independent


class _PublicKeyJwks:
    """A JWKS client that hands out an EC public key (what Supabase's JWKS serves)."""

    def __init__(self, public_key):
        self.public_key = public_key
        self.calls = 0

    def get_signing_key_from_jwt(self, _token):
        self.calls += 1
        return type("K", (), {"key": self.public_key})()


@pytest.mark.parametrize("secret_configured", [True, False])
def test_hs256_token_signed_with_the_jwks_public_key_is_rejected(monkeypatch, secret_configured):
    # Algorithm confusion: an HS256 token whose HMAC secret is the (public) JWKS key.
    public_key = ec.generate_private_key(ec.SECP256R1()).public_key()
    pem = public_key.public_bytes(Encoding.PEM, PublicFormat.SubjectPublicKeyInfo)
    jwks = _PublicKeyJwks(public_key)
    monkeypatch.setattr(auth, "_get_jwk_client", lambda: jwks)
    if not secret_configured:
        settings = auth.get_settings().model_copy(update={"supabase_jwt_secret": ""})
        monkeypatch.setattr(auth, "get_settings", lambda: settings)

    with pytest.raises(HTTPException) as exc:
        auth.decode_token(_forge_hmac_token(_claims(), pem))
    assert exc.value.status_code == 401
    assert jwks.calls == 0  # an HS256 token never selects the JWKS key


def test_other_hmac_algs_are_never_verified_with_the_jwks_key(monkeypatch):
    public_key = ec.generate_private_key(ec.SECP256R1()).public_key()
    pem = public_key.public_bytes(Encoding.PEM, PublicFormat.SubjectPublicKeyInfo)
    monkeypatch.setattr(auth, "_get_jwk_client", lambda: _PublicKeyJwks(public_key))
    with pytest.raises(HTTPException) as exc:
        auth.decode_token(_forge_hmac_token(_claims(), pem, alg="HS512"))
    assert exc.value.status_code == 401 and exc.value.detail == "Invalid token."


def test_jwks_outage_is_503_not_an_invalid_session(monkeypatch):
    token = jwt.encode(_claims(), ec.generate_private_key(ec.SECP256R1()), algorithm="ES256", headers={"kid": "k1"})

    class DownJwks:
        def get_signing_key_from_jwt(self, _token):
            raise jwt.PyJWKClientConnectionError('Fail to fetch data from the url, err: "timed out"')

    monkeypatch.setattr(auth, "_get_jwk_client", lambda: DownJwks())
    with pytest.raises(HTTPException) as exc:
        auth.decode_token(token)
    assert exc.value.status_code == 503 and "timed out" not in str(exc.value.detail)


def test_limiter_memory_stays_bounded_under_many_keys():
    # e.g. spoofed X-Forwarded-For values when not behind a proxy, or a botnet
    lim = SlidingWindowLimiter(max_requests=3, window_seconds=60, max_keys=100)
    for i in range(5_000):
        assert lim.hit(f"ip-{i}")
    assert len(lim._hits) <= 100
    # recent keys are still tracked and still limited
    assert lim.hit("ip-4999") and lim.hit("ip-4999")
    assert not lim.hit("ip-4999")


def test_limiter_forgets_idle_keys(monkeypatch):
    now = [1_000.0]
    monkeypatch.setattr(rate_limit.time, "monotonic", lambda: now[0])
    lim = SlidingWindowLimiter(max_requests=1, window_seconds=60)
    assert lim.hit("a") and not lim.hit("a")
    now[0] += 61
    assert lim.hit("b")
    assert "a" not in lim._hits
    assert lim.hit("a")  # its window has passed
