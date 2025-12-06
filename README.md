# 🎯 Oracle Donation Management System

Full‑stack web application built on a **“thick database” architecture** where most business logic runs inside **Oracle (PL/SQL, triggers, constraints, packages)**, with a modern backend and a simple web frontend.

> Goal: flex Oracle as much as possible (security, integrity, performance, advanced features) while still delivering a clean full‑stack app. 

---

## 🏗️ High‑Level Architecture

- **Frontend**
  - Simple web UI (HTML/JS/Bootstrap or small framework).
  - Role‑based screens: Admin, Organisation, Donor.

- **Backend**
  - REST API (e.g., **FastAPI**) exposing endpoints for:
    - Authentication (`/auth`)
    - Organisations & campaigns (`/organisations`, `/actions`)
    - Needs & inventory (`/needs`)
    - Donations & payment proofs (`/donations`)   

- **Database (Oracle)**
  - “Thick DB” with:
    - Tables, constraints, sequences/identity columns.
    - Triggers (audit, business logic).
    - Stored procedures and PL/SQL packages.
    - Materialized views, data redaction, indexes, Oracle Text (if available).   

---

## 👥 Team & Module Ownership

Each member is a **vertical full‑stack owner** for their module (DB + API + UI). 

| Person  | Module & Scope                                          | Main DB Objects                                                                                         | API / UI Responsibility                                      |
|--------|----------------------------------------------------------|---------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| A      | Environment, Users & Security                            | USERS, ROLES, USER_ROLES, AUDIT_LOG_USERS, SECURITY_PKG, redaction policies, ERROR_LOG                 | Git/GitHub, project board, `/auth/*`, admin security views   |
| B      | Organisations & Campaigns                                | ORGANISATION, ACTION_SOCIAL, campaign constraints, reporting MV (MV_MONTHLY_DONATIONS)                 | `/organisations/*`, `/actions/*`, org dashboard, reports     |
| C      | Needs & Inventory                                       | ITEM_TYPES, BESOIN, virtual columns, search indexes, Oracle Text (if available)                        | `/needs/*`, `/item-types/*`, needs grid, search UI           |
| D      | Donations & Payments                                     | DON, PAYMENT_PROOFS, donation triggers, transaction logic, load testing & concurrency scripts          | `/donations/*`, `/payment-proofs/*`, donation flow UI        |

---

## 📚 Functional Overview

### User Roles

- **Admin**
  - Manage organisations and user roles.
  - View security/audit logs.
  - Access global reports and statistics.

- **Organisation**
  - Manage its profile.
  - Create and manage **campaigns** (social actions).
  - Define **needs** (BESOIN) and monitor fulfillment. 

- **Donor**
  - Browse active campaigns and needs.
  - Make donations and upload payment proofs.
  - See donation history and progress. 

### Core Features

- Registration & login with role assignment.
- Campaign creation with lifecycle states: `DRAFT`, `ACTIVE`, `CLOSED`, `COMPLETED`.
- Needs per campaign with requested quantity, current quantity, and `% fulfilled`.
- Donations linked to users and needs with status and optional payment proof (BLOB path or ref).
- Admin/Org dashboards + donor journey UI.

---

## 🗄️ Oracle Database Design

### Main Tables

- **USERS**
  - Identity primary key.
  - Email (unique), password hash, phone, status, created_at, etc. 
- **ROLES**
  - e.g., `ADMIN`, `ORGANISATION`, `DONOR`.
- **USER_ROLES**
  - Join table mapping users to roles (if many‑to‑many).

- **ORGANISATION**
  - Basic organisation info.
  - Status (`PENDING`, `ACTIVE`, `SUSPENDED`). 

- **ACTION_SOCIAL**
  - Campaigns/social actions.
  - FKs to ORGANISATION, date range, status (`DRAFT`, `ACTIVE`, `CLOSED`, `COMPLETED`).
  - Check constraint `end_date > start_date`. 

- **ITEM_TYPES**
  - Types of items/needs (e.g., food, clothes, money).

- **BESOIN**
  - Need per campaign.
  - FKs to ACTION_SOCIAL and ITEM_TYPES.
  - `quantity_requested`, `quantity_current`.
  - Virtual column `%_fulfilled = quantity_current / quantity_requested * 100`. 

- **DON**
  - Donation records.
  - FKs to USERS (donor) and BESOIN.
  - `amount`, `donation_date`, `payment_status`, extra fields as needed. 

- **PAYMENT_PROOFS**
  - References to proof files/BLOBs linked to DON.

- **AUDIT_LOG_USERS**
  - Log of all changes on USERS. 

- **ERROR_LOG**
  - Centralized error and exception logging.

---

## 🧠 PL/SQL Logic (Stored Procedures & Packages)

### Standalone Procedures

- `SP_REGISTER_USER`
  - Inserts a new user, assigns default role (e.g., DONOR), returns `user_id`. 
- `SP_LOGIN`
  - Validates credentials, returns status and role info, used by backend `/auth/login`. 
- `SP_CREATE_ACTION`
  - Validates organisation status is `ACTIVE` before creating a new campaign. 
- `SP_UPDATE_ACTION_STATUS`
  - Enforces valid status transitions (`DRAFT` → `ACTIVE` → `CLOSED` / `COMPLETED`).
- `SP_ADD_NEED`
  - Adds a need only if action is not `CLOSED` or `COMPLETED`. 
- `SP_UPDATE_NEED_QTY`
  - Allows admin to adjust current quantity with sanity checks.
- `SP_MAKE_DONATION`
  - Inserts donation, coordinates updates, and wraps everything in transaction control (commit/rollback). 

