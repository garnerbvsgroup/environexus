-- ============================================================
-- Migration: 000001_initial_schema.sql
-- Project:   EnviroNexus SaaS — environexus-dev
-- Date:      2026-05-16
-- Phase:     1 — Core Data Model & Auth
-- Sources:   docs/04_object_model.md
--            docs/05_relationship_map.md
--            docs/02_system_architecture.md
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- HELPER: auto-update updated_at on row change
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- HELPER: return calling user's tenant_id (used by RLS)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_tenant_id()
RETURNS UUID AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM public.users WHERE id = auth.uid();
  RETURN v_tenant_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================
-- TABLE: tenants
-- Source: 04_object_model.md § 2.1
-- ============================================================
CREATE TABLE public.tenants (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT        NOT NULL,
  slug                TEXT        NOT NULL UNIQUE,
  logo_url            TEXT,
  primary_color       TEXT,
  subscription_plan   TEXT        NOT NULL DEFAULT 'trial'
                        CHECK (subscription_plan IN ('trial','starter','growth','enterprise')),
  subscription_status TEXT        NOT NULL DEFAULT 'trialing'
                        CHECK (subscription_status IN ('active','past_due','cancelled','trialing')),
  trial_ends_at       TIMESTAMPTZ,
  qbo_realm_id        TEXT,
  qbo_connected       BOOLEAN     NOT NULL DEFAULT FALSE,
  timezone            TEXT        NOT NULL DEFAULT 'America/New_York',
  address_line1       TEXT,
  address_line2       TEXT,
  city                TEXT,
  state               TEXT,
  zip                 TEXT,
  phone               TEXT,
  email               TEXT,
  website             TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_tenants_slug       ON public.tenants(slug);
CREATE INDEX idx_tenants_active     ON public.tenants(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_tenants_updated_at
  BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: users
-- Source: 04_object_model.md § 2.2
-- NOTE: id = auth.users.id (Supabase Auth mirror)
-- ============================================================
CREATE TABLE public.users (
  id            UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id     UUID        NOT NULL REFERENCES public.tenants(id),
  email         TEXT        NOT NULL,
  first_name    TEXT,
  last_name     TEXT,
  phone         TEXT,
  role          TEXT        NOT NULL DEFAULT 'field_crew'
                  CHECK (role IN ('owner','admin','office_manager','dispatcher','crew_lead','field_crew')),
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  avatar_url    TEXT,
  default_view  TEXT        DEFAULT 'dashboard'
                  CHECK (default_view IN ('dashboard','schedule','jobs')),
  receive_sms   BOOLEAN     NOT NULL DEFAULT FALSE,
  receive_email BOOLEAN     NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX idx_users_tenant_id  ON public.users(tenant_id);
CREATE INDEX idx_users_email      ON public.users(email);
CREATE INDEX idx_users_active     ON public.users(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: customers
-- Source: 04_object_model.md § 2.3
-- ============================================================
CREATE TABLE public.customers (
  id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                UUID        NOT NULL REFERENCES public.tenants(id),
  qbo_customer_id          TEXT,
  qbo_sync_status          TEXT        NOT NULL DEFAULT 'not_linked'
                             CHECK (qbo_sync_status IN ('synced','pending','error','not_linked')),
  display_name             TEXT        NOT NULL,
  company_name             TEXT,
  first_name               TEXT,
  last_name                TEXT,
  customer_type            TEXT        NOT NULL DEFAULT 'residential'
                             CHECK (customer_type IN ('residential','commercial','hoa','municipal')),
  status                   TEXT        NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active','inactive','prospect','on_hold')),
  email                    TEXT,
  email_cc                 TEXT[],
  phone_primary            TEXT,
  phone_secondary          TEXT,
  billing_address_line1    TEXT,
  billing_address_line2    TEXT,
  billing_city             TEXT,
  billing_state            TEXT,
  billing_zip              TEXT,
  billing_same_as_property BOOLEAN     NOT NULL DEFAULT FALSE,
  payment_terms            TEXT        DEFAULT 'net_30'
                             CHECK (payment_terms IN ('due_on_receipt','net_15','net_30','net_45')),
  default_tax_code         TEXT,
  source                   TEXT
                             CHECK (source IN ('website','referral','google','canvass','other')),
  notes                    TEXT,
  tags                     TEXT[],
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at               TIMESTAMPTZ
);

CREATE INDEX idx_customers_tenant_id       ON public.customers(tenant_id);
CREATE INDEX idx_customers_status          ON public.customers(tenant_id, status);
CREATE INDEX idx_customers_qbo_id          ON public.customers(qbo_customer_id) WHERE qbo_customer_id IS NOT NULL;
CREATE INDEX idx_customers_active          ON public.customers(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON public.customers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: properties
-- Source: 04_object_model.md § 2.4
-- ============================================================
CREATE TABLE public.properties (
  id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID           NOT NULL REFERENCES public.tenants(id),
  customer_id   UUID           NOT NULL REFERENCES public.customers(id),
  name          TEXT,
  address_line1 TEXT           NOT NULL,
  address_line2 TEXT,
  city          TEXT           NOT NULL,
  state         TEXT           NOT NULL,
  zip           TEXT           NOT NULL,
  latitude      DECIMAL(9,6),
  longitude     DECIMAL(9,6),
  property_type TEXT           NOT NULL DEFAULT 'residential'
                  CHECK (property_type IN ('residential','commercial','hoa_common','municipal')),
  lot_size_sqft DECIMAL(10,2),
  lot_size_acres DECIMAL(8,4),
  irrigated     BOOLEAN        NOT NULL DEFAULT FALSE,
  gate_code     TEXT,
  access_notes  TEXT,
  is_primary    BOOLEAN        NOT NULL DEFAULT FALSE,
  status        TEXT           NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','inactive')),
  notes         TEXT,
  created_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX idx_properties_tenant_id   ON public.properties(tenant_id);
CREATE INDEX idx_properties_customer_id ON public.properties(customer_id);
CREATE INDEX idx_properties_active      ON public.properties(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_properties_updated_at
  BEFORE UPDATE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: assets
-- Source: 04_object_model.md § 2.5
-- ============================================================
CREATE TABLE public.assets (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID          NOT NULL REFERENCES public.tenants(id),
  property_id          UUID          NOT NULL REFERENCES public.properties(id),
  asset_type           TEXT          NOT NULL
                         CHECK (asset_type IN ('tree','shrub','lawn_zone','irrigation_zone','structure','other')),
  common_name          TEXT,
  scientific_name      TEXT,
  dbh_inches           DECIMAL(6,2),
  height_ft            DECIMAL(6,2),
  spread_ft            DECIMAL(6,2),
  condition            TEXT
                         CHECK (condition IN ('excellent','good','fair','poor','critical','dead')),
  location_on_property TEXT,
  latitude             DECIMAL(9,6),
  longitude            DECIMAL(9,6),
  planted_date         DATE,
  last_serviced_date   DATE,
  next_service_date    DATE,
  notes                TEXT,
  attributes           JSONB,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at           TIMESTAMPTZ
);

CREATE INDEX idx_assets_tenant_id   ON public.assets(tenant_id);
CREATE INDEX idx_assets_property_id ON public.assets(property_id);
CREATE INDEX idx_assets_active      ON public.assets(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_assets_updated_at
  BEFORE UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: service_types
-- Source: 04_object_model.md § 2.6
-- ============================================================
CREATE TABLE public.service_types (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES public.tenants(id),
  name                  TEXT          NOT NULL,
  category              TEXT          NOT NULL
                          CHECK (category IN ('lawn_care','landscaping','tree_care','snow_ice','general_contracting','other')),
  description           TEXT,
  default_unit          TEXT
                          CHECK (default_unit IN ('per_visit','per_sqft','per_hour','per_item','flat')),
  default_price         DECIMAL(10,2),
  qbo_item_id           TEXT,
  qbo_income_account    TEXT,
  is_recurring_eligible BOOLEAN       NOT NULL DEFAULT TRUE,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_service_types_tenant_id ON public.service_types(tenant_id);
CREATE INDEX idx_service_types_active    ON public.service_types(tenant_id, is_active);

CREATE TRIGGER trg_service_types_updated_at
  BEFORE UPDATE ON public.service_types
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: recurring_templates
-- Source: 04_object_model.md § 2.7
-- ============================================================
CREATE TABLE public.recurring_templates (
  id                         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                  UUID          NOT NULL REFERENCES public.tenants(id),
  customer_id                UUID          NOT NULL REFERENCES public.customers(id),
  property_id                UUID          NOT NULL REFERENCES public.properties(id),
  service_type_id            UUID          NOT NULL REFERENCES public.service_types(id),
  name                       TEXT          NOT NULL,
  status                     TEXT          NOT NULL DEFAULT 'active'
                               CHECK (status IN ('active','paused','completed','cancelled')),
  frequency_type             TEXT          NOT NULL
                               CHECK (frequency_type IN ('weekly','biweekly','monthly','every_n_days','seasonal','custom')),
  frequency_interval         INTEGER,
  season_start_month         INTEGER       CHECK (season_start_month BETWEEN 1 AND 12),
  season_end_month           INTEGER       CHECK (season_end_month BETWEEN 1 AND 12),
  occurrences_total          INTEGER,
  occurrences_completed      INTEGER       NOT NULL DEFAULT 0,
  schedule_start_date        DATE          NOT NULL,
  schedule_end_date          DATE,
  preferred_day_of_week      INTEGER       CHECK (preferred_day_of_week BETWEEN 0 AND 6),
  assigned_crew_id           UUID          REFERENCES public.users(id),
  estimated_duration_minutes INTEGER,
  price_per_visit            DECIMAL(10,2),
  billing_cycle              TEXT
                               CHECK (billing_cycle IN ('per_visit','monthly','program_advance','program_completion')),
  notes                      TEXT,
  attributes                 JSONB,
  created_at                 TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at                 TIMESTAMPTZ
);

CREATE INDEX idx_recurring_templates_tenant_id    ON public.recurring_templates(tenant_id);
CREATE INDEX idx_recurring_templates_customer_id  ON public.recurring_templates(customer_id);
CREATE INDEX idx_recurring_templates_property_id  ON public.recurring_templates(property_id);
CREATE INDEX idx_recurring_templates_status       ON public.recurring_templates(tenant_id, status);
CREATE INDEX idx_recurring_templates_active       ON public.recurring_templates(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_recurring_templates_updated_at
  BEFORE UPDATE ON public.recurring_templates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: jobs
-- Source: 04_object_model.md § 2.8
-- NOTE: estimate_id and invoice_id FKs added after those tables exist
-- ============================================================
CREATE TABLE public.jobs (
  id                         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                  UUID          NOT NULL REFERENCES public.tenants(id),
  customer_id                UUID          NOT NULL REFERENCES public.customers(id),
  property_id                UUID          NOT NULL REFERENCES public.properties(id),
  service_type_id            UUID          REFERENCES public.service_types(id),
  recurring_template_id      UUID          REFERENCES public.recurring_templates(id),
  estimate_id                UUID,         -- FK added after estimates table (see below)
  job_number                 TEXT          NOT NULL,
  title                      TEXT,
  status                     TEXT          NOT NULL DEFAULT 'scheduled'
                               CHECK (status IN ('scheduled','en_route','in_progress','completed','invoiced','cancelled','on_hold')),
  priority                   TEXT          NOT NULL DEFAULT 'normal'
                               CHECK (priority IN ('low','normal','high','urgent')),
  scheduled_date             DATE,
  scheduled_start_time       TIME,
  scheduled_end_time         TIME,
  actual_start_time          TIMESTAMPTZ,
  actual_end_time            TIMESTAMPTZ,
  assigned_crew_lead_id      UUID          REFERENCES public.users(id),
  assigned_crew_members      UUID[],
  instructions               TEXT,
  completion_notes           TEXT,
  customer_signature_url     TEXT,
  gps_checkin_lat            DECIMAL(9,6),
  gps_checkin_lng            DECIMAL(9,6),
  gps_checkout_lat           DECIMAL(9,6),
  gps_checkout_lng           DECIMAL(9,6),
  duration_actual_minutes    INTEGER,
  duration_estimated_minutes INTEGER,
  invoice_id                 UUID,         -- FK added after invoices table (see below)
  attributes                 JSONB,
  created_at                 TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at                 TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_jobs_job_number           ON public.jobs(tenant_id, job_number);
CREATE INDEX        idx_jobs_tenant_id            ON public.jobs(tenant_id);
CREATE INDEX        idx_jobs_customer_id          ON public.jobs(customer_id);
CREATE INDEX        idx_jobs_property_id          ON public.jobs(property_id);
CREATE INDEX        idx_jobs_status               ON public.jobs(tenant_id, status);
CREATE INDEX        idx_jobs_scheduled_date       ON public.jobs(tenant_id, scheduled_date);
CREATE INDEX        idx_jobs_recurring_template   ON public.jobs(recurring_template_id) WHERE recurring_template_id IS NOT NULL;
CREATE INDEX        idx_jobs_active               ON public.jobs(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_jobs_updated_at
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: estimates
-- Source: 04_object_model.md § 2.9
-- ============================================================
CREATE TABLE public.estimates (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID          NOT NULL REFERENCES public.tenants(id),
  customer_id         UUID          NOT NULL REFERENCES public.customers(id),
  property_id         UUID          NOT NULL REFERENCES public.properties(id),
  estimate_number     TEXT          NOT NULL,
  title               TEXT,
  status              TEXT          NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','sent','viewed','accepted','declined','expired','converted')),
  valid_until         DATE,
  sent_at             TIMESTAMPTZ,
  viewed_at           TIMESTAMPTZ,
  accepted_at         TIMESTAMPTZ,
  accepted_by_name    TEXT,
  accepted_ip_address TEXT,
  subtotal            DECIMAL(10,2) NOT NULL DEFAULT 0,
  discount_type       TEXT          CHECK (discount_type IN ('flat','percent')),
  discount_value      DECIMAL(10,2),
  tax_rate            DECIMAL(5,4)  NOT NULL DEFAULT 0,
  tax_amount          DECIMAL(10,2) NOT NULL DEFAULT 0,
  total               DECIMAL(10,2) NOT NULL DEFAULT 0,
  notes_internal      TEXT,
  notes_customer      TEXT,
  pdf_url             TEXT,
  created_by          UUID          REFERENCES public.users(id),
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_estimates_number      ON public.estimates(tenant_id, estimate_number);
CREATE INDEX        idx_estimates_tenant_id   ON public.estimates(tenant_id);
CREATE INDEX        idx_estimates_customer_id ON public.estimates(customer_id);
CREATE INDEX        idx_estimates_status      ON public.estimates(tenant_id, status);
CREATE INDEX        idx_estimates_active      ON public.estimates(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_estimates_updated_at
  BEFORE UPDATE ON public.estimates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Deferred FK: jobs → estimates
ALTER TABLE public.jobs
  ADD CONSTRAINT fk_jobs_estimate_id
  FOREIGN KEY (estimate_id) REFERENCES public.estimates(id);

-- ============================================================
-- TABLE: estimate_line_items
-- Source: 04_object_model.md § 2.10
-- ============================================================
CREATE TABLE public.estimate_line_items (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID          NOT NULL REFERENCES public.tenants(id),
  estimate_id     UUID          NOT NULL REFERENCES public.estimates(id) ON DELETE CASCADE,
  service_type_id UUID          REFERENCES public.service_types(id),
  sort_order      INTEGER       NOT NULL DEFAULT 0,
  description     TEXT          NOT NULL,
  quantity        DECIMAL(10,3) NOT NULL DEFAULT 1,
  unit            TEXT,
  unit_price      DECIMAL(10,2) NOT NULL DEFAULT 0,
  line_total      DECIMAL(10,2) NOT NULL DEFAULT 0,
  is_optional     BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_estimate_line_items_estimate_id    ON public.estimate_line_items(estimate_id);
CREATE INDEX idx_estimate_line_items_tenant_id      ON public.estimate_line_items(tenant_id);

CREATE TRIGGER trg_estimate_line_items_updated_at
  BEFORE UPDATE ON public.estimate_line_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: invoices
-- Source: 04_object_model.md § 2.11
-- ============================================================
CREATE TABLE public.invoices (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID          NOT NULL REFERENCES public.tenants(id),
  customer_id     UUID          NOT NULL REFERENCES public.customers(id),
  qbo_invoice_id  TEXT,
  qbo_sync_status TEXT          NOT NULL DEFAULT 'not_linked'
                    CHECK (qbo_sync_status IN ('synced','pending','error','not_linked')),
  invoice_number  TEXT          NOT NULL,
  status          TEXT          NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','approved','sent','partial','paid','void','overdue')),
  invoice_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
  due_date        DATE,
  sent_at         TIMESTAMPTZ,
  subtotal        DECIMAL(10,2) NOT NULL DEFAULT 0,
  discount_type   TEXT          CHECK (discount_type IN ('flat','percent')),
  discount_value  DECIMAL(10,2),
  tax_rate        DECIMAL(5,4)  NOT NULL DEFAULT 0,
  tax_amount      DECIMAL(10,2) NOT NULL DEFAULT 0,
  total           DECIMAL(10,2) NOT NULL DEFAULT 0,
  amount_paid     DECIMAL(10,2) NOT NULL DEFAULT 0,
  balance_due     DECIMAL(10,2) NOT NULL DEFAULT 0,
  payment_terms   TEXT
                    CHECK (payment_terms IN ('due_on_receipt','net_15','net_30','net_45')),
  notes_internal  TEXT,
  notes_customer  TEXT,
  pdf_url         TEXT,
  created_by      UUID          REFERENCES public.users(id),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_invoices_number      ON public.invoices(tenant_id, invoice_number);
CREATE INDEX        idx_invoices_tenant_id   ON public.invoices(tenant_id);
CREATE INDEX        idx_invoices_customer_id ON public.invoices(customer_id);
CREATE INDEX        idx_invoices_status      ON public.invoices(tenant_id, status);
CREATE INDEX        idx_invoices_qbo_id      ON public.invoices(qbo_invoice_id) WHERE qbo_invoice_id IS NOT NULL;
CREATE INDEX        idx_invoices_active      ON public.invoices(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_invoices_updated_at
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Deferred FK: jobs → invoices
ALTER TABLE public.jobs
  ADD CONSTRAINT fk_jobs_invoice_id
  FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);

-- ============================================================
-- TABLE: invoice_line_items
-- Source: 04_object_model.md § 2.12
-- ============================================================
CREATE TABLE public.invoice_line_items (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID          NOT NULL REFERENCES public.tenants(id),
  invoice_id      UUID          NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  job_id          UUID          REFERENCES public.jobs(id),
  service_type_id UUID          REFERENCES public.service_types(id),
  sort_order      INTEGER       NOT NULL DEFAULT 0,
  description     TEXT          NOT NULL,
  quantity        DECIMAL(10,3) NOT NULL DEFAULT 1,
  unit            TEXT,
  unit_price      DECIMAL(10,2) NOT NULL DEFAULT 0,
  line_total      DECIMAL(10,2) NOT NULL DEFAULT 0,
  qbo_item_id     TEXT,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_line_items_invoice_id   ON public.invoice_line_items(invoice_id);
CREATE INDEX idx_invoice_line_items_job_id       ON public.invoice_line_items(job_id) WHERE job_id IS NOT NULL;
CREATE INDEX idx_invoice_line_items_tenant_id    ON public.invoice_line_items(tenant_id);

CREATE TRIGGER trg_invoice_line_items_updated_at
  BEFORE UPDATE ON public.invoice_line_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: payments
-- Source: 04_object_model.md § 2.13
-- ============================================================
CREATE TABLE public.payments (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID          NOT NULL REFERENCES public.tenants(id),
  customer_id      UUID          NOT NULL REFERENCES public.customers(id),
  qbo_payment_id   TEXT,
  qbo_sync_status  TEXT          NOT NULL DEFAULT 'pending'
                     CHECK (qbo_sync_status IN ('synced','pending','error')),
  payment_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
  amount           DECIMAL(10,2) NOT NULL,
  payment_method   TEXT          NOT NULL
                     CHECK (payment_method IN ('check','credit_card','ach','cash','online','other')),
  reference_number TEXT,
  notes            TEXT,
  created_by       UUID          REFERENCES public.users(id),
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_tenant_id    ON public.payments(tenant_id);
CREATE INDEX idx_payments_customer_id  ON public.payments(customer_id);
CREATE INDEX idx_payments_date         ON public.payments(tenant_id, payment_date);

CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: payment_allocations
-- Source: 04_object_model.md § 2.14
-- ============================================================
CREATE TABLE public.payment_allocations (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID          NOT NULL REFERENCES public.tenants(id),
  payment_id     UUID          NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  invoice_id     UUID          NOT NULL REFERENCES public.invoices(id),
  amount_applied DECIMAL(10,2) NOT NULL,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_allocations_payment_id ON public.payment_allocations(payment_id);
CREATE INDEX idx_payment_allocations_invoice_id ON public.payment_allocations(invoice_id);
CREATE INDEX idx_payment_allocations_tenant_id  ON public.payment_allocations(tenant_id);

-- ============================================================
-- TABLE: attachments
-- Source: 04_object_model.md § 2.15
-- Polymorphic: record_type + record_id identify parent
-- ============================================================
CREATE TABLE public.attachments (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID        NOT NULL REFERENCES public.tenants(id),
  record_type     TEXT        NOT NULL
                    CHECK (record_type IN ('job','estimate','invoice','customer','property','asset')),
  record_id       UUID        NOT NULL,
  file_name       TEXT        NOT NULL,
  file_type       TEXT,
  file_size_bytes INTEGER,
  storage_path    TEXT        NOT NULL,
  label           TEXT,
  uploaded_by     UUID        REFERENCES public.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachments_tenant_id ON public.attachments(tenant_id);
CREATE INDEX idx_attachments_record    ON public.attachments(record_type, record_id);

-- ============================================================
-- TABLE: proposals
-- Source: 04_object_model.md § 2.16
-- ============================================================
CREATE TABLE public.proposals (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID          NOT NULL REFERENCES public.tenants(id),
  customer_id      UUID          NOT NULL REFERENCES public.customers(id),
  property_id      UUID          NOT NULL REFERENCES public.properties(id),
  proposal_number  TEXT          NOT NULL,
  title            TEXT,
  status           TEXT          NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','sent','viewed','accepted','declined','expired')),
  cover_letter     TEXT,
  valid_until      DATE,
  total            DECIMAL(10,2) NOT NULL DEFAULT 0,
  pdf_url          TEXT,
  sent_at          TIMESTAMPTZ,
  accepted_at      TIMESTAMPTZ,
  accepted_by_name TEXT,
  notes_internal   TEXT,
  created_by       UUID          REFERENCES public.users(id),
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_proposals_number      ON public.proposals(tenant_id, proposal_number);
CREATE INDEX        idx_proposals_tenant_id   ON public.proposals(tenant_id);
CREATE INDEX        idx_proposals_customer_id ON public.proposals(customer_id);
CREATE INDEX        idx_proposals_status      ON public.proposals(tenant_id, status);
CREATE INDEX        idx_proposals_active      ON public.proposals(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_proposals_updated_at
  BEFORE UPDATE ON public.proposals
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: proposal_estimates  (join table)
-- Source: 05_relationship_map.md § 3.10
-- ============================================================
CREATE TABLE public.proposal_estimates (
  proposal_id UUID    NOT NULL REFERENCES public.proposals(id)  ON DELETE CASCADE,
  estimate_id UUID    NOT NULL REFERENCES public.estimates(id),
  sort_order  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (proposal_id, estimate_id)
);

CREATE INDEX idx_proposal_estimates_estimate_id ON public.proposal_estimates(estimate_id);

-- ============================================================
-- TABLE: notes
-- Source: 04_object_model.md § 2.17
-- Polymorphic: record_type + record_id identify parent
-- ============================================================
CREATE TABLE public.notes (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID        NOT NULL REFERENCES public.tenants(id),
  record_type TEXT        NOT NULL
                CHECK (record_type IN ('customer','property','job','estimate','invoice')),
  record_id   UUID        NOT NULL,
  body        TEXT        NOT NULL,
  is_pinned   BOOLEAN     NOT NULL DEFAULT FALSE,
  created_by  UUID        REFERENCES public.users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notes_tenant_id ON public.notes(tenant_id);
CREATE INDEX idx_notes_record    ON public.notes(record_type, record_id);

CREATE TRIGGER trg_notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLE: qbo_sync_logs
-- Source: 04_object_model.md § 2.18
-- ============================================================
CREATE TABLE public.qbo_sync_logs (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID        NOT NULL REFERENCES public.tenants(id),
  sync_type     TEXT        NOT NULL
                  CHECK (sync_type IN ('customer','invoice','payment','item')),
  direction     TEXT        NOT NULL
                  CHECK (direction IN ('push','pull')),
  record_id     UUID,
  qbo_entity_id TEXT,
  status        TEXT        NOT NULL
                  CHECK (status IN ('success','failed','pending_retry')),
  attempt_count INTEGER     NOT NULL DEFAULT 1,
  error_message TEXT,
  synced_at     TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_qbo_sync_logs_tenant_id  ON public.qbo_sync_logs(tenant_id);
CREATE INDEX idx_qbo_sync_logs_status     ON public.qbo_sync_logs(tenant_id, status);
CREATE INDEX idx_qbo_sync_logs_record_id  ON public.qbo_sync_logs(record_id) WHERE record_id IS NOT NULL;

-- ============================================================
-- ROW LEVEL SECURITY
-- Per: docs/05_relationship_map.md § 4 and docs/02_system_architecture.md
-- Rule: every tenant-scoped table enforces tenant_id = caller's tenant
-- ============================================================

ALTER TABLE public.tenants              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_types        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_templates  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estimates            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estimate_line_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_line_items   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_allocations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proposals            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proposal_estimates   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbo_sync_logs        ENABLE ROW LEVEL SECURITY;

-- ---- tenants ----
CREATE POLICY "tenant_select"
  ON public.tenants FOR SELECT
  USING (id = public.get_user_tenant_id());

CREATE POLICY "tenant_update"
  ON public.tenants FOR UPDATE
  USING (id = public.get_user_tenant_id())
  WITH CHECK (id = public.get_user_tenant_id());

-- ---- users ----
CREATE POLICY "users_select"
  ON public.users FOR SELECT
  USING (tenant_id = public.get_user_tenant_id());

CREATE POLICY "users_insert"
  ON public.users FOR INSERT
  WITH CHECK (tenant_id = public.get_user_tenant_id());

CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---- Standard tenant-isolation policy macro for remaining tables ----
-- customers
CREATE POLICY "tenant_isolation" ON public.customers            FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- properties
CREATE POLICY "tenant_isolation" ON public.properties           FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- assets
CREATE POLICY "tenant_isolation" ON public.assets               FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- service_types
CREATE POLICY "tenant_isolation" ON public.service_types        FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- recurring_templates
CREATE POLICY "tenant_isolation" ON public.recurring_templates  FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- jobs
CREATE POLICY "tenant_isolation" ON public.jobs                 FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- estimates
CREATE POLICY "tenant_isolation" ON public.estimates            FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- estimate_line_items
CREATE POLICY "tenant_isolation" ON public.estimate_line_items  FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- invoices
CREATE POLICY "tenant_isolation" ON public.invoices             FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- invoice_line_items
CREATE POLICY "tenant_isolation" ON public.invoice_line_items   FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- payments
CREATE POLICY "tenant_isolation" ON public.payments             FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- payment_allocations
CREATE POLICY "tenant_isolation" ON public.payment_allocations  FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- proposals
CREATE POLICY "tenant_isolation" ON public.proposals            FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- attachments
CREATE POLICY "tenant_isolation" ON public.attachments          FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- notes
CREATE POLICY "tenant_isolation" ON public.notes                FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());
-- qbo_sync_logs
CREATE POLICY "tenant_isolation" ON public.qbo_sync_logs        FOR ALL USING (tenant_id = public.get_user_tenant_id()) WITH CHECK (tenant_id = public.get_user_tenant_id());

-- proposal_estimates (join table — no tenant_id column; scoped via parent proposal)
CREATE POLICY "tenant_isolation" ON public.proposal_estimates FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.proposals p
      WHERE p.id = proposal_id
        AND p.tenant_id = public.get_user_tenant_id()
    )
  );

-- ============================================================
-- END OF MIGRATION 000001
-- ============================================================
