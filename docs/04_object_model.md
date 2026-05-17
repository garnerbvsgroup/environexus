---
title: Object Model
version: 0.1
last_updated: 2026-05-13
status: DRAFT
---

# EnviroNexus SaaS — Object Model

---

## 1. Overview

This document defines the core domain objects for EnviroNexus SaaS, their attributes, and their data types. This is the authoritative reference for all schema definitions. No AI tool or developer may introduce attributes, objects, or relationships not defined here without first updating this document and logging the change in `99_system_log.md`.

All objects use:
- UUID primary keys (generated server-side)
- `tenant_id` for multi-tenant data isolation (where applicable)
- Soft delete via `deleted_at` timestamp
- Audit columns: `created_at`, `updated_at`, `created_by`, `updated_by`

---

## 2. Core Domain Objects

---

### 2.1 Tenant

Represents a subscribing business. The root of all multi-tenant data.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `name` | TEXT | Business/company name |
| `slug` | TEXT | URL-safe unique identifier |
| `logo_url` | TEXT | Supabase Storage path |
| `primary_color` | TEXT | Hex color for white-labeling |
| `subscription_plan` | TEXT | `trial`, `starter`, `growth`, `enterprise` |
| `subscription_status` | TEXT | `active`, `past_due`, `cancelled`, `trialing` |
| `trial_ends_at` | TIMESTAMPTZ | Null after trial conversion |
| `qbo_realm_id` | TEXT | QBO Company ID; null if not connected |
| `qbo_connected` | BOOLEAN | Whether QBO OAuth is active |
| `timezone` | TEXT | IANA timezone string (e.g., `America/New_York`) |
| `address_line1` | TEXT | |
| `address_line2` | TEXT | |
| `city` | TEXT | |
| `state` | TEXT | Two-letter state code |
| `zip` | TEXT | |
| `phone` | TEXT | |
| `email` | TEXT | Primary business contact email |
| `website` | TEXT | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete |

---

### 2.2 User

A human user of the platform, always scoped to a Tenant.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK; matches Supabase Auth `auth.users.id` |
| `tenant_id` | UUID | FK → Tenant |
| `email` | TEXT | Auth email |
| `first_name` | TEXT | |
| `last_name` | TEXT | |
| `phone` | TEXT | Mobile phone for SMS notifications |
| `role` | TEXT | `owner`, `admin`, `office_manager`, `dispatcher`, `crew_lead`, `field_crew` |
| `is_active` | BOOLEAN | Deactivated users cannot log in |
| `avatar_url` | TEXT | Supabase Storage path |
| `default_view` | TEXT | `dashboard`, `schedule`, `jobs` — user preference |
| `receive_sms` | BOOLEAN | Opt-in for SMS job notifications |
| `receive_email` | BOOLEAN | Opt-in for email notifications |
| `last_login_at` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete |

---

### 2.3 Customer

A client of the tenant. May have one or many Properties. Syncs to QBO.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `qbo_customer_id` | TEXT | QBO Customer ID; null until synced |
| `qbo_sync_status` | TEXT | `synced`, `pending`, `error`, `not_linked` |
| `display_name` | TEXT | Used in UI and on invoices |
| `company_name` | TEXT | Optional; for commercial customers |
| `first_name` | TEXT | |
| `last_name` | TEXT | |
| `customer_type` | TEXT | `residential`, `commercial`, `hoa`, `municipal` |
| `status` | TEXT | `active`, `inactive`, `prospect`, `on_hold` |
| `email` | TEXT | Primary email |
| `email_cc` | TEXT[] | Additional CC email addresses |
| `phone_primary` | TEXT | |
| `phone_secondary` | TEXT | |
| `billing_address_line1` | TEXT | |
| `billing_address_line2` | TEXT | |
| `billing_city` | TEXT | |
| `billing_state` | TEXT | |
| `billing_zip` | TEXT | |
| `billing_same_as_property` | BOOLEAN | If true, billing address mirrors primary property |
| `payment_terms` | TEXT | `due_on_receipt`, `net_15`, `net_30`, `net_45` |
| `default_tax_code` | TEXT | QBO-linked tax code |
| `balance_owing` | DECIMAL(10,2) | Computed; not stored — derived from invoices |
| `source` | TEXT | `website`, `referral`, `google`, `canvass`, `other` |
| `notes` | TEXT | Internal notes; not visible to customer |
| `tags` | TEXT[] | Flexible labels (e.g., `priority`, `seasonal-only`) |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete |

