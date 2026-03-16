# Dynamic BIAN Reconciliation — Simplified Architecture

## 1. Overview
This reconciliation engine compares DSL (flattened JSON) data with Onyx CRM data using a fully metadata‑driven approach.

The key architectural principle:
**Both DSL and Onyx must be reshaped to the same BIAN domain/entity grain.**

Once the grain is aligned:
- Join rules disappear
- crm_key_type disappears
- mapping_rule disappears
- Polymorphic logic disappears
- Reconciliation becomes fully dynamic

---

## 2. Metadata Model
Only attribute mappings are required:

domain  
entity  
dsl_attribute  
onyx_attribute  
is_key  
reconciliation_type  
is_active  

No join rules.  
No key types.  
No conditional logic.

---

## 3. Onyx Source Views
Onyx raw tables are reshaped into domain/entity‑specific staging views:

stg_onyx_party_customer  
stg_onyx_party_address  
stg_onyx_party_email  
stg_onyx_party_phone  

Each view:
- filters by type  
- exposes partyReferenceId  
- aligns with DSL grain  

---

## 4. Join Logic
All reconciliations use the same join:

ON dsl.partyReferenceId = onyx.partyReferenceId

---

## 5. Comparison Logic
Driven entirely by reconciliation_type:

- EXACT  
- NORMALIZED  
- DATE_ONLY  

---

## 6. Reconciliation Output
The engine produces a metadata‑only mismatch ledger:

domain  
entity  
primary_key_hash  
attribute_name  
reconciliation_type  
match_status  
mismatch_reason  
run_timestamp  

No values stored.

---

## 7. Summary
By aligning Onyx to the DSL grain, the reconciliation engine becomes:

- deterministic  
- metadata‑driven  
- domain‑agnostic  
- scalable  
- sponsor‑grade  

No join rules.  
No polymorphism.  
No complexity.  
