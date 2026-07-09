"""Navigation loop: read the root index.md, let Claude choose concepts to
open one at a time via the open_concept tool, and answer once it stops
calling the tool. Mirrors the loop in the Ballerina agent's main.bal.
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, SystemMessage

from anthropic_client import SYSTEM_PROMPT, BundleNavigator, build_open_concept_tool, model
from config import BUNDLE_ROOT_PATH, MAX_NAVIGATION_STEPS

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)


def extract_text(content: str | list) -> str:
    """AIMessage.content is either a plain string or a list of content
    blocks (e.g. when the model also returns a thinking block) -- normalize
    both shapes down to the answer's text."""
    if isinstance(content, str):
        return content
    parts = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text":
            parts.append(block.get("text", ""))
    return "".join(parts)


def run(question: str, bundle_root_path: str) -> str:
    navigator = BundleNavigator(bundle_root_path)
    root_index_content = navigator.read_root_index()

    open_concept_tool = build_open_concept_tool(navigator)
    model_with_tools = model.bind_tools([open_concept_tool])

    initial_user_content = (
        f"Question: {question}\n\n"
        f"Root index of the knowledge bundle (index.md):\n\n{root_index_content}"
    )
    messages: list[BaseMessage] = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=initial_user_content),
    ]

    for _ in range(MAX_NAVIGATION_STEPS):
        ai_message: AIMessage = model_with_tools.invoke(messages)
        messages.append(ai_message)

        if not ai_message.tool_calls:
            return extract_text(ai_message.content)

        for tool_call in ai_message.tool_calls:
            tool_message = open_concept_tool.invoke(tool_call)
            messages.append(tool_message)

    logger.warning("reached navigation step limit, forcing a final answer")
    messages.append(
        HumanMessage(
            content="You've reached the exploration limit. Answer now using what you've read so far."
        )
    )
    final_message: AIMessage = model.invoke(messages)
    return extract_text(final_message.content)


def main() -> None:
    question = sys.argv[1] if len(sys.argv) > 1 else input("Question: ").strip()
    if not question:
        sys.exit("No question provided.")

    if not (Path(BUNDLE_ROOT_PATH) / "index.md").exists():
        sys.exit(f"No index.md found at bundle root: {BUNDLE_ROOT_PATH}")

    answer = run(question, BUNDLE_ROOT_PATH)
    print(answer)


if __name__ == "__main__":
    main()
