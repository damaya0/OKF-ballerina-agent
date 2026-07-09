"""Loads runtime configuration from config.toml (gitignored -- see .gitignore),
mirroring the Ballerina agent's Config.toml.
"""

from __future__ import annotations

import tomllib
from pathlib import Path

_CONFIG_PATH = Path(__file__).resolve().parent / "config.toml"

_DEFAULT_BUNDLE_ROOT_PATH = str(
    Path(__file__).resolve().parent.parent
    / "knowledge-catalog" / "okf" / "bundles" / "stackoverflow"
)


def _load() -> dict:
    if not _CONFIG_PATH.exists():
        raise FileNotFoundError(
            f"Missing {_CONFIG_PATH}. Copy config.toml.example to config.toml "
            "and fill in your Anthropic API key."
        )
    with _CONFIG_PATH.open("rb") as config_file:
        return tomllib.load(config_file)


_config = _load()

ANTHROPIC_API_KEY: str = _config.get("anthropic_api_key", "")
if not ANTHROPIC_API_KEY:
    raise ValueError(f"'anthropic_api_key' is missing or empty in {_CONFIG_PATH}")

ANTHROPIC_MODEL_NAME: str = _config.get("anthropic_model_name", "claude-sonnet-5")
BUNDLE_ROOT_PATH: str = _config.get("bundle_root_path", _DEFAULT_BUNDLE_ROOT_PATH)
MAX_NAVIGATION_STEPS: int = _config.get("max_navigation_steps", 12)
