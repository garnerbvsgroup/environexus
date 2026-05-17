---
title: System Architecture
version: 0.1
last_updated: 2026-05-13
status: DRAFT
---

# EnviroNexus SaaS — System Architecture

---

## 1. Architecture Overview

EnviroNexus is a cloud-native, multi-tenant SaaS platform delivered entirely through the browser (web) and native mobile applications. There is no desktop installation, no local server dependency, and no per-device licensing for core functionality.

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                         │
│  ┌────────────────────┐     ┌──────────────────────────┐   │
│  │   Web Application  │     │  Mobile App (iOS/Android) │   │
│  │   (FlutterFlow)    │     │      (FlutterFlow)        │   │
│  └────────┬───────────┘     └───────────┬──────────────┘   │
└───────────┼─────────────────────────────┼───────────────────┘
            │                             │
            ▼                             ▼
┌─────────────────────────────────────────────────────────────┐
│                       API / BACKEND LAYER                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               Supabase (Primary Backend)             │   │
│  │  • PostgreSQL database (row-level security)          │   │
│  │  • Auth (email/password, OAuth)                      │   │
│  │  • Storage (file attachments, photos)                │   │
│  │  • Edge Functions (custom business logic)            │   │
│  │  • Realtime (live schedule updates)                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│                   INTEGRATION LAYER                         │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  QuickBooks     │  │  Google Maps  │  │  SendGrid /   │  │
│  │  Online (QBO)   │  │  / Places API │  │  Twilio       │  │
│  └─────────────────┘  └──────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Tech Stack Decisions

### 2.1 Frontend & Mobile — FlutterFlow

| Decision | Rationale |
|---|---|
| **Platform:** FlutterFlow | Produces native iOS, Android, and web from a single codebase. Eliminates the need for separate mobile and web development teams. |
| **Export:** Flutter/Dart source | Code is exportable; we are not locked into the FlutterFlow platform forever. |
| **UI framework:** Material 3 + custom theme | Provides a strong, consistent component library with room for EnviroNexus branding (teal/green palette, fingerprint motif). |
| **State management:** FlutterFlow state + custom actions | Global app state managed through FlutterFlow's built-in state management; complex business logic extracted to Dart custom actions. |
| **Offline support:** Local SQLite cache | Field crew mobile views cache today's jobs for offline operation. Changes sync on reconnect. |

### 2.2 Backend — Supabase

| Decision | Rationale |
|---|---|
| **Database:** PostgreSQL via Supabase | Battle-tested relational database. Full SQL capability for complex queries (recurring schedules, financial reports). |
| **Auth:** Supabase Auth | Built-in user management with JWT-based session tokens. Supports email/password and OAuth (Google). Role-based access enforced at the database layer via Row Level Security (RLS). |
| **Storage:** Supabase Storage | S3-compatible object storage for job photos, attachment files, and proposal PDFs. |
| **Business logic:** Supabase Edge Functions (Deno) | Serverless functions for webhook handling, QBO sync, recurring job generation, and complex triggers. |
| **Realtime:** Supabase Realtime | Live updates for dispatch board — new jobs, status changes, and GPS check-ins broadcast in real time. |

> **Contingency:** If Supabase proves insufficient for a specific workflow (e.g., complex background job scheduling), Xano may be evaluated as a backend supplement or replacement for that workflow only. The database schema design is not Supabase-specific.

### 2.3 Integrations

| Integration | Purpose | Protocol |
|---|---|---|
| QuickBooks Online | Invoice sync, payment sync, customer sync, tax codes | OAuth 2.0 + QBO REST API v3 |
| Google Maps / Places | Address autocomplete, route visualization, property geocoding | Google Maps Platform REST API |
| Google Calendar (optional) | Crew schedule export | Google Calendar API v3 |
| SendGrid | Transactional email (estimates, invoices, notifications) | REST API |
| Twilio (optional) | SMS notifications to field crews and customers | REST API |
| Stripe (future) | In-app payment processing for customer portal | Stripe API |

---

## 3. Multi-Tenant Structure

EnviroNexus is a multi-tenant SaaS platform. Each subscribing business is a **Tenant**.

### Tenancy Model: Shared Database, Isolated Data

All tenants share the same PostgreSQL database schema. Data isolation is enforced at every layer:

#### Database Layer (Row Level Security)
Every table that holds tenant-scoped data includes a `tenant_id` UUID foreign key column. Supabase RLS policies ensure:

```sql
-- Example RLS policy on the "customers" table
CREATE POLICY "tenant_isolation" ON customers
  USING (tenant_id = auth.jwt() ->> 'tenant_id');
```

No query — regardless of how it is constructed — can return data from another tenant.

#### Application Layer
All API calls and Edge Functions validate `tenant_id` from the authenticated user's JWT claims before processing. `tenant_id` is never accepted as a user-supplied parameter; it is always derived from the authenticated session.

#### Storage Layer
Supabase Storage buckets are organized by tenant:
```
/attachments/{tenant_id}/{record_type}/{record_id}/{filename}
```
Bucket policies restrict access to the owning tenant.

