import ipaddress
import socket
import ssl
from urllib.parse import urljoin, urlsplit

import aiohttp
import certifi
from aiohttp.abc import AbstractResolver
from bs4 import BeautifulSoup

MAX_JOB_BYTES = 1_000_000


class JobFetchError(ValueError):
    pass


def validate_url(url: str) -> None:
    try:
        parts = urlsplit(url)
        if parts.scheme not in ('https', 'http') or not parts.hostname or parts.username or parts.password:
            raise ValueError()
        if parts.port not in (None, 80, 443):
            raise ValueError()
        host = parts.hostname.lower().rstrip('.')
        if host == 'localhost' or host.endswith(('.localhost', '.local', '.internal')):
            raise ValueError()
        try:
            address = ipaddress.ip_address(host)
        except ValueError:
            address = None
        if address is not None and not address.is_global:
            raise ValueError()
    except ValueError as exc:
        raise JobFetchError('Use a public HTTP or HTTPS job posting URL.') from exc


class PublicResolver(AbstractResolver):
    """Resolve only public addresses and hand those exact addresses to aiohttp."""
    def __init__(self):
        self._resolver = aiohttp.resolver.ThreadedResolver()

    async def resolve(self, host, port=0, family=socket.AF_INET):
        results = await self._resolver.resolve(host, port, family)
        if not results or any(not ipaddress.ip_address(r['host']).is_global for r in results):
            raise OSError('Host resolves to a non-public address')
        return results

    async def close(self):
        await self._resolver.close()


async def fetch_job(url: str) -> str:
    timeout = aiohttp.ClientTimeout(total=20, connect=5)
    connector = aiohttp.TCPConnector(resolver=PublicResolver(), use_dns_cache=False,
                                     ssl=ssl.create_default_context(cafile=certifi.where()))
    try:
        async with aiohttp.ClientSession(timeout=timeout, connector=connector, trust_env=False,
                                         headers={'User-Agent': 'CareerBooster/1.0'}) as session:
            for _ in range(4):
                validate_url(url)
                async with session.get(url, allow_redirects=False) as response:
                    if response.status in (301, 302, 303, 307, 308):
                        location = response.headers.get('Location')
                        if not location:
                            raise JobFetchError('The job page returned an invalid redirect.')
                        url = urljoin(url, location)
                        continue
                    if response.status != 200:
                        raise JobFetchError('The job page could not be opened. Paste the job description instead.')
                    if response.content_type not in ('text/html', 'text/plain'):
                        raise JobFetchError('The job URL must point to a web page or plain text.')
                    data = bytearray()
                    async for chunk in response.content.iter_chunked(65536):
                        data.extend(chunk)
                        if len(data) > MAX_JOB_BYTES:
                            raise JobFetchError('The job page is too large. Paste the job description instead.')
                    page = data.decode(response.charset or 'utf-8', errors='replace')
                    soup = BeautifulSoup(page, 'html.parser')
                    for element in soup(['script', 'style', 'nav', 'footer', 'header']):
                        element.decompose()
                    text = ' '.join(soup.stripped_strings)
                    if len(text) < 80:
                        raise JobFetchError('Not enough job text was found. Paste the job description instead.')
                    return text[:30000]
            raise JobFetchError('The job page redirected too many times.')
    except JobFetchError:
        raise
    except (aiohttp.ClientError, TimeoutError, OSError, UnicodeError, LookupError) as exc:
        raise JobFetchError('The job page could not be opened. Paste the job description instead.') from exc
