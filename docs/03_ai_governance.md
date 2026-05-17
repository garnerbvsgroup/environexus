---
title: AI Governance
version: 0.1
last_updated: 2026-05-13
status: DRAFT
---

# EnviroNexus SaaS — AI Governance

---

## 1. Purpose

This document defines the rules, roles, and operating standards for all AI tools used in the EnviroNexus SaaS project. Every team member and AI agent operating on this project is governed by these rules without exception.

Non-compliance with these rules — whether by a human or an AI agent — is treated as a project defect.

---

## 2. Governing Principle

> **AI is a disciplined collaborator, not an autonomous decision-maker.**

AI tools on this project accelerate execution. They do not set direction, override documentation, invent architecture, or act without context. Every AI action must be traceable to a governing document, a recorded decision, or an explicit human instruction.

---

## 3. Approved AI Tools and Roles

### 3.1 Grok — Project Manager / Strategic AI

| Property | Value |
|---|---|
| **Role** | Project manager, documentation architect, decision synthesizer |
| **Access** | All governing documents; implementation plans; system logs |
| **Authorized tasks** | Drafting and updating documentation; reviewing decisions against governing docs; generating structured plans; analyzing scope; flagging inconsistencies |
| **Not authorized** | Writing production code autonomously; making architecture decisions without documentation; accessing or requesting real customer data |

**Operating rule:** Grok must read the relevant governing documents before answering any question about the project. Responses that contradict governing documentation must cite the conflict explicitly rather than silently diverging.

### 3.2 GitHub Copilot — Code Generation Assistant

| Property | Value |
|---|---|
| **Role** | In-editor code assistant; implementation accelerator |
| **Access** | Workspace source code; documentation in `/docs` |
| **Authorized tasks** | Writing Dart/Flutter code to spec; Edge Function logic; database migration SQL; test scaffolding; reviewing code for security issues |
| **Not authorized** | Rewriting architecture; inventing data models not in `04_object_model.md`; generating code that contains real customer data |

**Operating rule:** Copilot suggestions must be reviewed before commit. Copilot does not have merge authority. Generated code that deviates from the object model or architecture must be corrected before use.

### 3.3 FlutterFlow AI — UI Generation Assistant

| Property | Value |
|---|---|
| **Role** | UI scaffolding; screen layout generation; component wiring |
| **Access** | FlutterFlow project canvas only |
| **Authorized tasks** | Generating screen layouts from wireframe descriptions; wiring data bindings to Supabase tables; applying theme tokens |
| **Not authorized** | Creating new database tables or schema changes; modifying backend logic; creating QBO integration flows |

**Operating rule:** All FlutterFlow AI-generated screens must be reviewed against the UX spec before promotion to a stable build. No AI-generated screen ships without human review.

---

## 4. Strict Operating Rules (All AI Tools)

The following rules apply universally to every AI tool used on this project:

### Rule 1: Read Before Acting
Before performing any task that touches architecture, schema, or business logic, the AI must first read and apply the relevant governing document(s):
- Schema changes → read `04_object_model.md` first
- Architecture decisions → read `02_system_architecture.md` first
- Scope changes → read `10_implementation_plan.md` first
- Integration changes → read `02_system_architecture.md` (Integration section) first

### Rule 2: Never Improvise Architecture
AI tools must not invent new tables, relationships, or integration patterns not documented in the governing docs. If a required object or relationship is missing from the docs, the AI must flag the gap and request a documentation update — it must not proceed by assumption.

### Rule 3: No Real Customer Data
Real customer data (names, addresses, financial records, contact information) must never be:
- Used as AI prompts or examples
- Included in training datasets or fine-tuning requests
- Stored in development or staging environments
- Passed to any third-party AI service (including Grok, Copilot, or FlutterFlow AI)

Development and testing use synthetic data only. See Section 6 for synthetic data standards.

### Rule 4: Flag Conflicts, Don't Resolve Silently
If an AI tool detects a conflict between:
- A user instruction and a governing document
- Two governing documents
- A code implementation and the documented architecture

