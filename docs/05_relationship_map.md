---
title: Relationship Map
version: 0.1
last_updated: 2026-05-13
status: DRAFT
---

# EnviroNexus SaaS — Relationship Map

---

## 1. Overview

This document defines how all core domain objects relate to each other — including cardinality, directionality, and the business rules that govern each relationship. This is the authoritative reference for foreign key design and data integrity rules.

All relationships are scoped within a single Tenant unless explicitly noted.

---

## 2. Entity Relationship Diagram

```
Tenant
  │
  ├──< User (many users per tenant)
  │
  ├──< Customer (many customers per tenant)
  │       │
  │       ├──< Property (many properties per customer)
  │       │       │
  │       │       ├──< Asset (many assets per property)
  │       │       │
  │       │       ├──< RecurringTemplate (many recurring templates per property)
  │       │       │       │
  │       │       │       └──< Job [generated] (many jobs from one template)
  │       │       │
  │       │       └──< Job (many one-off jobs per property)
  │       │
  │       ├──< Estimate (many estimates per customer)
  │       │       │
  │       │       ├──< EstimateLineItem (many line items per estimate)
  │       │       └──> Job [converts to] (estimate → one or many jobs)
  │       │
  │       ├──< Proposal (many proposals per customer)
  │       │       └──< Estimate [linked] (one or many estimates per proposal)
  │       │
  │       ├──< Invoice (many invoices per customer)
  │       │       │
  │       │       ├──< InvoiceLineItem (many line items per invoice)
  │       │       └──< Job [source] (one or many jobs per invoice)
  │       │
  │       └──< Payment (many payments per customer)
  │               └──< PaymentAllocation (many allocations per payment)
  │                       └──> Invoice (payment allocated to invoices)
  │
  ├──< ServiceType (many service types per tenant; catalog)
  │
  └──< QBOSyncLog (audit log per tenant)

Attachment (polymorphic → Job | Estimate | Invoice | Customer | Property | Asset)
Note      (polymorphic → Job | Estimate | Invoice | Customer | Property)
```

---

## 3. Relationship Definitions

---

### 3.1 Tenant → User
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | A Tenant has one or more Users. A User belongs to exactly one Tenant. |
| **Business rule** | A User cannot access data from any Tenant other than their own (`tenant_id` RLS enforced at the database layer). |
| **Delete behavior** | Soft delete. Deactivating a user (`is_active = false`) revokes access without destroying their records. |

---

### 3.2 Tenant → Customer
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | A Tenant has many Customers. A Customer belongs to exactly one Tenant. |
| **Business rule** | Customer records are never shared across Tenants. Customer email uniqueness is enforced per Tenant only (not globally). |
| **Delete behavior** | Soft delete. Customers with open Invoices or active Jobs cannot be hard deleted. |

---

### 3.3 Customer → Property
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | A Customer may have one or many Properties. A Property belongs to exactly one Customer. |
| **Business rule** | Every Customer must have at least one Property before a Job or RecurringTemplate can be created for them. Exactly one Property must be marked `is_primary = true`. |
| **Delete behavior** | Soft delete. Properties with active Jobs or RecurringTemplates cannot be deactivated without resolving dependencies. |

---

### 3.4 Property → Asset
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | A Property may have zero or many Assets (trees, shrubs, irrigation zones, etc.). An Asset belongs to exactly one Property. |
| **Business rule** | Assets are referenced by Jobs and RecurringTemplates via the `attributes.asset_ids` JSONB field. No hard FK to Asset from Job (assets are informational references, not scheduling constraints). |
| **Delete behavior** | Soft delete. Service history for an asset is preserved even after the asset is marked inactive (e.g., tree removed). |

---

### 3.5 Customer → RecurringTemplate (via Property)
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many (Customer has many recurring templates) |
| **Description** | A RecurringTemplate is always scoped to one Customer and one Property. A single Customer may have multiple active RecurringTemplates across multiple services and properties. |
| **Business rule** | A RecurringTemplate must reference exactly one ServiceType. A RecurringTemplate in `active` status will generate Jobs automatically per its schedule. Pausing a template halts job generation without affecting existing scheduled Jobs. |
| **Delete behavior** | Soft delete on RecurringTemplate cancels future job generation. Previously generated Jobs are not deleted. |

---

### 3.6 RecurringTemplate → Job
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | A RecurringTemplate generates many Jobs over its lifetime. Each generated Job carries a reference to its parent RecurringTemplate via `recurring_template_id`. |
| **Business rule** | Jobs generated from a RecurringTemplate inherit `property_id`, `customer_id`, `service_type_id`, `assigned_crew_lead_id`, `estimated_duration_minutes`, and `price` from the template at the time of generation. Changes to the template after generation do not retroactively update generated Jobs. |
| **Generation trigger** | Edge Function runs daily and generates Jobs for all active templates where the next scheduled date equals today. |

---

### 3.7 Customer → Job (One-Off Jobs)
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | Jobs may also be created manually (no recurring template) for one-off work orders. |
| **Business rule** | A Job must always reference a Customer and a Property. A Job may optionally reference an Estimate (if estimate-originated). |

---

