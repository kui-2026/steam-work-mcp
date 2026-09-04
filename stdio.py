"""Run steam-mcp over stdio for the OpenAI secure tunnel client."""

from app import _load_env_file


_load_env_file()

from steam_mcp.server import mcp  # noqa: E402


if __name__ == "__main__":
    mcp.run()
