---
title: Implementation Plan
version: 0.1
last_updated: 2026-05-13
status: DRAFT
---

# EnviroNexus SaaS — Implementation Plan

---

## 1. Overview

This document defines the phased implementation roadmap for EnviroNexus SaaS from initial setup through full production launch. Each phase has defined scope, milestones, success criteria, and budget guardrails.

**Total budget ceiling: < $50,000 USD**
**MVP target: 2–4 months from project start**
**Prototype target: 2 weeks from project start**

---

## 2. Phase Summary

| Phase | Name | Duration | Cumulative Budget |
|---|---|---|---|
| Phase 0 | Foundation & Governance | Week 1–2 | ~$0 |
| Phase 1 | Core Data Model & Auth | Week 3–4 | ~$500 |
| Phase 2 | Customer, Property & Job MVP | Month 2 | ~$3,000 |
| Phase 3 | Estimating, Invoicing & QBO | Month 3 | ~$8,000 |
| Phase 4 | Recurring Services & Scheduling | Month 4 | ~$15,000 |
| Phase 5 | Mobile App & Field Crew Experience | Month 5–6 | ~$28,000 |
| Phase 6 | Customer Portal, Reporting & Launch | Month 7–8 | ~$42,000 |

---

## 3. Phase Details

---

### Phase 0 — Foundation & Governance
**Duration:** Week 1–2
**Budget:** $0 (no paid tooling incurred yet)
**Goal:** Establish the documentation, tooling, and infrastructure foundation before a single line of code is written.

#### Milestones
- [ ] All governing documents created and reviewed (`01` through `05`, `10`, `99`)
- [ ] GitHub repository initialized with branch protection rules (`main`, `develop`, `staging`)
- [ ] Supabase project created (development instance)
- [ ] FlutterFlow project initialized with EnviroNexus theme (brand colors, fonts, logo)
- [ ] AI tool governance rules in place (`03_ai_governance.md` signed off)
- [ ] Development environment documented and reproducible
- [ ] `99_system_log.md` initialized with first entries

#### Success Criteria
- All team members and AI tools know where governing docs live and how to use them
- Supabase project accessible and secured
- FlutterFlow theme matches EnviroNexus brand

#### Tooling Costs
| Tool | Cost |
|---|---|
| GitHub | Free (private repo) |
| Supabase | Free tier (development) |
| FlutterFlow | Free tier (development) |

---

### Phase 1 — Core Data Model & Auth
**Duration:** Week 3–4
**Budget target:** ~$500
**Goal:** Build the database schema for all core objects, implement authentication, and establish the multi-tenant data isolation layer.

#### Milestones
- [ ] Full PostgreSQL schema deployed to Supabase (all objects from `04_object_model.md`)
- [ ] Row Level Security policies implemented and tested for all tenant-scoped tables
- [ ] Supabase Auth configured (email/password, Google OAuth)
- [ ] User roles and RBAC policies implemented
- [ ] Tenant onboarding flow (registration → tenant creation → owner user linked)
- [ ] Synthetic seed data created for testing
- [ ] Schema documented in migration files (`/supabase/migrations/`)

#### Success Criteria
- A new tenant can register, log in, and be fully isolated from other tenants
- All RLS policies validated with automated tests (multiple tenants attempting cross-access)
- Schema matches `04_object_model.md` with no deviations

#### Tooling Costs
| Tool | Cost |
|---|---|
| Supabase (Pro, if needed) | $25/month |

---

### Phase 2 — Customer, Property & Job MVP
**Duration:** Month 2 (Weeks 5–8)
**Budget target:** ~$3,000 cumulative
**Goal:** Deliver a working prototype of the core operational workflow: create customers, properties, and jobs; dispatch and complete jobs from the web interface.

#### Milestones
- [ ] Customer CRUD (web — FlutterFlow)
- [ ] Property CRUD linked to Customer
- [ ] Asset CRUD linked to Property
- [ ] Job creation (manual, one-off)
- [ ] Job scheduling (calendar/dispatch board view)
- [ ] Job assignment to crew members
- [ ] Job status workflow (scheduled → in_progress → completed)
- [ ] Basic job completion form (notes, photos)
- [ ] Attachment upload (Supabase Storage integration)
- [ ] Basic internal notes on Customer and Job