### 3.8 Estimate → EstimateLineItem
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | An Estimate contains one or many EstimateLineItems. A LineItem belongs to exactly one Estimate. |
| **Business rule** | An Estimate must have at least one LineItem to be sent to a Customer. Totals (`subtotal`, `tax_amount`, `total`) are computed from line items and stored for performance. |
| **Delete behavior** | Deleting an Estimate hard-deletes its line items (they have no independent existence). |

---

### 3.9 Estimate → Job (Conversion)
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many (one estimate can generate multiple jobs) |
| **Description** | When an Estimate is accepted, it may be converted to one or more Jobs. The conversion maps estimate line items to job work. |
| **Business rule** | An Estimate's status changes to `converted` upon job creation. An Estimate in `converted` status is read-only. The `estimate_id` FK on each generated Job records the source. |

---

### 3.10 Proposal → Estimate
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | A Proposal may contain one or many linked Estimates (e.g., a multi-phase landscape proposal). |
| **Join table** | `proposal_estimates` (proposal_id, estimate_id, sort_order) |
| **Business rule** | An Estimate may appear in only one Proposal at a time. Accepting a Proposal accepts all linked Estimates simultaneously. |

---

### 3.11 Invoice → InvoiceLineItem
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many |
| **Description** | An Invoice contains one or many InvoiceLineItems. |
| **Business rule** | Invoice totals are computed from line items. A line item may reference a Job (`job_id`) to link billing to fieldwork. Not all line items must be job-linked (e.g., material charges, retainers). |

---

### 3.12 Job → Invoice (Invoicing)
| Property | Value |
|---|---|
| **Cardinality** | Many-to-One (many jobs can appear on one invoice) |
| **Description** | One or many completed Jobs may be collected onto a single Invoice (batch invoicing). A Job carries an `invoice_id` FK once it is invoiced. |
| **Business rule** | A Job with status `completed` is eligible for invoicing. Once a Job is linked to an Invoice, it moves to `invoiced` status and cannot be added to another Invoice. |

---

### 3.13 Payment → PaymentAllocation → Invoice
| Property | Value |
|---|---|
| **Cardinality** | Many-to-Many (via PaymentAllocation join table) |
| **Description** | A Payment may be allocated across one or many Invoices. An Invoice may receive allocations from one or many Payments. |
| **Business rule** | The sum of all `PaymentAllocation.amount_applied` for a Payment must not exceed `Payment.amount`. The `Invoice.amount_paid` is derived from the sum of all allocations against it. |
| **QBO sync** | Payment allocations are mirrored in QBO's linked transactions structure. |

---

### 3.14 Attachment (Polymorphic)
| Property | Value |
|---|---|
| **Cardinality** | Many-to-One (many attachments per parent record) |
| **Parent types** | `job`, `estimate`, `invoice`, `customer`, `property`, `asset` |
| **Description** | An Attachment belongs to one record of one type. The `record_type` + `record_id` pair identifies the parent. |
| **Business rule** | Attachments are stored in Supabase Storage. Deleting the parent record does not automatically delete storage files — a cleanup function must be invoked. |

---

### 3.15 Note (Polymorphic)
| Property | Value |
|---|---|
| **Cardinality** | Many-to-One (many notes per parent record) |
| **Parent types** | `customer`, `property`, `job`, `estimate`, `invoice` |
| **Business rule** | Notes are internal only. They are never exposed in customer-facing documents or the customer portal. |

---

### 3.16 ServiceType → RecurringTemplate / Job / EstimateLineItem / InvoiceLineItem
| Property | Value |
|---|---|
| **Cardinality** | One-to-Many (each ServiceType referenced by many records) |
| **Business rule** | ServiceType is a tenant-level catalog. Deleting a ServiceType is prohibited if it is referenced by any active Job, RecurringTemplate, or open Invoice. Instead, mark it `is_active = false` to prevent new use. |

---

## 4. Key Business Rules Summary

| Rule | Description |
|---|---|
| **Tenant isolation** | No object can belong to more than one Tenant. All cross-tenant data access is prohibited at the database layer. |
| **Customer → Property prerequisite** | No Job, Estimate, or RecurringTemplate can be created without a Customer and a Property. |
| **Soft delete standard** | Core objects (Customer, Property, Job, Invoice, RecurringTemplate) are never hard-deleted in production. |
| **Invoice immutability** | An Invoice in `paid` or `void` status cannot be edited. A new credit memo must be issued to adjust a paid invoice. |
| **Recurring template immutability of history** | Editing a RecurringTemplate does not alter previously generated Jobs. Changes apply to future generations only. |
| **Job invoicing exclusivity** | A completed Job can appear on exactly one Invoice. |
| **Estimate conversion lock** | An Estimate in `converted` status is read-only. |
| **QBO sync integrity** | Every Invoice pushed to QBO records the QBO Invoice ID. Duplicate pushes are prevented by checking for an existing `qbo_invoice_id`. |
| **Payment balance constraint** | A Payment's total allocations cannot exceed the payment amount. Partial payments leave Invoice balance open. |
| **Property primary address** | Exactly one Property per Customer must be `is_primary = true`. Enforced by application logic (not a DB constraint). |
