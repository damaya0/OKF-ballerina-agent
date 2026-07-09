"""Resolves and reads links within an OKF bundle, mirroring the link rules in
okf/SPEC.md section 5: a leading "/" is bundle-root-relative, anything else
is relative to the directory of the document currently being viewed.

Deliberately dependency-free (no LangChain imports) so this logic is reusable
independent of how it's invoked -- the same principle applied to the
Ballerina agent's bundle_nav.bal.
"""

from __future__ import annotations

from pathlib import Path


class OkfNavigationError(Exception):
    """Raised when a link can't be resolved within the bundle (e.g. it walks
    above the bundle root via too many '..' segments)."""


def _split_segments(path: str) -> list[str]:
    return [segment for segment in path.split("/") if segment]


def resolve_concept_link(current_dir: str, link: str) -> str:
    """Resolves a link found inside the document at `current_dir` to a
    bundle-relative path, e.g.
    resolve_concept_link("tables", "../datasets/index.md") -> "datasets/index.md".
    """
    trimmed_link = link.strip()
    is_absolute = trimmed_link.startswith("/")
    base_segments = [] if is_absolute else _split_segments(current_dir)
    link_body = trimmed_link[1:] if is_absolute else trimmed_link
    link_segments = _split_segments(link_body)

    stack = list(base_segments)
    for segment in link_segments:
        if segment == ".":
            continue
        elif segment == "..":
            if not stack:
                raise OkfNavigationError(f"link '{link}' escapes the bundle root")
            stack.pop()
        else:
            stack.append(segment)

    relative_path = "/".join(stack)
    if not relative_path.endswith(".md"):
        relative_path = f"{relative_path}/index.md" if relative_path else "index.md"
    return relative_path


def dirname_of(relative_file_path: str) -> str:
    if "/" not in relative_file_path:
        return ""
    return relative_file_path.rsplit("/", 1)[0]


def read_concept_file(bundle_root_path: str, relative_path: str) -> str:
    full_path = Path(bundle_root_path) / relative_path
    return full_path.read_text(encoding="utf-8")