#### Prototype Milestone (End of Phase 2)
> **A complete demo-ready flow:** Create a customer with a property → create a job → assign it → mark it complete with a photo → view it in the dashboard.

#### Success Criteria
- End-to-end job workflow works in web browser
- Photo upload and retrieval works
- All data is correctly tenant-isolated
- No security vulnerabilities in new code (reviewed against OWASP Top 10)

#### Tooling Costs
| Tool | Cost |
|---|---|
| Supabase Pro | $25/month |
| FlutterFlow Starter | $30/month |

---

### Phase 3 — Estimating, Invoicing & QBO Integration
**Duration:** Month 3 (Weeks 9–12)
**Budget target:** ~$8,000 cumulative
**Goal:** Complete the financial workflow — estimates, invoices, and live QuickBooks Online sync.

#### Milestones
- [ ] ServiceType catalog management
- [ ] Estimate creation with line items
- [ ] Estimate PDF generation (branded)
- [ ] Estimate email delivery (SendGrid)
- [ ] Customer digital acceptance (e-signature link)
- [ ] Estimate → Job conversion flow
- [ ] Invoice creation (manual + from completed jobs)
- [ ] Invoice PDF generation
- [ ] Invoice email delivery
- [ ] QBO OAuth connection flow (per tenant)
- [ ] QBO Customer sync (bi-directional)
- [ ] QBO Invoice push
- [ ] QBO Payment pull
- [ ] QBO sync error dashboard
- [ ] Payment recording and allocation

#### MVP Milestone (End of Phase 3)
> **A complete revenue cycle:** Estimate → Customer acceptance → Job → Completion → Invoice → QBO sync → Payment recorded.

#### Success Criteria
- Full estimate-to-invoice flow works end-to-end
- QBO sync tested against a live QBO sandbox company
- QBO sync error rate in testing: 0%
- Invoice totals and QBO totals reconcile exactly

#### Tooling Costs
| Tool | Cost |
|---|---|
| SendGrid | Free tier (100 emails/day) |
| QBO Developer Account | Free (sandbox) |

---

### Phase 4 — Recurring Services & Scheduling
**Duration:** Month 4 (Weeks 13–16)
**Budget target:** ~$15,000 cumulative
**Goal:** Implement the recurring service engine — the core competitive differentiator for the green industry.

#### Milestones
- [ ] RecurringTemplate creation UI
- [ ] Schedule configuration (all frequency types: weekly, biweekly, monthly, every-N-days, seasonal)
- [ ] Daily Edge Function: auto-generate jobs from active templates
- [ ] Recurring job generation tested for all frequency types
- [ ] Template pause/resume/cancel flow
- [ ] Recurring program billing (per-visit and program-advance modes)
- [ ] Batch invoicing: generate one invoice for multiple completed jobs
- [ ] Season start/end configuration per template
- [ ] Recurring template occurrence tracking (`occurrences_completed` counter)
- [ ] Route optimization view (basic — jobs grouped by geography)
- [ ] Dispatch board enhancements (filter by date, crew, status)

#### Success Criteria
- Recurring templates generate jobs correctly for all frequency types across a simulated 12-month period
- Batch invoicing produces correct totals with no duplicate line items
- Edge Function runs reliably (tested with multiple concurrent tenants)

---

### Phase 5 — Mobile App & Field Crew Experience
**Duration:** Month 5–6 (Weeks 17–24)
**Budget target:** ~$28,000 cumulative
**Goal:** Deploy the FlutterFlow mobile app (iOS + Android) built specifically for field crew workflows.

#### Milestones
- [ ] FlutterFlow mobile build configured (iOS + Android targets)
- [ ] Field crew login and role-restricted mobile dashboard
- [ ] Today's job list (offline-capable via local cache)
- [ ] Job detail view (instructions, property notes, access info)
- [ ] GPS check-in / check-out on job start/end
- [ ] Job completion form (completion notes, photos, signature capture)
- [ ] Completed job sync when connectivity restored (offline-first)
- [ ] Push notifications for job assignment and schedule changes
- [ ] Map view of daily route
- [ ] TestFlight (iOS) and Google Play Internal Testing deployment
- [ ] Field crew user acceptance testing (UAT) with real crew members

