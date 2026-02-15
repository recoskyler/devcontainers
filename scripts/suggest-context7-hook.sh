#!/bin/bash
# PreToolUse hook for WebSearch: force-suggests using Context7 MCP for documentation queries.
# Registered by init-claude-mcp.sh when CONTEXT7_API_KEY is set.

echo "IMPORTANT: Context7 MCP is configured and available. For ANY queries about programming libraries, frameworks, APIs, or documentation, you MUST use mcp__context7__resolve-library-id followed by mcp__context7__query-docs INSTEAD of WebSearch. Reserve WebSearch for non-documentation needs only (current events, news, general knowledge). A MCP for the programming library, framework, API, or documentation you are searching for might also be configured and available. Discover the MCPs to check, and try the thing-specific MCP before context7 MCP."
exit 0