### Tenant Onboarding Flow
1. Owner registers → Tenant record created → Owner User record linked with `role = owner`
2. Tenant configuration wizard (company name, logo, service types, QBO connection)
3. First user invitation sent → additional users linked to same `tenant_id`
4. QBO OAuth flow completed → `qbo_tokens` stored encrypted per tenant

---

## 4. Data Storage Strategy

### 4.1 Structured Data (PostgreSQL)
All core domain objects (Customers, Jobs, Invoices, etc.) are stored in normalized relational tables. See `04_object_model.md` for full schema definitions.

**Key design principles:**
- Soft deletes on all major entities (`deleted_at` timestamp, not physical row deletion)
- Audit columns on every table: `created_at`, `updated_at`, `created_by`, `updated_by`
- UUID primary keys (not sequential integers) for all tenant-scoped records
- JSONB columns used selectively for flexible attribute storage (e.g., `service_attributes` on job records)

### 4.2 File Storage (Supabase Storage)
| Object Type | Storage Location |
|---|---|
| Job completion photos | `/attachments/{tenant_id}/jobs/{job_id}/` |
| Customer signatures | `/attachments/{tenant_id}/jobs/{job_id}/signatures/` |
| Proposal / estimate PDFs | `/attachments/{tenant_id}/proposals/{proposal_id}/` |
| Company logo | `/tenant_assets/{tenant_id}/logo` |
| Document attachments | `/attachments/{tenant_id}/documents/{record_id}/` |

### 4.3 Caching
- Mobile app caches today's job list in local SQLite for offline access
- No server-side caching layer in Phase 0–1; add Redis/Supabase caching at Phase 2+ if query performance requires it

---

## 5. Integration Architecture — QuickBooks Online

QBO integration is a first-class concern. The following outlines the sync architecture:

### 5.1 Authentication
- OAuth 2.0 authorization code flow per tenant
- Access tokens stored encrypted in `tenant_qbo_tokens` table
- Token refresh handled automatically by Edge Function before each API call

### 5.2 Sync Objects

| EnviroNexus Object | QBO Object | Direction |
|---|---|---|
| Customer | Customer | Bi-directional |
| Invoice | Invoice | Push (EN → QBO) |
| Payment | Payment | Pull (QBO → EN) |
| Service Item | Item (Service) | Push (EN → QBO) |
| Credit Memo | Credit Memo | Push (EN → QBO) |

### 5.3 Sync Strategy
- **Invoice push:** Triggered immediately when an invoice status changes to `approved` in EnviroNexus
- **Payment pull:** Webhook from QBO (or polling fallback) triggers payment status update in EnviroNexus
- **Customer sync:** New customers created in EnviroNexus push to QBO; QBO customer imports available during onboarding
- **Conflict resolution:** EnviroNexus is the system of record for field data; QBO is the system of record for payment status

### 5.4 Error Handling
- All sync operations logged to `qbo_sync_log` table with status (`success`, `failed`, `pending_retry`)
- Failed syncs surfaced in the owner dashboard with actionable error messages
- Maximum 3 automatic retries with exponential backoff before requiring manual intervention

---

## 6. Security and Compliance

### 6.1 Authentication and Authorization
- All sessions authenticated via Supabase Auth (JWT, 1-hour expiry, refresh token rotation)
- Role-based access control (RBAC) enforced at both the application and database layers
- Roles: `owner`, `admin`, `office_manager`, `dispatcher`, `crew_lead`, `field_crew`
- MFA available (TOTP) for owner and admin roles

### 6.2 Data Security
- All data in transit encrypted via TLS 1.2+
- All data at rest encrypted by Supabase (AES-256)
- QBO tokens encrypted at the application layer before storage (AES-256-GCM)
- No real customer PII used in development or staging environments (see `03_ai_governance.md`)

### 6.3 API Security
- All API endpoints require valid JWT
- Rate limiting applied at the Supabase / Edge Function layer
- Input validation enforced on all Edge Functions (schema validation via Zod)
- SQL injection not possible due to parameterized queries via Supabase client

### 6.4 Compliance Considerations
- **GDPR / CCPA:** Data deletion capability required; soft-delete + full purge path must be implemented
- **SOC 2:** Not required at launch; architecture decisions documented for future audit readiness
- **PCI DSS:** No raw card data stored; Stripe handles all payment card processing (future phase)

### 6.5 Backup and Recovery
- Supabase provides automated daily database backups with point-in-time recovery
- File storage replicated within Supabase infrastructure
- RTO target: < 4 hours | RPO target: < 24 hours (Phase 0–1)

---

## 7. Infrastructure and Hosting

| Component | Provider | Notes |
|---|---|---|
| Database | Supabase (AWS us-east-1) | Managed PostgreSQL |
| Edge Functions | Supabase Edge Runtime (Deno) | Serverless; auto-scaled |
| File Storage | Supabase Storage | S3-compatible |
| Web App Hosting | FlutterFlow CDN / Vercel | Static Flutter web build |
| Domain & DNS | Cloudflare | DNS management + DDoS protection |
| Email | SendGrid | Transactional only |
| Monitoring | Supabase Dashboard + Sentry (future) | Error tracking |
