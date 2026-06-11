# Security Design Decisions

[日本語版はこちら](security-decisions.ja.md)

This document records security recommendations that were **reviewed and intentionally not adopted**, as well as a comprehensive list of **adopted security measures**. Its purpose is to prevent the same discussions from recurring in future reviews or contributions.

## Assumptions

ccskill-gmail is a **personal, local companion tool** that complements the standard Gmail connector available in Claude.ai and Codex. It is not a replacement for that connector, and it is not designed for organizational deployment or SaaS delivery. If any of these assumptions change, all decisions below should be re-evaluated.

## Design Principles

These are foundational constraints that shape the entire security model:

- **No send API** — Only draft creation is supported. Users review and send manually from Gmail. This eliminates the risk of AI-initiated unsolicited emails.
- **No permanent delete API** — Only `move_to_trash` is available, and it is denied by default via `config.js`. This prevents irreversible data loss through AI operations.
- **One Web App per Google account, MYSELF access** — Since the central account registry (#121–#126), the Web App is deployed once per registered account and shared across directories. The `MYSELF` access restriction is unchanged; only the deployment granularity moved from per-project to per-account. Dedicated per-project deployments remain available via `ccskill-gmail install --dedicated` (e.g., to keep per-project `config.js` permission sets).

## Adopted Security Measures

The following technical measures have been implemented. Each entry includes the issue number where the work was done.

| # | Measure | Issue |
|---|---------|-------|
| 1 | GAS Web App restricted to `MYSELF` access — only the deploying user can call the endpoint | #026 |
| 2 | `config.js` allow/deny permission mechanism; `move_to_trash` denied by default | #041 |
| 3 | `formatMessage` excludes `htmlBody` — eliminates HTML attack surface from default responses | #049 |
| 4 | Invisible character stripping (`stripInvisibleChars`) — removes zero-width spaces, joiners, and directional control characters from email body and subject | #049, #061 |
| 5 | Email body boundary markers (`EMAIL CONTENT START/END`) — helps the AI distinguish email content from user instructions | #049 |
| 6 | Indirect prompt injection warning in SKILL.md — instructs the AI not to follow instructions embedded in email content | #049 |
| 7 | Single-quote escaping added to `escapeHtml_` | #049 |
| 8 | Automatic `.gitignore` setup during install — prevents `.ccskill-gmail/` from being committed | #049 |
| 9 | Local audit log (`history.sh`) — records all API operations locally in JSONL format | #050 |
| 10 | POST temporary JSON files stored in `.ccskill-gmail/tmp/` — avoids `/tmp/` pollution and improves sandbox compatibility | #085 |
| 11 | Bulk operations protected by `isActionAllowed` permission check | #057 |
| 12 | Bulk operations provide `dryRun` option for safe preview before execution | #057 |

### Defense in Depth (Prompt Injection)

The prompt injection countermeasures form a layered defense:

```
Layer 1: htmlBody excluded from default responses (eliminates HTML-based attack surface)
Layer 2: Invisible character stripping (prevents plain-text obfuscation)
Layer 3: Content boundary markers (aids AI in distinguishing email vs. instructions)
Layer 4: SKILL.md warning (direct instruction to the AI)
Layer 5: get_message_html is explicit opt-in (HTML only when specifically requested)
```

## Review Recommendations Not Adopted

The following items were raised during security reviews but intentionally not adopted. Each entry explains the recommendation and the rationale for the decision.

| Recommendation | Decision | Rationale |
|----------------|----------|-----------|
| Add `Session.getActiveUser()` check on the GAS side | Not adopted | `access: "MYSELF"` is enforced at the Google infrastructure level. If changed to `ANYONE`, `getActiveUser()` can return empty — making it unreliable as a secondary check |
| Change default permissions to read-only | Not adopted | The primary use case (search → draft reply → label management) would not work out of the box. Per-action restriction is available via `config.js` `permissions.deny` |
| Deny HTML/attachment retrieval by default | Not adopted | Contradicts the core feature requirement (reading emails). HTML is already excluded from default responses (`get_message_html` is opt-in) |
| Add per-action audit logging on the GAS side | Not adopted | Stackdriver logging is already active. Local-side audit log (#050) provides equivalent coverage |
| Validate `installed_from` path (realpath, uid check, etc.) | Not adopted | An attacker who can tamper with `.ccskill-metadata.json` can also tamper with the `api` script itself (same directory, same permissions). Path validation of the indirect reference does not reduce attack surface (discussed during #060 review) |
| Hardcode master path in the `api` script | Not adopted | Same rationale as above — equivalent security to the `installed_from` indirect reference. Reading from metadata.json is more maintainable |
| Add rate limits on bulk operations | Not adopted | GAS has a built-in 6-minute execution time limit that serves as a natural ceiling. Adding artificial limits would reduce utility without meaningful security benefit |
