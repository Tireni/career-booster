import io
from types import SimpleNamespace
from unittest.mock import AsyncMock
import pytest
from fastapi.testclient import TestClient
from docx import Document

from app.main import app, get_analyzer
from app.resume import ResumeError, extract_resume
from app.schemas import AnalysisResult
from app.job_fetcher import JobFetchError, validate_url
from app.job_fetcher import PublicResolver
from app.analysis_service import AnalysisService
from app.auth import require_user, hash_password, verify_password


class FakeAnalyzer:
    async def analyze(self, resume, job):
        return AnalysisResult(match_score=72, summary='Some overlap', matched_keywords=['Python'],
                              missing_keywords=['Docker'], tailored_bullets=['Built Python apps'],
                              cover_letter='I would like to apply.', cautions=['Review all suggestions.'])


@pytest.fixture
def client():
    app.dependency_overrides[get_analyzer] = lambda: FakeAnalyzer()
    app.dependency_overrides[require_user] = lambda: 1
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


def test_password_hash_is_salted_and_verifiable():
    first = hash_password('a strong password')
    second = hash_password('a strong password')
    assert first != second
    assert 'a strong password' not in first
    assert verify_password('a strong password', first)
    assert not verify_password('wrong', first)


def test_analysis_requires_an_account():
    app.dependency_overrides[get_analyzer] = lambda: FakeAnalyzer()
    try:
        with TestClient(app) as anonymous:
            response = anonymous.post('/api/v1/analyze', data={'resume_text': 'x' * 40, 'job_text': 'y' * 100})
            assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()


def test_analyze_text_and_health(client):
    assert client.get('/health').json() == {'status': 'ok'}
    response = client.post('/api/v1/analyze', data={'resume_text': 'Python developer experience. ' * 4,
                                                   'job_text': 'Python developer position. ' * 5})
    assert response.status_code == 200
    assert response.json()['match_score'] == 72
    assert response.headers['cache-control'] == 'no-store'


def test_file_upload_and_validation(client):
    response = client.post('/api/v1/analyze', files={'resume_file': ('cv.txt', b'Experienced Python developer ' * 4, 'text/plain')},
                           data={'job_text': 'Python developer position. ' * 5})
    assert response.status_code == 200
    assert client.post('/api/v1/analyze', data={'resume_text': 'short', 'job_text': 'short'}).status_code == 422
    assert client.post('/api/v1/analyze', data={'resume_text': 'x' * 40, 'job_text': 'y' * 100,
                                                'job_url': 'https://example.com'}).status_code == 422
    bad = client.post('/api/v1/analyze', files={'resume_file': ('cv.exe', b'x' * 100)}, data={'job_text': 'y' * 100})
    assert bad.status_code == 422


def test_chunked_request_size_is_bounded(client):
    chunks = (b'x' * 100_000 for _ in range(23))
    response = client.post('/api/v1/analyze', content=chunks,
                           headers={'content-type': 'application/octet-stream'})
    assert response.status_code == 413


def test_docx_and_file_limits():
    doc = Document()
    doc.add_paragraph('Experienced Python developer building web applications.')
    data = io.BytesIO()
    doc.save(data)
    assert 'Python developer' in extract_resume('resume.docx', data.getvalue())
    with pytest.raises(ResumeError):
        extract_resume('a.txt', b'x' * (2 * 1024 * 1024 + 1))
    with pytest.raises(ResumeError):
        extract_resume('a.pdf', b'invalid')


@pytest.mark.parametrize('url', ['http://localhost/a', 'http://127.0.0.1/', 'http://169.254.169.254/',
                                 'http://[::1]/', 'file:///etc/passwd', 'https://user:pass@example.com/',
                                 'http://example.com:8080/'])
def test_rejects_unsafe_urls(url):
    with pytest.raises(JobFetchError):
        validate_url(url)


def test_provider_failure_does_not_leak_details(client, caplog):
    class Broken:
        async def analyze(self, resume, job):
            raise RuntimeError('secret or private resume')
    app.dependency_overrides[get_analyzer] = lambda: Broken()
    response = client.post('/api/v1/analyze', data={'resume_text': 'x' * 40, 'job_text': 'y' * 100})
    assert response.status_code == 502
    assert 'secret' not in response.text
    assert 'secret' not in caplog.text


@pytest.mark.asyncio
async def test_dns_resolver_rejects_private_or_mixed_addresses():
    class FakeResolver:
        async def resolve(self, host, port, family):
            return [{'host': '8.8.8.8'}, {'host': '127.0.0.1'}]

        async def close(self):
            pass

    resolver = PublicResolver()
    await resolver._resolver.close()
    resolver._resolver = FakeResolver()
    with pytest.raises(OSError):
        await resolver.resolve('example.com', 443)
    await resolver.close()


@pytest.mark.asyncio
async def test_gemini_service_uses_structured_output_and_parses_response():
    payload = AnalysisResult(match_score=70, summary='Some overlap', matched_keywords=['Dart'],
                             missing_keywords=['Docker'], tailored_bullets=['Built apps'],
                             cover_letter='Dear hiring team', cautions=[])
    generate = AsyncMock(return_value=SimpleNamespace(text=payload.model_dump_json()))
    service = AnalysisService('test-key', 'test-model')
    service._client = SimpleNamespace(aio=SimpleNamespace(models=SimpleNamespace(generate_content=generate)))
    result = await service.analyze('Resume text', 'Job text')
    assert result.match_score == 70
    args = generate.await_args.kwargs
    assert args['config'].response_mime_type == 'application/json'
    assert args['model'] == 'test-model'
    assert 'never invent' in args['contents']