---

### 2.4 Property (Site)

A physical location associated with a Customer. Customers may have multiple properties. Services and Jobs are performed at a Property.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `name` | TEXT | Friendly name (e.g., "Front Yard," "Commercial Lot B") |
| `address_line1` | TEXT | |
| `address_line2` | TEXT | |
| `city` | TEXT | |
| `state` | TEXT | |
| `zip` | TEXT | |
| `latitude` | DECIMAL(9,6) | Geocoded |
| `longitude` | DECIMAL(9,6) | Geocoded |
| `property_type` | TEXT | `residential`, `commercial`, `hoa_common`, `municipal` |
| `lot_size_sqft` | DECIMAL(10,2) | Used in pricing calculations |
| `lot_size_acres` | DECIMAL(8,4) | Computed or manually entered |
| `irrigated` | BOOLEAN | |
| `gate_code` | TEXT | Access information for crew |
| `access_notes` | TEXT | |
| `is_primary` | BOOLEAN | Marks the primary property for a customer |
| `status` | TEXT | `active`, `inactive` |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete |

---

### 2.5 Asset

A trackable physical asset on a Property (tree, shrub, irrigation zone, structure). Core to arborist and plant health care workflows.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `property_id` | UUID | FK → Property |
| `asset_type` | TEXT | `tree`, `shrub`, `lawn_zone`, `irrigation_zone`, `structure`, `other` |
| `common_name` | TEXT | e.g., "Sugar Maple" |
| `scientific_name` | TEXT | e.g., "Acer saccharum" |
| `dbh_inches` | DECIMAL(6,2) | Diameter at breast height (trees) |
| `height_ft` | DECIMAL(6,2) | |
| `spread_ft` | DECIMAL(6,2) | |
| `condition` | TEXT | `excellent`, `good`, `fair`, `poor`, `critical`, `dead` |
| `location_on_property` | TEXT | Free text (e.g., "front left corner") |
| `latitude` | DECIMAL(9,6) | GPS-tagged location |
| `longitude` | DECIMAL(9,6) | |
| `planted_date` | DATE | |
| `last_serviced_date` | DATE | |
| `next_service_date` | DATE | |
| `notes` | TEXT | |
| `attributes` | JSONB | Flexible key-value for additional species/care data |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete |

---

### 2.6 ServiceType

A catalog of the services the tenant offers. Linked to QBO items for financial sync.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `name` | TEXT | e.g., "Lawn Fertilization," "Tree Pruning" |
| `category` | TEXT | `lawn_care`, `landscaping`, `tree_care`, `snow_ice`, `general_contracting`, `other` |
| `description` | TEXT | |
| `default_unit` | TEXT | `per_visit`, `per_sqft`, `per_hour`, `per_item`, `flat` |
| `default_price` | DECIMAL(10,2) | |
| `qbo_item_id` | TEXT | Linked QBO Service Item ID |
| `qbo_income_account` | TEXT | QBO Chart of Accounts mapping |
| `is_recurring_eligible` | BOOLEAN | Can this service be part of a recurring template? |
| `is_active` | BOOLEAN | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

---

### 2.7 RecurringTemplate

