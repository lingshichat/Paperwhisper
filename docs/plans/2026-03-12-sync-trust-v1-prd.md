# Sync Trust V1 PRD

> **Goal:** Turn sync from a background feature into a trustworthy baseline capability with clear status, safe failure handling, and recoverable deletion.

**Status:** Draft for implementation  
**Date:** 2026-03-12  
**Target Release:** V1 by 2026-04-02, V1.1 by 2026-04-16  
**Product Scope:** PaperWhisper basic safety, trust, UX, and interaction for diary sync  
**Non-Goal:** This release is not about monetization and does not position sync as a paid differentiator.

---

## Background

Current sync behavior has three core product problems:

1. Users cannot reliably tell whether their content is actually safe.
2. Failure states are too transient and too technical, so users may think sync succeeded when it did not.
3. Delete and remote-cleanup behavior are not consistently recoverable, which is unacceptable for a diary product.

An audit on 2026-03-12 also found implementation risks around manifest consistency, false-success states, secret storage, and provider/service boundary violations. Product-wise, this means PaperWhisper is currently closer to "best effort sync" than "trusted personal archive."

The product direction for this PRD is clear:

- Do not optimize for monetization.
- Do not add more sync protocols or advanced features first.
- First make sync safe, understandable, and trustworthy.

---

## Product Principle

Sync is not a premium trick. It is part of the app's safety model.

For a diary app, users buy into two promises:

1. My writing will not silently disappear.
2. The app will not lie to me about whether it is safe.

Every product decision in this PRD should be evaluated against those two promises.

---

## Problem Statement

Today the product has these user-facing problems:

- After saving a diary or moment, users cannot clearly tell whether the content is only local or already synced.
- Failure feedback is mostly toast-based and temporary.
- "Auto sync" is not presented as a reliable, understandable user control.
- Users have no stable place to see sync health, pending changes, or last successful sync.
- Delete behavior is not consistently framed as recoverable archive behavior.
- There is no user-facing recovery flow for broken sync states.

---

## Goals

### Primary Goals

- Make sync state visible and trustworthy.
- Make sync failure visible, actionable, and non-destructive.
- Make deletion recoverable by default.
- Reduce user anxiety around "Did it actually sync?"

### Secondary Goals

- Improve progress and retry experience.
- Make settings easier to understand.
- Create a clean foundation for later conflict handling.

### Non-Goals

- No protocol expansion beyond current WebDAV and S3 support.
- No collaboration or shared diaries.
- No deep conflict editor in V1.
- No paywall or premium packaging work in this project.

---

## Target Users

- Users who write private diaries and care about data safety more than feature breadth.
- Users switching between devices who need confidence, not just connectivity.
- Users on unstable networks who need honest failure states and retry paths.

---

## V1 Scope

V1 focuses on three product outcomes:

1. **True Status**
   Users can always see the current sync state and whether content is actually safe.

2. **Safe Failure**
   Failed uploads, network interruptions, or permission problems must not be disguised as success.

3. **Recoverable Delete**
   Deleted content should go through recoverable archive behavior, not silent destructive cleanup.

---

## User-Facing Sync States

V1 must define and expose these states consistently:

- `Not Enabled`
- `Local Changes Pending`
- `Syncing`
- `Synced Successfully`
- `Sync Failed`
- `Needs Attention`

### State Definitions

**Not Enabled**
- User has not enabled sync.
- UI should show setup guidance, not failure language.

**Local Changes Pending**
- There are unsynced local changes.
- UI should show pending count and available action.

**Syncing**
- Sync is actively running.
- UI should show stable progress text and non-misleading indicators.

**Synced Successfully**
- Latest known local changes have been confirmed synced.
- UI should show last successful sync time.

**Sync Failed**
- A sync attempt failed and local changes may still be pending.
- UI should show short human-readable reason plus retry entry.

**Needs Attention**
- Sync configuration is invalid, remote data is inconsistent, or there is a recoverable data issue that needs explicit user action.

---

## Core User Stories

### Story 1: Save with Confidence

As a user, after I save a diary or moment, I want to know whether it is only local or already safe in sync, so I do not have to guess.

### Story 2: Failure Without Panic

As a user, if sync fails, I want the app to clearly tell me that my content is still pending instead of falsely showing success.

### Story 3: Easy Recovery

As a user, if I delete something or sync cleanup happens, I want it to remain recoverable by default.

### Story 4: One Stable Place to Check

As a user, I want a stable sync status area where I can see health, pending changes, last success time, and retry actions.

---

## Functional Requirements

### FR1. Sync Status Surface

The app must provide a persistent sync status surface in the sync settings flow and any appropriate overview surface.

It must show:

- current state
- last successful sync time
- pending changes count
- current progress text while syncing
- failure summary when broken
- retry action when retry is possible

### FR2. Accurate Success Criteria

The product must only show successful sync when data and sync metadata are both in a confirmed-good state.

If uploads fail, the product must remain in `Local Changes Pending` or `Sync Failed`, not `Synced Successfully`.

### FR3. Auto Sync as Real User Control

The product must provide an explicit auto sync switch.

If auto sync is off:

