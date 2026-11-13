import base64
import hashlib
import hmac
import re
import secrets
from datetime import datetime, timedelta, timezone

import jwt
import pymysql
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field, field_validator
from pymysql.cursors import DictCursor

from .config import settings

router = APIRouter(prefix='/api/v1/auth', tags=['account'])
bearer = HTTPBearer(auto_error=False)


def connection():
    config = settings()
    if not config.db_user or not config.jwt_secret:
        raise HTTPException(503, 'Accounts are not configured on the server.')
    try:
        return pymysql.connect(host=config.db_host, port=config.db_port, user=config.db_user,
                               password=config.db_password, database=config.db_name, charset='utf8mb4',
                               cursorclass=DictCursor, autocommit=True, connect_timeout=5, read_timeout=5)
    except pymysql.MySQLError as exc:
        raise HTTPException(503, 'The account database is unavailable.') from exc


def init_database():
    with connection() as db, db.cursor() as cursor:
        cursor.execute('''CREATE TABLE IF NOT EXISTS users (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            full_name VARCHAR(120) NOT NULL,
            email VARCHAR(254) NOT NULL UNIQUE,
            username VARCHAR(32) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci''')


def hash_password(password: str, salt: bytes | None = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1, dklen=32, maxmem=64 * 1024 * 1024)
    return 'scrypt$' + base64.urlsafe_b64encode(salt).decode() + '$' + base64.urlsafe_b64encode(digest).decode()


def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, salt, _ = encoded.split('$')
        if algorithm != 'scrypt':
            return False
        return hmac.compare_digest(hash_password(password, base64.urlsafe_b64decode(salt)), encoded)
    except (ValueError, TypeError):
        return False


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    email: str = Field(min_length=3, max_length=254)
    username: str = Field(min_length=3, max_length=32)
    password: str = Field(min_length=8, max_length=128)

    @field_validator('full_name', 'email', 'username', mode='before')
    @classmethod
    def clean(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator('email')
    @classmethod
    def email_format(cls, value):
        if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', value):
            raise ValueError('Enter a valid email address.')
        return value.lower()

    @field_validator('username')
    @classmethod
    def username_format(cls, value):
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', value):
            raise ValueError('Use letters, numbers, dots, dashes or underscores.')
        return value.lower()


class LoginRequest(BaseModel):
    identity: str = Field(min_length=1, max_length=254)
    password: str = Field(min_length=1, max_length=128)


def create_token(user_id: int) -> str:
    secret = settings().jwt_secret
    if len(secret) < 32:
        raise HTTPException(503, 'Account security is not configured.')
    now = datetime.now(timezone.utc)
    return jwt.encode({'sub': str(user_id), 'iat': now, 'exp': now + timedelta(hours=24)}, secret, algorithm='HS256')


def require_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> int:
    if credentials is None:
        raise HTTPException(401, 'Please sign in to continue.')
    try:
        secret = settings().jwt_secret
        if len(secret) < 32:
            raise HTTPException(503, 'Account security is not configured.')
        payload = jwt.decode(credentials.credentials, secret, algorithms=['HS256'], options={'require': ['sub', 'exp', 'iat']})
        user_id = int(payload['sub'])
        if user_id <= 0:
            raise ValueError()
        return user_id
    except (jwt.PyJWTError, ValueError, TypeError, KeyError) as exc:
        raise HTTPException(401, 'Your session has expired. Please sign in again.') from exc


@router.post('/register', status_code=201)
def register(data: RegisterRequest):
    if len(settings().jwt_secret) < 32:
        raise HTTPException(503, 'Account security is not configured.')
    try:
        with connection() as db, db.cursor() as cursor:
            cursor.execute('INSERT INTO users (full_name, email, username, password_hash) VALUES (%s, %s, %s, %s)',
                           (data.full_name, data.email, data.username, hash_password(data.password)))
            user_id = cursor.lastrowid
    except pymysql.IntegrityError as exc:
        raise HTTPException(409, 'That email or username is already in use.') from exc
    return {'access_token': create_token(user_id), 'token_type': 'bearer',
            'user': {'full_name': data.full_name, 'email': data.email, 'username': data.username}}


@router.post('/login')
def login(data: LoginRequest):
    with connection() as db, db.cursor() as cursor:
        identity = data.identity.strip().lower()
        cursor.execute('SELECT id, full_name, email, username, password_hash FROM users WHERE email=%s OR username=%s',
                       (identity, identity))
        user = cursor.fetchone()
    # Always run the password hash, including for unknown accounts.
    fake = 'scrypt$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    valid = verify_password(data.password, user['password_hash'] if user else fake)
    if not user or not valid:
        raise HTTPException(401, 'Incorrect email, username, or password.')
    return {'access_token': create_token(user['id']), 'token_type': 'bearer',
            'user': {key: user[key] for key in ('full_name', 'email', 'username')}}


@router.get('/me')
def me(user_id: int = Depends(require_user)):
    with connection() as db, db.cursor() as cursor:
        cursor.execute('SELECT full_name, email, username FROM users WHERE id=%s', (user_id,))
        user = cursor.fetchone()
    if not user:
        raise HTTPException(401, 'Your account no longer exists.')
    return user
