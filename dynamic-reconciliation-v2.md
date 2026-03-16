# Dynamic DSL Reconciliation Framework — Canonical Architecture

## 1. Purpose
This document defines the architecture for the dynamic reconciliation
framework that compares DSL (flattened JSON) data against any external
system (Onyx, ArcGIS, WinCan, etc.).

Reconciliation direction is always:

    DSL  →  Target System

DSL is the canonical, BIAN-aligned truth snapshot.
All reconciliations use DSL as the left-hand side.

The architecture is:
- deterministic
- metadata-driven
- system-agnostic
- domain/entity-agnostic
- scalable
- sponsor-grade
- audit-safe

Once all systems reshape their data to the DSL grain, the engine becomes
fully dynamic with no join rules, no polymorphism, and no entity-specific SQL.

---

## 2. Metadata Model (System-Agnostic)

The metadata model supports reconciliation against any system.

Fields:

- domain
- entity
- system_name
- dsl_attribute
- system_attribute
- is_key
- reconciliation_type
- is_active

### Example (bian_mappings.csv)

domain,entity,system_name,dsl_attribute,system_attribute,is_key,reconciliation_type,is_active
Party,Customer,Onyx,partyReferenceId,partyReferenceId,Y,EXACT,Y
Party
