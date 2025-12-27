-- ============================================================
-- INDEXES for Performance
-- ============================================================

CREATE INDEX idx_organisation_owner ON Organisation(id_user_owner);
CREATE INDEX idx_action_org ON Action_social(id_org);
CREATE INDEX idx_besoin_action ON Besoin(id_action);
CREATE INDEX idx_don_donateur ON Don(id_donateur);
CREATE INDEX idx_don_besoin ON Don(id_besoin);
CREATE INDEX idx_payment_proof_don ON Payment_Proofs(id_don);

CREATE INDEX idx_audit_business_record ON Business_Log_Audit(record_pk);
CREATE INDEX idx_audit_business_table ON Business_Log_Audit(table_name);
CREATE INDEX idx_audit_business_changer ON Business_Log_Audit(changed_by);

CREATE INDEX idx_don_date ON Don(date_don);
CREATE INDEX idx_action_date ON Action_social(date_debut_action, date_fin_action);