### Packages

- **SECURITY_PKG**
  - Utility functions: `is_admin(p_user_id)`, `has_role(p_user_id, p_role_code)`.
  - Centralized security checks for SPs and triggers.
  - Optionally stores app‑level security constants. 

- **REPORTING_PKG**
  - Helpers for reporting queries (top donors, donations per month, most active organisations).
  - Used by API endpoints for admin/org dashboards.

---

## 🔔 Triggers & Automation

- **AUDIT_USERS_TRG**
  - AFTER INSERT/UPDATE/DELETE on USERS.
  - Writes old/new values, user, timestamp into AUDIT_LOG_USERS. 

- **ACTION_COMPLETE_TRG**
  - Fires on BESOIN changes.
  - If all needs for a given ACTION_SOCIAL reach 100% fulfilled, automatically set action status to `COMPLETED`. 

- **BESOIN_PROTECT_DELETE_TRG**
  - BEFORE DELETE on BESOIN.
  - Prevents deletion if there are related DON rows (raises application error). 

- **DON_UPDATE_NEED_TRG**
  - AFTER INSERT on DON.
  - Increments BESOIN.quantity_current and recalculates `%_fulfilled`. 

---

## 🔐 Security & Data Redaction

- **Oracle Roles (DB‑level)**
  - `APP_ADMIN`, `APP_USER` (and possibly separate schema/technical user). 

- **Application Roles**
  - Stored in ROLES / USER_ROLES tables: `ADMIN`, `ORGANISATION`, `DONOR`.
  - Backend passes user id/role to DB; PL/SQL checks via `SECURITY_PKG`. 

- **Data Redaction / Masking**
  - Use **DBMS_REDACT** policies to mask phone/email for non‑admin sessions.
  - Or complementary views (e.g. `USERS_MASKED`) to expose partially hidden data. 

---

## 📊 Reporting & Performance

- **Materialized View**
  - `MV_MONTHLY_DONATIONS`:
    - Summarizes donations by month, organisation, and/or action.
    - Periodic or on‑demand refresh for demo. 

- **Indexes**
  - Index on USERS.email for fast login.
  - Indexes on FK columns (org_id, action_id, user_id, besoin_id).
  - Function‑based index on lowercased description for search. 

- **Oracle Text (if available)**
  - Full‑text search on needs and campaigns descriptions:
    - `CONTAINS(description, ...)` in search endpoints. 

- **EXPLAIN PLAN**
  - Captured for key queries:
    - Listing actions, needs search, reporting queries.
  - Used in documentation to show performance decisions and index usage. 

---

## 🌐 API Overview (Examples)

- **Auth**
  - `POST /auth/register` → calls `SP_REGISTER_USER`.
  - `POST /auth/login` → calls `SP_LOGIN`, returns JWT/token. 

- **Organisations & Actions**
  - `GET /organisations`
  - `POST /organisations`
  - `GET /actions`
  - `POST /actions`
  - `PATCH /actions/{id}/status` → uses `SP_UPDATE_ACTION_STATUS`. 

- **Needs & Inventory**
  - `GET /actions/{id}/needs`
  - `POST /actions/{id}/needs` → uses `SP_ADD_NEED`.
  - `GET /search/needs?q=...` → uses indexed/Oracle Text search. 

- **Donations**
  - `POST /donations` → uses `SP_MAKE_DONATION`.
  - `GET /donations/mine`
  - `POST /payment-proofs` (upload/link proof). 

- **Reporting**
  - `GET /reports/monthly-donations` → materialized view.
  - `GET /reports/underfunded-needs` → REPORTING_PKG queries. 

---

## 🧪 Testing & Demo Scenarios

- **Test Data**
  - PL/SQL or scripts to generate:
    - Hundreds of users, organisations, campaigns, needs, and donations. 

- **Concurrency Demo**
  - Script simulating many donations (e.g., loop or parallel sessions) to test locks and transaction handling in `SP_MAKE_DONATION`. 

- **Demo Walkthroughs**
  1. **Admin story**
     - Logs in, sees masked vs unmasked data, views audit logs and reports.
  2. **Organisation story**
     - Creates campaign, adds needs, tracks fulfillment, views monthly donations.
  3. **Donor story**
     - Registers, logs in, donates, sees progress bars and history.

---

## 📄 Documentation

- **Architecture Diagram**
  - Frontend ↔ Backend ↔ Oracle DB (thick database).

- **ER Diagram**
  - All tables with keys and relationships.

- **Oracle Object Inventory**
  - List of:
    - Tables
    - Views & materialized views
    - Triggers
    - Procedures & packages
    - Policies and indexes 

- **Design Rationale**
  - Why certain logic is in PL/SQL (DB) vs backend.
  - Trade‑offs between triggers, constraints, and application logic.
  - Security decisions (DBMS_REDACT, roles) and performance choices (indexes, MV).

---

## 🧰 Project Setup (High‑Level)

- **Prerequisites**
  - Oracle Database (12c+ recommended).
  - Python + FastAPI (or chosen backend framework).
  - Node/PNPM/Yarn (if using a JS build system).
  - Git & GitHub access.

- **Steps**
  1. Clone repository and set environment variables (`.env`).
  2. Run Oracle schema script (DDL).
  3. Run PL/SQL scripts for procedures, packages, triggers, MV.
  4. Seed test data.
  5. Start backend server.
  6. Open frontend and start exploring the flows.

---

> This project is intentionally heavy on Oracle to demonstrate capabilities: constraints, triggers, PL/SQL packages, redaction, materialized views, and indexing strategies, all integrated in a real full‑stack web app.