Defines the schedule and parameters for auto-generating recurring Jobs. The engine that drives subscription-style green industry services.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `property_id` | UUID | FK → Property |
| `service_type_id` | UUID | FK → ServiceType |
| `name` | TEXT | e.g., "2026 Lawn Fertilization Program — 6-App" |
| `status` | TEXT | `active`, `paused`, `completed`, `cancelled` |
| `frequency_type` | TEXT | `weekly`, `biweekly`, `monthly`, `every_n_days`, `seasonal`, `custom` |
| `frequency_interval` | INTEGER | Used when `frequency_type = every_n_days` |
| `season_start_month` | INTEGER | 1–12; for seasonal programs |
| `season_end_month` | INTEGER | 1–12 |
| `occurrences_total` | INTEGER | Total number of visits in the program; null = indefinite |
| `occurrences_completed` | INTEGER | Counter; auto-incremented on job completion |
| `schedule_start_date` | DATE | First job generation date |
| `schedule_end_date` | DATE | Null for indefinite programs |
| `preferred_day_of_week` | INTEGER | 0=Sunday, 6=Saturday; nullable |
| `assigned_crew_id` | UUID | FK → User (crew lead); default assignment |
| `estimated_duration_minutes` | INTEGER | |
| `price_per_visit` | DECIMAL(10,2) | |
| `billing_cycle` | TEXT | `per_visit`, `monthly`, `program_advance`, `program_completion` |
| `notes` | TEXT | |
| `attributes` | JSONB | Service-specific configuration (e.g., application type, product) |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete (pauses generation) |

---

### 2.8 Job (Work Order)

A discrete, schedulable unit of work assigned to a crew. May be generated from a RecurringTemplate or created manually.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `property_id` | UUID | FK → Property |
| `service_type_id` | UUID | FK → ServiceType |
| `recurring_template_id` | UUID | FK → RecurringTemplate; null for one-off jobs |
| `estimate_id` | UUID | FK → Estimate; null if not estimate-originated |
| `job_number` | TEXT | Human-readable sequential identifier (e.g., `J-2026-00142`) |
| `title` | TEXT | |
| `status` | TEXT | `scheduled`, `en_route`, `in_progress`, `completed`, `invoiced`, `cancelled`, `on_hold` |
| `priority` | TEXT | `low`, `normal`, `high`, `urgent` |
| `scheduled_date` | DATE | |
| `scheduled_start_time` | TIME | |
| `scheduled_end_time` | TIME | |
| `actual_start_time` | TIMESTAMPTZ | GPS or manual check-in |
| `actual_end_time` | TIMESTAMPTZ | GPS or manual check-out |
| `assigned_crew_lead_id` | UUID | FK → User |
| `assigned_crew_members` | UUID[] | Array of User IDs |
| `instructions` | TEXT | Crew-facing work instructions |
| `completion_notes` | TEXT | Field crew notes on completion |
| `customer_signature_url` | TEXT | Storage path |
| `gps_checkin_lat` | DECIMAL(9,6) | |
| `gps_checkin_lng` | DECIMAL(9,6) | |
| `gps_checkout_lat` | DECIMAL(9,6) | |
| `gps_checkout_lng` | DECIMAL(9,6) | |
| `duration_actual_minutes` | INTEGER | Computed from actual start/end |
| `duration_estimated_minutes` | INTEGER | |
| `invoice_id` | UUID | FK → Invoice; populated after invoicing |
| `attributes` | JSONB | Service-specific job data (products used, sq ft treated, etc.) |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | Soft delete |

---

### 2.9 Estimate

