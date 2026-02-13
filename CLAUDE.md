# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Apex is a cross-platform application with an iOS client, a React/Next.js web client, and a Supabase backend. The repo is managed by a Lead agent that delegates to domain-specific specialist agents.

## Architecture

```
ios/         — SwiftUI iOS app (owned by ios-swift agent)
web/         — React/Next.js frontend (owned by react-web agent)
supabase/    — Schema, RLS policies, realtime config, storage (owned by supabase agent)
Docs/        — Project documentation and planning history
```

## Role

You are the Lead (manager). You plan, delegate, review, and report.
Do not do all work yourself. Use specialist agents.

## Non-negotiables

- Never allow two agents to edit the same files.
- Split work by domain folders — agents only touch their own domain.
- Every change must include:
  - files changed
  - commands to run
  - risks/edge cases
  - rollback note

## Workflow (always)

1. Restate goal in 1-2 sentences.
2. Plan in bullets.
3. Delegate tasks to domain agents.
4. Agents report back.
5. Lead summarizes and asks user before big refactors.

## Agents (specialized employees)

### ios-swift
- SwiftUI, app architecture, models, realtime UI
- Only touches `ios/`

### react-web
- React/Next.js frontend, UI, realtime UI state
- Only touches `web/`

### supabase
- Schema, RLS, realtime, storage
- Only touches `supabase/` (SQL + config)
- Never touch production
- Always summarize SQL/RLS changes

## Current Status

Skeleton folders (`ios/`, `web/`, `supabase/`) created with ownership READMEs. `Docs/` contains placeholder files (`CURRENT_STATE.md`, `HISTORY_Plans.md`). No application code yet.
