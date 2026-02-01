---
author: Sanath Samarasinghe
pubDatetime: 2026-02-01T00:00:00Z
modDatetime:
title: How OpenClaw Gives AI Agents Persistent Memory With Plain Markdown
featured: false
draft: false
tags:
  - ai
  - openclaw
  - development
  - tools
description: A deep dive into how OpenClaw's file-based memory system gives AI assistants genuine continuity between sessions using Markdown files, semantic search, and automatic memory flush.
---

You know how AI assistants sometimes feel like they have amnesia? You have this great conversation, close the tab, come back later and it's like talking to a stranger. OpenClaw solves this in a way that's surprisingly elegant - plain Markdown files on disk.

So here's the thing - most AI memory systems try to get clever with databases, vector stores, or some kind of external brain. OpenClaw takes a completely different approach. Your agent's memory is just files. Markdown files sitting in a workspace directory that you can open, read, edit, and version control like any other code.

And yeah, it actually works really well. Let me break down how.

## Table of contents

## The Memory Architecture

The entire memory system lives in `~/.openclaw/workspace/` and it's built around a small set of files that each serve a distinct purpose:

| File | Purpose |
|------|---------|
| `memory/YYYY-MM-DD.md` | Daily append-only logs - raw notes from each day |
| `MEMORY.md` | Curated long-term memory - the distilled knowledge |
| `AGENTS.md` | Operating instructions loaded every session |
| `SOUL.md` | Persona and tone definition |
| `TOOLS.md` | Tool conventions and local notes |

At the start of every session the agent reads today's and yesterday's daily notes plus AGENTS.md and SOUL.md. That's how it "remembers" who it is, who you are, and what happened recently.

The important distinction here is between daily notes and long-term memory. `memory/YYYY-MM-DD.md` files are raw logs - things that happened, decisions made, tasks completed. `MEMORY.md` is the curated version - think of it like the difference between your journal and your actual mental model of the world.

## How the Agent Evolves

This is where it gets interesting. The agent doesn't modify its own code - it evolves through deliberate file writing. Here's the feedback loop:

1. **Lesson learned?** - Update `AGENTS.md`, `TOOLS.md`, or a skill file
2. **Important fact?** - Write to `memory/YYYY-MM-DD.md` or `MEMORY.md`
3. **Mistake made?** - Document it so future sessions don't repeat it

These files get loaded into context at the start of every session, creating a genuine feedback loop of accumulated knowledge. Over time, during heartbeat cycles, the agent reviews recent daily files, distills what's worth keeping, and updates MEMORY.md.

It's basically journaling. The agent journals.

## Automatic Memory Flush - The Safety Net

Here's what happens when a session gets long. Context windows have limits and when you're approaching that limit, you lose older messages through compaction (summarization of old context). That means potentially important information could get lost.

OpenClaw handles this with an automatic memory flush that runs right before compaction kicks in:

1. Session token count crosses the soft threshold (default: 4000 tokens before the limit)
2. A silent system prompt fires: "Session nearing compaction. Store durable memories now."
3. The agent writes important context to `memory/YYYY-MM-DD.md`
4. The reply is suppressed with `NO_REPLY` so you never see any of this
5. Then compaction summarizes the older messages

The config for this looks like:

```json
{
  "agents": {
    "defaults": {
      "compaction": {
        "reserveTokensFloor": 20000,
        "memoryFlush": {
          "enabled": true,
          "softThresholdTokens": 4000
        }
      }
    }
  }
}
```

One flush per compaction cycle, tracked automatically. If the workspace is read-only, it skips the flush entirely. Clean and predictable.

## Semantic Memory Search - Finding What Matters

Okay so here's where the technical depth kicks in. Having files is great but finding the right information across weeks or months of notes? That's where the vector search comes in.

OpenClaw builds a hybrid search index over all memory files - combining BM25 keyword search with vector similarity search. The agent gets two tools:

- **`memory_search(query)`** - Hybrid semantic + keyword search
- **`memory_get(path, from, lines)`** - Read specific sections after finding them

Before answering questions about prior work, decisions, or preferences, the agent searches memory first. It's baked into the instructions.