- saving content must not silently trigger background sync
- UI should continue showing pending local changes

If auto sync is on:

- saving content should schedule sync according to product rules
- user should still be able to manually retry immediately

### FR4. Retry and Repair

When sync fails, the product must expose:

- retry now
- reason summary
- if configuration is invalid, go-to-settings action

V1 does not require a full repair center, but it must provide a visible path forward.

### FR5. Recoverable Delete

Delete behavior for synced diary-related content must default to recoverable archive semantics.

The product must never imply permanent deletion when the actual behavior is recoverable, and must not perform silent destructive cleanup that users cannot understand or recover from.

### FR6. Configuration Trust

The sync settings page must:

- clearly separate WebDAV and S3 configuration
- validate only fields that are truly required
- not mislabel optional fields as required
- distinguish setup problems from runtime sync problems

### FR7. Progress Feedback

When sync is running, the user must see stable progress feedback with:

- current action text
- progress indicator
- optional speed/ETA if available

Progress must not disappear immediately after a save if there are still unresolved pending changes.

### FR8. Pending Change Awareness

The product must track and expose whether local content is awaiting sync.

This includes:

- newly created diary entries
- edited diary entries
- deleted diary entries
- moments and related media where applicable in current sync scope

### FR9. Safe Secret Handling

Sync credentials are part of product trust.

The product must move away from plain-text credential persistence and align storage behavior with the product's privacy promise.

This is a V1 requirement even though it is not directly visible as a UI feature.

---

## UX Requirements

### UX1. Replace Toast-Only Mental Model

Important sync outcomes must not rely only on temporary toast notifications.

Toasts may assist, but the source of truth must remain visible on screen.

### UX2. Human-Readable Messaging

Messages should be short and user-safe.

Good examples:

- "尚有 3 条内容未同步"
- "最近一次成功同步：今天 14:32"
- "同步失败，内容仍保留在本地"
- "配置异常，请检查账号或服务器地址"

Avoid raw protocol language except where necessary.

### UX3. Anxiety Reduction

The product should always answer three questions quickly:

1. Is my content safe?
2. If not, what is pending?
3. What should I do next?

---

## Out of Scope for V1

These items are intentionally deferred to V1.1 or later:

- conflict resolution center
- version comparison UI
- sync history timeline
- cross-device merge inspector
- deep diagnostics panel for advanced users

---

## V1.1 Scope Preview

V1.1 will focus on conflict and repair:

- conflict detection
- conflict list
- choose local / choose remote / save as new copy
- repair entry point
- simple sync history summary

V1.1 should start only after V1 is stable and truthful.

---

## Acceptance Criteria

V1 is complete only when all of the following are true:

- Users can see a stable sync state without relying only on toast notifications.
- The app no longer shows success after partial or failed upload behavior.
- Auto sync can be explicitly enabled or disabled by the user and behaves accordingly.
- Failed sync leaves content in a visible pending state.
- Delete behavior is recoverable by default across the supported synced content path.
- The sync settings flow clearly distinguishes setup, syncing, success, and failure.
- Optional configuration fields are not blocked by required-field validation.
- The app shows last successful sync time and pending change awareness.
- Credential handling is aligned with the product's privacy and trust promise.

---

## Milestones and Schedule

### Phase 1: Product Definition and State Model

**Dates:** 2026-03-12 to 2026-03-15

Deliverables:

- final sync state model
- user-facing copy
- information architecture for sync status and settings
- implementation checklist and acceptance cases

### Phase 2: Safety and Correctness Foundation

**Dates:** 2026-03-16 to 2026-03-22

Deliverables:

- manifest consistency hardening
- no false-success sync outcome
- real auto sync control behavior
- recoverable delete alignment
- pending-state correctness after failures
- safer credential storage approach

### Phase 3: Trustworthy User Experience

**Dates:** 2026-03-23 to 2026-03-29

Deliverables:

- persistent sync status UI
- retry actions
- visible last success time
- pending changes display
- better progress interaction
- clearer setup and error messaging

### Phase 4: QA and Release Hardening

**Dates:** 2026-03-30 to 2026-04-02

Deliverables:

- Android and Windows regression pass
- unstable network scenarios
- permission denial scenarios
- repeat save / sync interruption checks
- delete and recovery checks

### Phase 5: V1.1 Conflict and Repair

**Dates:** 2026-04-03 to 2026-04-16

Deliverables:

- conflict visibility
- conflict resolution actions
- repair flow
- simple sync history

---

## Release Decision Rule

Do not ship V1 if any of these remain true:

- sync can still report success after upload failure
- users cannot see whether there are local pending changes
- delete behavior is still destructively unclear
- credential handling still contradicts the product's privacy promise

---

## Implementation Notes for Next Session

Recommended execution order:

1. fix sync truth model and manifest consistency
2. make auto sync a real setting
3. expose pending/success/failure state in UI
4. align delete behavior with recoverable archive semantics
5. finish validation, copy, and cross-platform QA

Suggested implementation rule:

- Treat this PRD as the source of truth for V1.
- Prefer trust and recoverability over clever automation.
- If a design choice hides uncertainty from the user, reject it.