...the AI must surface the conflict explicitly. It must not silently choose a resolution. The human project lead resolves conflicts; AI surfaces them.

### Rule 5: Log Major Decisions
Any AI-assisted decision that materially affects architecture, object model, tech stack, or timeline must be logged in `99_system_log.md` by the human project lead before it is considered adopted.

### Rule 6: No Autonomous Commits
AI-generated code must be reviewed by a human before committing to any branch. AI tools may prepare code for review; they do not have commit authority.

### Rule 7: Security First
AI-generated code must be reviewed for the following before use:
- Hardcoded credentials or secrets
- SQL injection vectors
- Insecure direct object references (missing `tenant_id` filters)
- Exposed API keys in client-side code
- Missing input validation on server-side functions

Any AI-generated code that contains a security defect must be corrected before commit, regardless of feature urgency.

---

## 5. Prompting Standards

### 5.1 Prompting Structure
All prompts to AI tools on this project should follow this structure where applicable:

```
CONTEXT: [What project, phase, and document context applies]
TASK: [What specific action is requested]
CONSTRAINTS: [Governing documents, rules, or limitations that apply]
OUTPUT FORMAT: [Expected format — code, markdown, table, etc.]
```

**Example — well-formed prompt:**
```
CONTEXT: EnviroNexus SaaS, Phase 1 MVP. Governing doc: 04_object_model.md.
TASK: Write a Supabase Edge Function that generates recurring job instances
      for all active RecurringTemplates due today.
CONSTRAINTS: Must use tenant_id isolation per 02_system_architecture.md.
             Do not introduce new tables.
OUTPUT FORMAT: TypeScript (Deno), single file, with inline comments.
```

### 5.2 Prohibited Prompt Patterns
The following prompt patterns are prohibited because they invite AI improvisation:

| Prohibited Pattern | Why |
|---|---|
| "Build me a CRM" | Too vague; AI will invent scope |
| "Create the database schema" | Schema is defined in governing docs; AI must follow it, not create it |
| "Add whatever fields you think are needed" | AI must not determine field requirements |
| "Make it work however you want" | AI must never have undefined latitude on architecture |
| "Use real data from our customers as examples" | Violates Rule 3 above |

### 5.3 Iteration Discipline
- One well-defined task per prompt when possible
- If AI output diverges from governing docs, correct the output — do not update the docs to match the output unless the divergence reveals a genuine documentation gap
- Revision history for governing docs is maintained in `99_system_log.md`

---

## 6. Synthetic Data Standards

For development, testing, and AI-assisted demonstrations:

- All synthetic customers use fictional names (e.g., "Maple Ridge Landscaping," "Thornhill Properties")
- All synthetic addresses are non-residential fictional addresses or are from publicly available test data sets
- No real phone numbers, email addresses, or financial amounts from actual customers
- Seed data files in `/supabase/seed/` are clearly marked as synthetic and must not be confused with production data
- Staging environment (`staging` branch / staging Supabase project) never receives a production data dump

---

## 7. AI Tool Access Matrix

| Governing Document | Grok | Copilot | FlutterFlow AI |
|---|---|---|---|
| 01_product_vision.md | Read/Write | Read | No access |
| 02_system_architecture.md | Read/Write | Read | No access |
| 03_ai_governance.md | Read/Write | Read | No access |
| 04_object_model.md | Read/Write | Read | No access |
| 05_relationship_map.md | Read/Write | Read | No access |
| 10_implementation_plan.md | Read/Write | Read | No access |
| 99_system_log.md | Read/Write | Read | No access |
| Source code (`/lib`, `/supabase`) | Read | Read/Write (with review) | No access |
| FlutterFlow canvas | No access | No access | Read/Write (with review) |
| Production database | No access | No access | No access |
| Real customer data | **Never** | **Never** | **Never** |

---

## 8. Governance Review Schedule

This document is reviewed and updated:
- At the start of each new project phase
- When a new AI tool is added to the project
- When a security incident or governance violation is identified
- At minimum, once per calendar quarter

All revisions are logged in `99_system_log.md`.
