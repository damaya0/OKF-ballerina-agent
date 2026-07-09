"""Anthropic model setup, the open_concept tool definition, and the
navigation state it operates on.

Pairs the tool's schema with its implementation in one file, mirroring
anthropic_client.bal in the Ballerina agent.
"""

from __future__ import annotations

import logging

from langchain_anthropic import ChatAnthropic
from langchain_core.tools import StructuredTool
from pydantic import BaseModel, Field

from bundle_nav import OkfNavigationError, dirname_of, read_concept_file, resolve_concept_link
from config import ANTHROPIC_API_KEY, ANTHROPIC_MODEL_NAME

logger = logging.getLogger(__name__)

MAX_TOKENS = 4096

model = ChatAnthropic(model=ANTHROPIC_MODEL_NAME, max_tokens=MAX_TOKENS, api_key=ANTHROPIC_API_KEY)

SYSTEM_PROMPT = (
    "You are a research agent that answers questions using a knowledge bundle "
    "written in the Open Knowledge Format (OKF): a directory tree of markdown "
    "files with YAML frontmatter, cross-linked by concept id (a relative or "
    "bundle-root-relative path, e.g. 'tables/users' -> 'tables/users.md').\n\n"
    "You do not have the whole bundle in context. You navigate it one concept "
    "at a time:\n"
    "- You are given the root index.md, which lists subdirectories and/or "
    "concepts with a short description of each.\n"
    "- Use the open_concept tool to open exactly one concept at a time -- copy "
    "the link/id verbatim from the markdown you are currently looking at (e.g. "
    "'datasets/index.md', '/tables/users.md', '../tables/index.md').\n"
    "- Directory index.md files exist purely for navigation -- they tell you "
    "what's available so you can decide where to look next. Concept files "
    "contain the schema/reference content you need to answer the question.\n"
    "- Keep opening concepts -- including ones referenced from inside a concept "
    "you already opened -- until you have enough concrete detail to answer "
    "accurately. Don't guess if the bundle has the specific answer.\n"
    "- If a link is broken, try a different one instead of giving up.\n"
    "- Don't over-explore: once you've found the concept(s) that answer the "
    "question, stop calling the tool and answer.\n\n"
    "When you have enough information, respond with plain text (no tool call). "
    "Answer the user's question directly and concisely, grounded in what you "
    "read, and mention which concept id(s) the answer came from."
)


class OpenConceptArgs(BaseModel):
    path: str = Field(
        description=(
            "The link path or concept id to open, copied exactly as it "
            "appears in the markdown you just read."
        )
    )


class BundleNavigator:
    """Tracks the directory of the most recently opened concept so relative
    links resolve correctly -- mirrors the `currentDir` loop variable in the
    Ballerina agent, just held as instance state instead of threaded through
    a pure function's parameters.
    """

    def __init__(self, bundle_root_path: str) -> None:
        self.bundle_root_path = bundle_root_path
        self.current_dir = ""

    def read_root_index(self) -> str:
        content = read_concept_file(self.bundle_root_path, "index.md")
        self.current_dir = dirname_of("index.md")
        return content

    def open_concept(self, path: str) -> str:
        # Broken links are expected (OKF tolerates them by design, see SPEC.md
        # section 5.3) -- report them back to the model as tool output instead
        # of raising, so it can try a different link. Note that LangChain's
        # `handle_tool_error` only intercepts its own ToolException, not
        # arbitrary exceptions like this one or FileNotFoundError, so we catch
        # here rather than relying on that.
        try:
            relative_path = resolve_concept_link(self.current_dir, path)
            content = read_concept_file(self.bundle_root_path, relative_path)
        except OkfNavigationError as e:
            logger.warning("failed to resolve link '%s': %s", path, e)
            return f"Error: {e}"
        except OSError as e:
            logger.warning("failed to open concept '%s': %s", path, e)
            return f"Error: no document at '{path}'"

        self.current_dir = dirname_of(relative_path)
        logger.info("opened concept: %s", relative_path)
        return content


def build_open_concept_tool(navigator: BundleNavigator) -> StructuredTool:
    return StructuredTool.from_function(
        func=navigator.open_concept,
        name="open_concept",
        description=(
            "Open a concept page in the OKF knowledge bundle by following a "
            "link/id copied verbatim from the document you're currently viewing "
            "(e.g. 'datasets/index.md', '/tables/users.md', '../tables/index.md')."
        ),
        args_schema=OpenConceptArgs,
        handle_tool_error=True,
    )
