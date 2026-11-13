import hmac
import logging
import time
from collections import defaultdict, deque
from threading import Lock
from typing import Annotated

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .analysis_service import AnalysisService
from .config import settings
from .job_fetcher import JobFetchError, fetch_job
from .resume import MAX_FILE_BYTES, MAX_TEXT, ResumeError, extract_resume
from .schemas import AnalysisResult
from .auth import router as auth_router, require_user

logger = logging.getLogger('career_booster')
_attempts = defaultdict(deque)
_attempts_lock = Lock()


class RequestSizeLimit:
    """Bound incoming bodies even when clients omit Content-Length."""
    def __init__(self, app, max_bytes: int):
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            await self.app(scope, receive, send)
            return
        chunks = []
        size = 0
        while True:
            message = await receive()
            if message['type'] == 'http.disconnect':
                return
            chunk = message.get('body', b'')
            size += len(chunk)
            if size > self.max_bytes:
                response = JSONResponse({'detail': 'Request is too large.'}, status_code=413,
                                        headers={'Cache-Control': 'no-store'})
                await response(scope, receive, send)
                return
            chunks.append(chunk)
            if not message.get('more_body', False):
                break
        body = b''.join(chunks)
        first = True

        async def replay():
            nonlocal first
            if first:
                first = False
                return {'type': 'http.request', 'body': body, 'more_body': False}
            return await receive()

        await self.app(scope, replay, send)


app = FastAPI(title='Career Booster API', version='1.0.0')
app.include_router(auth_router)
app.add_middleware(RequestSizeLimit, max_bytes=MAX_FILE_BYTES + 100_000)
origins = [x.strip() for x in settings().allowed_origins.split(',') if x.strip()]
if origins:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=['POST', 'GET'],
                       allow_headers=['Content-Type', 'X-App-Key', 'Authorization', 'ngrok-skip-browser-warning'])


@app.middleware('http')
async def reject_large_requests(request, call_next):
    path = request.url.path
    if request.method == 'POST' and (path.startswith('/api/v1/auth/') or path == '/api/v1/analyze'):
        now = time.monotonic()
        host = request.client.host if request.client else 'unknown'
        bucket = 'auth' if path.startswith('/api/v1/auth/') else 'analysis'
        limit = 12 if bucket == 'auth' else 10
        with _attempts_lock:
            # Keep only a bounded number of recent client buckets for this demo.
            if len(_attempts) > 10000:
                _attempts.clear()
            attempts = _attempts[(host, bucket)]
            while attempts and attempts[0] <= now - 60:
                attempts.popleft()
            if len(attempts) >= limit:
                return JSONResponse({'detail': 'Too many requests. Please wait a minute.'},
                                    status_code=429, headers={'Retry-After': '60', 'Cache-Control': 'no-store'})
            attempts.append(now)
    length = request.headers.get('content-length')
    try:
        if length and (int(length) < 0 or int(length) > MAX_FILE_BYTES + 100_000):
            return JSONResponse({'detail': 'Request is too large.'}, status_code=413)
    except ValueError:
        return JSONResponse({'detail': 'Invalid content length.'}, status_code=400)
    response = await call_next(request)
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    return response


def authorize(x_app_key: Annotated[str | None, Header()] = None):
    key = settings().app_api_key
    if key and not hmac.compare_digest(x_app_key or '', key):
        raise HTTPException(401, 'Invalid application key.')


def get_analyzer():
    config = settings()
    if not config.gemini_api_key:
        raise HTTPException(503, 'Gemini is not configured on the server.')
    return AnalysisService(config.gemini_api_key, config.gemini_model)


@app.get('/health')
def health():
    return {'status': 'ok'}


@app.post('/api/v1/analyze', response_model=AnalysisResult, dependencies=[Depends(authorize), Depends(require_user)])
async def analyze(
    resume_text: Annotated[str, Form()] = '',
    job_url: Annotated[str, Form()] = '',
    job_text: Annotated[str, Form()] = '',
    resume_file: Annotated[UploadFile | None, File()] = None,
    analyzer: AnalysisService = Depends(get_analyzer),
):
    resume_text, job_url, job_text = resume_text.strip(), job_url.strip(), job_text.strip()
    if bool(resume_text) == bool(resume_file):
        raise HTTPException(422, 'Provide either pasted resume text or one resume file.')
    if bool(job_url) == bool(job_text):
        raise HTTPException(422, 'Provide either a job URL or a pasted job description.')
    if len(resume_text) > MAX_TEXT or len(job_text) > 30000 or len(job_url) > 2048:
        raise HTTPException(422, 'The submitted text is too long.')
    if resume_file:
        try:
            content = await resume_file.read(MAX_FILE_BYTES + 1)
            resume_text = extract_resume(resume_file.filename or '', content)
        except ResumeError as exc:
            raise HTTPException(422, str(exc)) from exc
        finally:
            await resume_file.close()
    if len(resume_text) < 30:
        raise HTTPException(422, 'Please provide at least 30 characters of resume text.')
    if job_url:
        try:
            job_text = await fetch_job(job_url)
        except JobFetchError as exc:
            raise HTTPException(422, str(exc)) from exc
    if len(job_text) < 80:
        raise HTTPException(422, 'Please provide at least 80 characters of job description.')
    try:
        return await analyzer.analyze(resume_text, job_text)
    except Exception as exc:
        # Never log resume content, job text, prompts, keys, or provider errors.
        logger.warning('Analysis provider failed: %s', type(exc).__name__)
        raise HTTPException(502, 'Analysis is unavailable right now. Please try again.') from exc
