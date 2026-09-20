"""What the operator sees while the pipeline runs.

A crawl over 600 brands runs for hours. During that time the only question that
matters is whether it is doing something useful, and the answer must not need a
database query. Therefore every stage says what it does, how fast, and what it
refused.

Three rules keep the output readable:

  * Everything goes to stderr. stdout stays free, so `... report > file` and a
    pipe still work while the log is on the screen.
  * One line for each brand, not one line for each page. A page line appears
    only with --verbose. A long step prints a progress line at intervals, which
    replaces itself on a terminal and is written as a new line in a log file.
  * Every refusal is counted, and the counts are printed at the end. "3000
    pages" says nothing; "2874 products, 126 refused: 98 not a product page, 28
    without a name" says where the next hour of work is.

Colour is used only on a terminal. A redirected log holds no escape characters.
"""

from __future__ import annotations

import sys
import time
from collections import Counter
from typing import Optional

_COLOURS = {
    "reset": "\033[0m", "dim": "\033[2m", "bold": "\033[1m",
    "green": "\033[32m", "yellow": "\033[33m", "red": "\033[31m",
    "blue": "\033[34m",
}

VERBOSE = False
QUIET = False
_START = time.time()


def configure(verbose: bool = False, quiet: bool = False) -> None:
    global VERBOSE, QUIET, _START
    VERBOSE, QUIET = verbose, quiet
    _START = time.time()


def _tty() -> bool:
    return sys.stderr.isatty()


def paint(text: str, colour: str) -> str:
    if not _tty():
        return text
    return f"{_COLOURS.get(colour, '')}{text}{_COLOURS['reset']}"


def elapsed() -> str:
    seconds = int(time.time() - _START)
    return f"{seconds // 3600:d}:{seconds // 60 % 60:02d}:{seconds % 60:02d}"


def _write(line: str) -> None:
    # A progress line may be standing on this line. Clear it first, so that a
    # short line does not leave the tail of a long one behind it.
    if _tty():
        sys.stderr.write("\r\033[K")
    sys.stderr.write(line + "\n")
    sys.stderr.flush()


def info(message: str) -> None:
    if not QUIET:
        _write(f"{paint(elapsed(), 'dim')} {message}")


def step(message: str) -> None:
    """A stage or a brand begins."""
    if not QUIET:
        _write(f"{paint(elapsed(), 'dim')} {paint(message, 'bold')}")


def detail(message: str) -> None:
    """One page, one URL, one answer. Only with --verbose."""
    if VERBOSE and not QUIET:
        _write(f"{paint(elapsed(), 'dim')} {paint('  ' + message, 'dim')}")


def warn(message: str) -> None:
    _write(f"{paint(elapsed(), 'dim')} {paint('warning', 'yellow')} {message}")


def error(message: str) -> None:
    _write(f"{paint(elapsed(), 'dim')} {paint('error', 'red')} {message}")


def ok(message: str) -> None:
    if not QUIET:
        _write(f"{paint(elapsed(), 'dim')} {paint('ok', 'green')} {message}")


class Progress:
    """A counter that reports itself while a long step runs.

    On a terminal the line replaces itself, so the log does not scroll away. In
    a file each report is its own line, because a file has no cursor. The rate
    and the remaining time are measured, not estimated from a plan: a crawl runs
    at the speed that the slowest site allows.
    """

    def __init__(self, label: str, total: Optional[int] = None, every: float = 2.0):
        self.label = label
        self.total = total
        self.every = every
        self.done = 0
        self.counts: Counter = Counter()
        self.started = time.time()
        self._last_report = 0.0

    def add(self, outcome: str = "ok", amount: int = 1) -> None:
        self.done += amount
        self.counts[outcome] += amount
        if time.time() - self._last_report >= self.every:
            self.report()

    def report(self) -> None:
        if QUIET:
            return
        self._last_report = time.time()
        seconds = max(time.time() - self.started, 0.001)
        rate = self.done / seconds
        text = f"{self.label}: {self.done}"
        if self.total:
            text += f"/{self.total}"
            if rate > 0 and self.done < self.total:
                remaining = int((self.total - self.done) / rate)
                text += f", {remaining // 60}m{remaining % 60:02d}s left"
        text += f", {rate:.1f}/s"
        refused = sum(count for name, count in self.counts.items() if name != "ok")
        if refused:
            text += f", {refused} refused"
        if _tty():
            sys.stderr.write("\r\033[K" + paint(elapsed(), "dim") + " " + text)
            sys.stderr.flush()
        else:
            _write(f"{paint(elapsed(), 'dim')} {text}")

    def finish(self) -> None:
        if QUIET:
            return
        seconds = max(time.time() - self.started, 0.001)
        parts = [f"{self.counts.get('ok', 0)} ok"]
        parts += [
            f"{count} {name}" for name, count in sorted(self.counts.items())
            if name != "ok"
        ]
        _write(
            f"{paint(elapsed(), 'dim')} {paint('ok', 'green')} {self.label}: "
            f"{', '.join(parts)} in {seconds:.0f}s"
        )


def summary(title: str, rows: dict) -> None:
    """The table at the end of a stage. Names are aligned, numbers are right."""
    if QUIET or not rows:
        return
    width = max(len(str(name)) for name in rows)
    _write("")
    _write(paint(title, "bold"))
    for name, value in rows.items():
        _write(f"  {str(name).ljust(width)}  {paint(str(value), 'blue')}")
    _write("")
