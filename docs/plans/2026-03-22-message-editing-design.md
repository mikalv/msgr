# Message Editing

**Date:** 2026-03-22
**Status:** Approved

## Overview

Edit messages in-place with arrow-up shortcut and context menu. Bots ignore edits.

## Trigger
- **Arrow up** with empty composer → edit last own message
- **Context menu** → "Rediger" on any own message

## Composer Edit Mode
- Banner above composer: "Redigerer melding" with X to cancel
- Original message text loaded into composer
- Original message highlighted in chat (subtle border)
- Enter saves, Escape cancels (restores draft)

## Display
- `(redigert)` shown next to timestamp after edit
- `edited_at` stored in database

## Backend
- `PATCH /api/teams/:slug/channels/:channel_id/messages/:message_id`
- Body: `{ "content": { "text": "updated text" } }`
- Only message owner can edit (profile_id check)
- Sets `edited_at = now()`
- Broadcasts `message:edited` on `channel:{id}` topic

## Bot Behavior
- Bots ignore `message:edited` events
- Bot polling checks `inserted_at > last_seen`, so edits are invisible to bots
- No re-trigger, no loops

## Constraints
- Only own messages
- No time limit
- Text messages only (no media edits)