A priced scope of work presented to a Customer for approval. May convert to one or more Jobs upon acceptance.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `property_id` | UUID | FK → Property |
| `estimate_number` | TEXT | Sequential identifier (e.g., `EST-2026-00089`) |
| `title` | TEXT | |
| `status` | TEXT | `draft`, `sent`, `viewed`, `accepted`, `declined`, `expired`, `converted` |
| `valid_until` | DATE | Expiry date |
| `sent_at` | TIMESTAMPTZ | |
| `viewed_at` | TIMESTAMPTZ | |
| `accepted_at` | TIMESTAMPTZ | |
| `accepted_by_name` | TEXT | Name of person who accepted (e-signature) |
| `accepted_ip_address` | TEXT | IP address at acceptance (audit trail) |
| `subtotal` | DECIMAL(10,2) | Sum of line items before tax/discount |
| `discount_type` | TEXT | `flat`, `percent`, null |
| `discount_value` | DECIMAL(10,2) | |
| `tax_rate` | DECIMAL(5,4) | e.g., 0.0875 = 8.75% |
| `tax_amount` | DECIMAL(10,2) | |
| `total` | DECIMAL(10,2) | |
| `notes_internal` | TEXT | Not visible on customer-facing PDF |
| `notes_customer` | TEXT | Printed on estimate PDF |
| `pdf_url` | TEXT | Generated PDF storage path |
| `created_by` | UUID | FK → User |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | |

---

### 2.10 EstimateLineItem

Individual priced items within an Estimate.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `estimate_id` | UUID | FK → Estimate |
| `service_type_id` | UUID | FK → ServiceType; nullable |
| `sort_order` | INTEGER | Display order |
| `description` | TEXT | |
| `quantity` | DECIMAL(10,3) | |
| `unit` | TEXT | `each`, `sqft`, `hour`, `lb`, `bag`, `linear_ft`, etc. |
| `unit_price` | DECIMAL(10,2) | |
| `line_total` | DECIMAL(10,2) | Computed: quantity × unit_price |
| `is_optional` | BOOLEAN | Allows optional add-ons in proposals |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

---

### 2.11 Invoice

A financial document sent to the Customer for payment. Syncs to QBO.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `qbo_invoice_id` | TEXT | QBO Invoice ID after sync |
| `qbo_sync_status` | TEXT | `synced`, `pending`, `error`, `not_linked` |
| `invoice_number` | TEXT | Sequential identifier (e.g., `INV-2026-00234`) |
| `status` | TEXT | `draft`, `approved`, `sent`, `partial`, `paid`, `void`, `overdue` |
| `invoice_date` | DATE | |
| `due_date` | DATE | |
| `sent_at` | TIMESTAMPTZ | |
| `subtotal` | DECIMAL(10,2) | |
| `discount_type` | TEXT | `flat`, `percent`, null |
| `discount_value` | DECIMAL(10,2) | |
| `tax_rate` | DECIMAL(5,4) | |
| `tax_amount` | DECIMAL(10,2) | |
| `total` | DECIMAL(10,2) | |
| `amount_paid` | DECIMAL(10,2) | Sum of applied payments |
| `balance_due` | DECIMAL(10,2) | Computed: total − amount_paid |
| `payment_terms` | TEXT | Inherited from Customer; overridable |
| `notes_internal` | TEXT | |
| `notes_customer` | TEXT | Printed on invoice |
| `pdf_url` | TEXT | |
| `created_by` | UUID | FK → User |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | |

---

### 2.12 InvoiceLineItem

Individual line items on an Invoice.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `invoice_id` | UUID | FK → Invoice |
| `job_id` | UUID | FK → Job; nullable (not all invoice lines are job-linked) |
| `service_type_id` | UUID | FK → ServiceType; nullable |
| `sort_order` | INTEGER | |
| `description` | TEXT | |
| `quantity` | DECIMAL(10,3) | |
| `unit` | TEXT | |
| `unit_price` | DECIMAL(10,2) | |
| `line_total` | DECIMAL(10,2) | |
| `qbo_item_id` | TEXT | Passed to QBO line item |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

---

### 2.13 Payment

A payment record applied to one or more Invoices. May originate in QBO and sync back.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `qbo_payment_id` | TEXT | QBO Payment ID |
| `qbo_sync_status` | TEXT | `synced`, `pending`, `error` |
| `payment_date` | DATE | |
| `amount` | DECIMAL(10,2) | |
| `payment_method` | TEXT | `check`, `credit_card`, `ach`, `cash`, `online`, `other` |
| `reference_number` | TEXT | Check number or transaction ref |
| `notes` | TEXT | |
| `created_by` | UUID | FK → User |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