#### Success Criteria
- App functions fully with no connectivity for a full 8-hour work day
- GPS check-in accuracy within 50 meters
- Photo upload succeeds on reconnect with no data loss
- Field crew UAT: > 80% task completion rate without assistance

#### Tooling Costs
| Tool | Cost |
|---|---|
| Apple Developer Program | $99/year |
| Google Play Developer | $25 one-time |
| FlutterFlow Pro | $70/month |

---

### Phase 6 — Customer Portal, Reporting & Launch
**Duration:** Month 7–8 (Weeks 25–32)
**Budget target:** ~$42,000 cumulative
**Goal:** Deliver the customer-facing portal, operational reporting, and prepare for public launch.

#### Milestones
- [ ] Customer self-service portal (view invoices, accept estimates, make payments)
- [ ] Stripe integration for online payment in customer portal (optional: Phase 7)
- [ ] Operational reports: revenue by service type, jobs completed by crew, outstanding balances
- [ ] Tenant onboarding wizard (guided setup: company info, QBO connect, service catalog, first customer)
- [ ] Subscription billing management (Stripe or manual)
- [ ] Multi-location / multi-property customer portal support
- [ ] Performance hardening: query optimization, RLS policy audit
- [ ] Security audit: OWASP Top 10 review of all API surfaces
- [ ] Beta customer onboarding (2–5 pilot tenants)
- [ ] Feedback collection and iteration sprint
- [ ] Production environment configured (separate Supabase project)
- [ ] Domain live, SSL active, monitoring in place

#### Launch Milestone (End of Phase 6)
> **EnviroNexus is live in production with at least 2 paying pilot tenants, QBO sync operational, and field crew mobile app deployed.**

#### Success Criteria
- All Phase 0–5 success criteria remain passing
- Zero critical or high security findings in security audit
- QBO sync error rate in production: < 0.5%
- Pilot tenant NPS: > 40
- Monthly cost of running the platform: < $300/month at < 10 tenants

---

## 4. Budget Guardrails

| Category | Phase 0–2 | Phase 3–4 | Phase 5–6 | Cumulative Max |
|---|---|---|---|---|
| SaaS tooling (Supabase, FlutterFlow, etc.) | $0–$100 | $500 | $2,000 | $3,000 |
| Third-party APIs (SendGrid, QBO, Google) | $0 | $0–$100 | $200 | $400 |
| Apple / Google developer accounts | $0 | $0 | $125 | $125 |
| Design / branding assets | $0–$500 | $500 | $500 | $1,500 |
| Development labor | $0 | $5,000 | $30,000 | $40,000 |
| Contingency (10%) | — | — | — | $5,000 |
| **Total** | | | | **< $50,000** |

> **Rule:** No tooling commitment exceeding $200/month is made without explicit project lead approval and a log entry in `99_system_log.md`.

---

## 5. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| QBO API rate limits or breaking changes | Medium | High | Use official SDK; monitor QBO developer changelog; build retry/backoff |
| FlutterFlow limitations requiring full code export | Low | Medium | Design with export in mind; Dart custom actions for complex logic |
| Scope creep beyond Phase 3 | High | High | Strict phase gates; any scope addition requires `99_system_log.md` entry and plan revision |
| Supabase Edge Function cold start latency | Low | Low | Monitor; move to persistent workers if needed |
| Pilot tenant adoption failure | Medium | High | Early UAT in Phase 5; iterate before Phase 6 launch |
| Budget overrun on development labor | Medium | High | Weekly budget review; feature freeze if > 80% of budget consumed before Phase 6 |

---

## 6. Phase Gate Criteria

A phase is considered complete only when all of its **Success Criteria** are met and the completion is logged in `99_system_log.md`. No phase begins until the previous phase gate is passed. Exceptions require explicit project lead sign-off recorded in the system log.