### The Search Pipeline

Here's what happens when the agent searches its memory:

```
User Query
    |
    +-- Embed query (OpenAI / Gemini / Local)
    |
    +-- Keyword Search (FTS5 BM25)
    |     - Tokenize: extract words
    |     - Query SQLite FTS5 table
    |     - Score: 1 / (1 + rank)
    |
    +-- Vector Search (sqlite-vec or JS fallback)
    |     - Cosine similarity against all chunks
    |     - Score: 1 - distance
    |
    +-- Merge Results
    |     - Weighted: 0.7 * vectorScore + 0.3 * textScore
    |     - Sort descending
    |
    +-- Filter & Return
          - score >= 0.35 (minimum threshold)
          - Top 6 results (default)
```

The hybrid approach is smart. Pure vector search can miss exact terms. Pure keyword search misses semantically related concepts. The 70/30 weighted combination catches both.

### How Indexing Works

Memory files get chunked into segments of about 400 tokens with 80 tokens of overlap between chunks. Each chunk gets:

1. A SHA-256 hash (for dedup and cache lookup)
2. An embedding vector from your chosen provider
3. Stored in SQLite with both a vector table (sqlite-vec) and a full-text search table (FTS5)

The embedding cache is key here - unchanged chunks keep their embeddings across reindexes. Change your embedding provider? Full reindex, but it's atomic - temp DB, migrate, swap. No corruption on failures.

### Embedding Provider Options

OpenClaw auto-selects the best available provider:

1. **Local** - node-llama-cpp with a ~600MB model file (fully offline)
2. **OpenAI** - `text-embedding-3-small` (fast, cheap)
3. **Gemini** - `gemini-embedding-001`

Both OpenAI and Gemini support batch APIs for large reindexes so you're not hammering the API one chunk at a time.

### File Watching

Changes to memory files trigger reindexing automatically with a 1.5 second debounce. Session transcripts can optionally be indexed too (experimental) with delta thresholds of 100KB or 50 messages before reindexing.

## Session Persistence

Beyond the memory files, sessions themselves are persisted:

- **`sessions.json`** - Metadata like token counts, model overrides, compaction counts
- **`<sessionId>.jsonl`** - Full conversation transcripts in append-only format

The Gateway is the source of truth for all session state. Group chats, DMs, and slash commands each get their own session, so context stays separated.

## Why This Approach Works

The elegance here is in the simplicity. Your AI agent's entire memory is:

- **Inspectable** - it's just Markdown files, open them in any editor
- **Version controllable** - git track your agent's evolution
- **Editable** - fix a wrong memory by editing a file
- **Portable** - move the workspace folder, your agent comes with it
- **Private** - everything stays on your machine

No proprietary database. No cloud dependency for memory. No opaque embeddings-only store where you can't see what the agent "knows."

And the automatic memory flush means you don't have to worry about context compaction destroying important information. The agent handles it silently.

## What's Coming Next

There's research work happening on Memory v2 that includes some interesting ideas:

- **Entity-centric memory** - dedicated files per person/project (`bank/entities/Peter.md`)
- **Opinion confidence tracking** - the agent knows how sure it is about things
- **Temporal queries** - "what was true in November 2025?"
- **Narrative fact extraction** - self-contained context in each memory entry

None of this is implemented yet, but the direction is clear - more structured memory that's still grounded in readable files.

## Getting Started

If you're running OpenClaw, memory is already working out of the box. But here are a few things to know:

**Memory search needs an embedding provider.** Either set up a local model, or make sure you have an OpenAI or Gemini API key available.

**Tell your agent to remember things.** Explicitly say "remember this" or "write this down" and it'll update the memory files.

**Review MEMORY.md periodically.** Your agent should be doing this during heartbeats, but it helps to check what your agent actually remembers.

**Extra paths for indexing:**

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "extraPaths": ["../team-docs", "/srv/shared-notes/"]
      }
    }
  }
}
```

The whole thing is refreshingly transparent. Your AI agent's memory isn't some black box - it's a folder of Markdown files with a search index on top. And honestly, that's probably how it should be.

ciao
