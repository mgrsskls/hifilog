"""Raw document store.

Every page that the crawler gets is kept here, unchanged. Extraction always reads
from this store and never from the network. This has three effects:

  * You can change the extraction rules and run them again on the same pages.
    A better prompt or a new field does not need a second crawl.
  * A crawl can stop and start again. Pages that are already in the store are
    not requested a second time.
  * Each candidate field can point to the exact document that gave the value.

SQLite is sufficient. One brand gives some hundred pages, and 600 brands give a
file of some gigabytes. If the store becomes too large, move the body column to
files on disk. The interface stays the same.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Optional

SCHEMA = """
CREATE TABLE IF NOT EXISTS documents (
  url           TEXT PRIMARY KEY,
  brand_slug    TEXT NOT NULL,
  kind          TEXT NOT NULL,            -- robots | sitemap | page
  status        INTEGER,
  content_type  TEXT,
  body          TEXT,
  sha256        TEXT,
  fetched_at    REAL NOT NULL,
  error         TEXT
);
CREATE INDEX IF NOT EXISTS documents_brand_kind ON documents (brand_slug, kind);
CREATE INDEX IF NOT EXISTS documents_sha ON documents (sha256);

-- What was already extracted, and from which exact version of which document.
--
-- Extraction is repeated often: every rule that gets better is a reason to run
-- it again. Repeating the *work* is not. A page that has not changed, read by
-- the same rules, gives the same candidates, so the answer is kept and the work
-- is skipped. With a language model in the path this is not a saving in time
-- but in money: re-extracting 11000 pages that nobody changed would be paid for
-- twice.
--
-- The key holds the document digest and the version of the extractor, so a
-- changed page and a changed rule both invalidate by themselves. Nothing has to
-- be cleared by hand.
CREATE TABLE IF NOT EXISTS extractions (
  cache_key   TEXT PRIMARY KEY,
  url         TEXT NOT NULL,
  brand_slug  TEXT NOT NULL,
  candidates  TEXT NOT NULL,          -- a JSON array of candidate objects
  created_at  REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS extractions_brand ON extractions (brand_slug);
"""


@dataclass
class Document:
    url: str
    brand_slug: str
    kind: str
    status: Optional[int]
    content_type: Optional[str]
    body: Optional[str]
    sha256: Optional[str]
    fetched_at: float
    error: Optional[str] = None

    @property
    def ok(self) -> bool:
        return self.status == 200 and bool(self.body)


class FileCache:
    """The extraction cache as a plain file rather than as a table.

    SQLite needs file locks, and some file systems do not give them: a folder
    reached over a network or a container mount answers every write with "disk
    I/O error" while ordinary files are written happily. On such a mount the
    whole pipeline is unusable for the one reason that its cache is a table.

    So the cache can be a JSONL file instead. One line per document: the key,
    and the candidates that were read from it. It is appended to as the run goes
    -- a run that is stopped keeps what it found -- and read into memory once at
    the start, which for a catalogue of this size is some tens of megabytes.

    It also makes the cache readable. A question like "what did the extractor
    make of this page last time" is answered with grep.
    """

    def __init__(self, path: Path):
        self.path = path
        self.entries: dict = {}
        if path.exists():
            with open(path, "r", encoding="utf-8") as handle:
                for line in handle:
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if "key" in row:
                        self.entries[row["key"]] = row.get("candidates", [])
        path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = open(path, "a", encoding="utf-8")

    def get(self, key: str):
        return self.entries.get(key)

    def put(self, key: str, url: str, brand_slug: str, candidates: list) -> None:
        self.entries[key] = candidates
        self.handle.write(
            json.dumps(
                {"key": key, "url": url, "brand_slug": brand_slug, "candidates": candidates},
                ensure_ascii=False,
            )
            + "\n"
        )

    def commit(self) -> None:
        self.handle.flush()

    def clear(self, brand_slug: Optional[str] = None) -> int:
        """Forget everything, or one brand. Rewrites the file."""
        self.handle.close()
        if brand_slug is None:
            removed = len(self.entries)
            self.entries = {}
            self.path.write_text("")
        else:
            kept = []
            removed = 0
            with open(self.path, "r", encoding="utf-8") as handle:
                for line in handle:
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if row.get("brand_slug") == brand_slug:
                        removed += 1
                        self.entries.pop(row.get("key"), None)
                    else:
                        kept.append(line.rstrip("\n"))
            self.path.write_text("\n".join(kept) + ("\n" if kept else ""))
        self.handle = open(self.path, "a", encoding="utf-8")
        return removed


class DocumentStore:
    def __init__(self, path: Path, read_only: bool = False, cache: Optional[FileCache] = None):
        # read_only exists for the same reason FileCache does: the store can be
        # read over a mount that refuses the locks a write needs. Reading 8.7 GB
        # of stored pages works there; writing one row does not.
        self.read_only = read_only
        self.cache = cache
        if read_only:
            self.conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            self.conn.row_factory = sqlite3.Row
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(path))
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(SCHEMA)
        self.conn.commit()

    def has(self, url: str) -> bool:
        row = self.conn.execute(
            "SELECT 1 FROM documents WHERE url = ?", (url,)
        ).fetchone()
        return row is not None

    def get(self, url: str) -> Optional[Document]:
        row = self.conn.execute(
            "SELECT * FROM documents WHERE url = ?", (url,)
        ).fetchone()
        return _row_to_document(row) if row else None

    def put(
        self,
        url: str,
        brand_slug: str,
        kind: str,
        status: Optional[int],
        content_type: Optional[str],
        body: Optional[str],
        error: Optional[str] = None,
    ) -> Document:
        digest = (
            hashlib.sha256(body.encode("utf-8", "replace")).hexdigest()
            if body
            else None
        )
        doc = Document(
            url=url,
            brand_slug=brand_slug,
            kind=kind,
            status=status,
            content_type=content_type,
            body=body,
            sha256=digest,
            fetched_at=time.time(),
            error=error,
        )
        self.conn.execute(
            "REPLACE INTO documents "
            "(url, brand_slug, kind, status, content_type, body, sha256, fetched_at, error) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                doc.url,
                doc.brand_slug,
                doc.kind,
                doc.status,
                doc.content_type,
                doc.body,
                doc.sha256,
                doc.fetched_at,
                doc.error,
            ),
        )
        self.conn.commit()
        return doc

    def pages(self, brand_slug: Optional[str] = None) -> Iterator[Document]:
        if brand_slug:
            rows = self.conn.execute(
                "SELECT * FROM documents WHERE kind = 'page' AND brand_slug = ? ORDER BY url",
                (brand_slug,),
            )
        else:
            rows = self.conn.execute(
                "SELECT * FROM documents WHERE kind = 'page' ORDER BY brand_slug, url"
            )
        for row in rows:
            yield _row_to_document(row)

    def documents_of(self, kind: str, brand_slug: Optional[str] = None) -> Iterator[Document]:
        """Every stored document of one kind: home, sitemap, page, json, catalog."""
        if brand_slug:
            rows = self.conn.execute(
                "SELECT * FROM documents WHERE kind = ? AND brand_slug = ? ORDER BY url",
                (kind, brand_slug),
            )
        else:
            rows = self.conn.execute(
                "SELECT * FROM documents WHERE kind = ? ORDER BY brand_slug, url", (kind,)
            )
        for row in rows:
            yield _row_to_document(row)

    # -- extraction cache ------------------------------------------------

    def extraction_key(self, document: Document, extractor_version: str, mode: str) -> str:
        """One key for: this document, as it was, read by these rules."""
        raw = f"{document.url}|{document.sha256}|{extractor_version}|{mode}"
        return hashlib.sha256(raw.encode()).hexdigest()

    def cached_extraction(self, key: str) -> Optional[list]:
        if self.cache is not None:
            return self.cache.get(key)
        row = self.conn.execute(
            "SELECT candidates FROM extractions WHERE cache_key = ?", (key,)
        ).fetchone()
        if not row:
            return None
        try:
            return json.loads(row["candidates"])
        except json.JSONDecodeError:
            return None

    def remember_extraction(self, key: str, document: Document, candidates: list) -> None:
        if self.cache is not None:
            self.cache.put(key, document.url, document.brand_slug, candidates)
            return
        if self.read_only:
            return
        self.conn.execute(
            "REPLACE INTO extractions (cache_key, url, brand_slug, candidates, created_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (key, document.url, document.brand_slug, json.dumps(candidates), time.time()),
        )

    def commit(self) -> None:
        if self.cache is not None:
            self.cache.commit()
        if not self.read_only:
            self.conn.commit()

    def forget_extractions(self, brand_slug: Optional[str] = None) -> int:
        if self.cache is not None:
            return self.cache.clear(brand_slug)
        if self.read_only:
            return 0
        if brand_slug:
            cursor = self.conn.execute(
                "DELETE FROM extractions WHERE brand_slug = ?", (brand_slug,)
            )
        else:
            cursor = self.conn.execute("DELETE FROM extractions")
        self.conn.commit()
        return cursor.rowcount

    def page_index(self, brand_slug: Optional[str] = None) -> list:
        """(brand_slug, url) for every stored page, without the pages.

        The URL rules are decided before anything is read, and deciding them
        must not carry the documents. One brand's pages can be several hundred
        megabytes: a Wix page is often more than a megabyte of HTML.
        """
        if brand_slug:
            rows = self.conn.execute(
                "SELECT brand_slug, url FROM documents WHERE kind = 'page' AND brand_slug = ?",
                (brand_slug,),
            )
        else:
            rows = self.conn.execute("SELECT brand_slug, url FROM documents WHERE kind = 'page'")
        return [(row["brand_slug"], row["url"]) for row in rows]

    def count_pages(self, brand_slug: Optional[str] = None) -> int:
        if brand_slug:
            row = self.conn.execute(
                "SELECT COUNT(*) FROM documents WHERE kind = 'page' AND brand_slug = ?",
                (brand_slug,),
            ).fetchone()
        else:
            row = self.conn.execute(
                "SELECT COUNT(*) FROM documents WHERE kind = 'page'"
            ).fetchone()
        return row[0]

    def counts(self) -> dict:
        rows = self.conn.execute(
            "SELECT brand_slug, kind, COUNT(*) AS n FROM documents GROUP BY brand_slug, kind"
        )
        out: dict = {}
        for row in rows:
            out.setdefault(row["brand_slug"], {})[row["kind"]] = row["n"]
        return out


def _row_to_document(row: sqlite3.Row) -> Document:
    return Document(
        url=row["url"],
        brand_slug=row["brand_slug"],
        kind=row["kind"],
        status=row["status"],
        content_type=row["content_type"],
        body=row["body"],
        sha256=row["sha256"],
        fetched_at=row["fetched_at"],
        error=row["error"],
    )