---

### 2.14 PaymentAllocation

Maps a Payment to one or more Invoices (supports partial payments and multi-invoice payments).

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `payment_id` | UUID | FK → Payment |
| `invoice_id` | UUID | FK → Invoice |
| `amount_applied` | DECIMAL(10,2) | |
| `created_at` | TIMESTAMPTZ | |

---

### 2.15 Attachment

A file attached to any major record (Job, Estimate, Invoice, Customer, Property, Asset).

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `record_type` | TEXT | `job`, `estimate`, `invoice`, `customer`, `property`, `asset` |
| `record_id` | UUID | Polymorphic FK to the parent record |
| `file_name` | TEXT | Original file name |
| `file_type` | TEXT | MIME type |
| `file_size_bytes` | INTEGER | |
| `storage_path` | TEXT | Supabase Storage path |
| `label` | TEXT | User-assigned label (e.g., "Before Photo," "Signed Proposal") |
| `uploaded_by` | UUID | FK → User |
| `created_at` | TIMESTAMPTZ | |

---

### 2.16 Proposal

A customer-facing document combining one or more Estimates into a branded presentation. Extends the Estimate for larger or multi-phase projects.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `customer_id` | UUID | FK → Customer |
| `property_id` | UUID | FK → Property |
| `proposal_number` | TEXT | Sequential identifier |
| `title` | TEXT | |
| `status` | TEXT | `draft`, `sent`, `viewed`, `accepted`, `declined`, `expired` |
| `cover_letter` | TEXT | Rich text; rendered in PDF |
| `valid_until` | DATE | |
| `total` | DECIMAL(10,2) | Sum of all linked estimates |
| `pdf_url` | TEXT | |
| `sent_at` | TIMESTAMPTZ | |
| `accepted_at` | TIMESTAMPTZ | |
| `accepted_by_name` | TEXT | |
| `notes_internal` | TEXT | |
| `created_by` | UUID | FK → User |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |
| `deleted_at` | TIMESTAMPTZ | |

---

### 2.17 Note

A time-stamped internal note attached to any major record.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `record_type` | TEXT | `customer`, `property`, `job`, `estimate`, `invoice` |
| `record_id` | UUID | Polymorphic FK |
| `body` | TEXT | |
| `is_pinned` | BOOLEAN | Pinned notes appear at the top of the note list |
| `created_by` | UUID | FK → User |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

---

### 2.18 QBOSyncLog

Audit log for all QuickBooks Online synchronization events.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tenant_id` | UUID | FK → Tenant |
| `sync_type` | TEXT | `customer`, `invoice`, `payment`, `item` |
| `direction` | TEXT | `push`, `pull` |
| `record_id` | UUID | FK to the synced local record |
| `qbo_entity_id` | TEXT | QBO ID of the synced entity |
| `status` | TEXT | `success`, `failed`, `pending_retry` |
| `attempt_count` | INTEGER | |
| `error_message` | TEXT | |
| `synced_at` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | |

---

## 3. JSONB Attribute Conventions

The `attributes` JSONB column on Jobs and RecurringTemplates stores service-specific structured data that is not universal enough to warrant a dedicated column. Standard keys by service category:

### Lawn Care
```json
{
  "application_number": 3,
  "product_applied": "Pre-emergent + Fertilizer 19-0-6",
  "rate_per_1000sqft": "3.5 lbs",
  "area_treated_sqft": 8500,
  "soil_temp_at_application": "52°F",
  "watered_in": true
}
```

### Tree Care
```json
{
  "asset_ids": ["uuid-1", "uuid-2"],
  "work_type": "pruning",
  "pruning_type": "crown_reduction",
  "debris_disposal": "hauled_away",
  "chip_drop_on_site": false,
  "isc_standards_followed": true
}
```

### Irrigation
```json
{
  "zones_serviced": [1, 2, 3, 5],
  "heads_replaced": 2,
  "system_status_after": "operational",
  "winterized": false
}
```
