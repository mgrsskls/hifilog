"""Polite HTTP client.

The crawler speaks for hifilog. It must not be the reason that a small brand
pays for more bandwidth, and it must be easy for a site owner to identify and
to stop. Therefore:

  * The user agent gives a name and a URL where the site owner can read what
    the crawler does and how to block it.
  * robots.txt is read one time for each host and is obeyed. A Crawl-delay
    value in robots.txt wins over the default delay.
  * One request at a time for each host, with a delay between requests.
  * Only GET, only HTTP and HTTPS, and a size limit for each response.
  * A failed request is tried again two times with an increasing delay.
    A 4xx answer is not tried again.

Standard library only, so that the tool runs on a server with no installation.
"""

from __future__ import annotations

import gzip
import random
import time
import urllib.error
import urllib.request
import urllib.robotparser
from dataclasses import dataclass
from typing import Optional
from urllib.parse import urlparse

from . import log

USER_AGENT = "hifilog-importer/0.1 (+https://hifilog.com/crawler; mail@hifilog.com)"
MAX_BYTES = 5 * 1024 * 1024
DEFAULT_DELAY = 2.0
TIMEOUT = 30


@dataclass
class Response:
    url: str
    status: Optional[int]
    content_type: Optional[str]
    text: Optional[str]
    error: Optional[str] = None


class Fetcher:
    def __init__(self, delay: float = DEFAULT_DELAY, obey_robots: bool = True):
        self.delay = delay
        self.obey_robots = obey_robots
        self._robots: dict = {}
        self._last_request: dict = {}
        self.refused_by_robots = 0

    # -- robots ---------------------------------------------------------

    def robots_for(self, url: str) -> urllib.robotparser.RobotFileParser:
        host = _host_key(url)
        if host not in self._robots:
            parser = urllib.robotparser.RobotFileParser()
            robots_url = f"{host}/robots.txt"
            response = self._request(robots_url)
            if response.text and response.status == 200:
                parser.parse(response.text.splitlines())
                log.detail(f"robots.txt read from {host}")
            else:
                # No robots.txt means no restriction. An error is treated the
                # same way, because a site that does not answer for robots.txt
                # will also not answer for its pages.
                parser.parse([])
            parser.set_url(robots_url)
            self._robots[host] = parser
        return self._robots[host]

    def allowed(self, url: str) -> bool:
        if not self.obey_robots:
            return True
        return self.robots_for(url).can_fetch(USER_AGENT, url)

    def sitemaps_from_robots(self, url: str) -> list:
        maps = self.robots_for(url).site_maps()
        return list(maps) if maps else []

    def delay_for(self, url: str) -> float:
        if not self.obey_robots:
            return self.delay
        stated = self.robots_for(url).crawl_delay(USER_AGENT)
        return max(self.delay, float(stated)) if stated else self.delay

    # -- fetching -------------------------------------------------------

    def get(self, url: str) -> Response:
        scheme = urlparse(url).scheme
        if scheme not in ("http", "https"):
            return Response(url, None, None, None, error=f"unsupported scheme {scheme!r}")
        if not self.allowed(url):
            # Not an error. It is the site saying no, and the operator should see
            # it without having to switch on --verbose: a robots rule that hides
            # the whole product path explains an empty result for a brand.
            log.detail(f"robots.txt refuses {url}")
            self.refused_by_robots += 1
            return Response(url, None, None, None, error="disallowed by robots.txt")
        self._wait(url)
        started = time.time()
        response = self._request(url, retries=2)
        took = time.time() - started
        if response.error:
            log.detail(f"{url} -> {response.error}")
        else:
            size = len(response.text or "")
            log.detail(f"{url} -> {response.status} {size // 1024}kB {took:.1f}s")
        return response

    def _wait(self, url: str) -> None:
        host = _host_key(url)
        wait_until = self._last_request.get(host, 0) + self.delay_for(url)
        now = time.time()
        if now < wait_until:
            time.sleep(wait_until - now)
        self._last_request[host] = time.time()

    def _request(self, url: str, retries: int = 0) -> Response:
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": USER_AGENT,
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Encoding": "gzip",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                raw = response.read(MAX_BYTES + 1)
                if len(raw) > MAX_BYTES:
                    return Response(url, response.status, None, None, error="too large")
                if response.headers.get("Content-Encoding") == "gzip":
                    raw = gzip.decompress(raw)
                if url.endswith(".gz"):
                    try:
                        raw = gzip.decompress(raw)
                    except OSError:
                        pass
                charset = response.headers.get_content_charset() or "utf-8"
                return Response(
                    url=response.geturl(),
                    status=response.status,
                    content_type=response.headers.get("Content-Type"),
                    text=raw.decode(charset, "replace"),
                )
        except urllib.error.HTTPError as error:
            # 4xx is an answer, not a fault. Do not ask again.
            if error.code < 500 or retries <= 0:
                return Response(url, error.code, None, None, error=f"HTTP {error.code}")
        except Exception as error:  # network level
            if retries <= 0:
                return Response(url, None, None, None, error=str(error))
        time.sleep(self.delay * (3 - retries) + random.random())
        return self._request(url, retries - 1)


def _host_key(url: str) -> str:
    parts = urlparse(url)
    return f"{parts.scheme}://{parts.netloc}"
