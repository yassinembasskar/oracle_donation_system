-- ============================================================
-- TRIGGER: TRG_PROTECT_DELETE
-- Prevent delete FK
-- ============================================================

CREATE OR REPLACE TRIGGER trg_besoin_on_delete_set_deleted
BEFORE DELETE ON Besoin
FOR EACH ROW
BEGIN
  -- Re-point all related donations to the special 'deleted besoin'
  UPDATE Don
     SET id_besoin = 1
   WHERE id_besoin = :OLD.id_besoin;
END;
/
SHOW ERRORS;

CREATE OR REPLACE TRIGGER trg_user_on_delete_set_deleted
BEFORE DELETE ON Utilisateur
FOR EACH ROW
BEGIN
  UPDATE Don
     SET id_donateur = 1
   WHERE id_donateur = :OLD.id_user;

  UPDATE Organisation
     SET id_user_owner = 1
   WHERE id_user_owner = :OLD.id_user;
END;
/
SHOW ERRORS;

CREATE OR REPLACE TRIGGER trg_org_on_delete_set_deleted
BEFORE DELETE ON Organisation
FOR EACH ROW
BEGIN
  UPDATE Action_social
     SET id_org = 1
   WHERE id_org = :OLD.id_org;
END;
/
SHOW ERRORS;

CREATE OR REPLACE TRIGGER trg_action_on_delete_set_deleted
BEFORE DELETE ON Action_social
FOR EACH ROW
BEGIN

  UPDATE Besoin
     SET id_action = 1
   WHERE id_action = :OLD.id_action;

  UPDATE Don
     SET id_besoin = 1
   WHERE id_besoin IN (
           SELECT id_besoin
             FROM Besoin
            WHERE id_action = 1
        );
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: TRG_ACTION_COMPLETE
-- When all besoins of an action are full, mark the action COMPLETED
-- ============================================================

CREATE OR REPLACE TRIGGER TRG_ACTION_COMPLETE
AFTER INSERT OR UPDATE ON Besoin
FOR EACH ROW
DECLARE
    v_action_id      Action_social.id_action%TYPE;
    v_not_full_count NUMBER;
BEGIN
    v_action_id := :NEW.id_action;

    -- Count besoins that are NOT at 100% for this action
    SELECT COUNT(*)
    INTO v_not_full_count
    FROM Besoin
    WHERE id_action = v_action_id
      AND (pourcentage_rempli < 100 OR pourcentage_rempli IS NULL);

    IF v_not_full_count = 0 THEN
        UPDATE Action_social
        SET statut_action = 'COMPLETED'
        WHERE id_action = v_action_id
          AND statut_action <> 'COMPLETED';
    END IF;
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: TRG_ORGANISATION_AUDITS
-- ============================================================

CREATE OR REPLACE TRIGGER trg_organisation_audit
AFTER INSERT OR UPDATE OR DELETE
ON Organisation
FOR EACH ROW
DECLARE
  v_old_values  VARCHAR2(2000);
  v_new_values  VARCHAR2(2000);
  v_operation   VARCHAR2(10);
BEGIN
  IF UPDATING THEN
    v_operation := 'UPDATE';
    v_old_values :=
         'id_org='        || :OLD.id_org
      || ';nom_org='      || :OLD.nom_org
      || ';statut_org='   || :OLD.statut_org
      || ';id_user_owner='|| :OLD.id_user_owner;

    v_new_values :=
         'id_org='        || :NEW.id_org
      || ';nom_org='      || :NEW.nom_org
      || ';statut_org='   || :NEW.statut_org
      || ';id_user_owner='|| :NEW.id_user_owner;
      
  END IF;

  INSERT INTO Business_Log_Audit (
    table_name,
    record_pk,
    operation,
    old_values,
    new_values,
    changed_by,
    change_date
  ) VALUES (
    ORA_DICT_OBJ_NAME,
    NVL(:NEW.id_org, :OLD.id_org),
    v_operation,
    v_old_values,
    v_new_values,
    NVL(SYS_CONTEXT('APP_CTX','USER_EMAIL'), USER),
    SYSDATE
  );
END;
/
SHOW ERRORS;


-- ============================================================
-- TRIGGER: TRG_ORGANISATION_STATUS_VALIDATION
-- ============================================================

CREATE OR REPLACE TRIGGER trg_organisation_status_validation
BEFORE UPDATE OF statut_org
ON Organisation
FOR EACH ROW
DECLARE
      e_invalid_status EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_invalid_status, -20001);
BEGIN
      IF :OLD.statut_org = :NEW.statut_org THEN
        RETURN;
      END IF;
      
      IF NOT (
            (:OLD.statut_org = 'PENDING'   AND :NEW.statut_org IN ('ACTIVE','SUSPENDED'))
         OR (:OLD.statut_org = 'ACTIVE'    AND :NEW.statut_org = 'SUSPENDED')
         OR (:OLD.statut_org = 'SUSPENDED' AND :NEW.statut_org = 'ACTIVE')
      ) THEN
        RAISE_APPLICATION_ERROR(
          -20001,
          'Invalid organisation status transition: '
          || :OLD.statut_org || ' -> ' || :NEW.statut_org
        );
      END IF;
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: TRG_ACTION_AUDIT
-- ============================================================
create or replace TRIGGER trg_action_audit
AFTER INSERT OR UPDATE OR DELETE
ON Action_social
FOR EACH ROW
DECLARE
  v_old_values  VARCHAR2(2000);
  v_new_values  VARCHAR2(2000);
  v_operation VARCHAR(10);
BEGIN
  IF UPDATING THEN
    v_operation := 'UPDATE';
    v_old_values :=
         'id_action='        || :OLD.id_action
      || ';id_org='          || :OLD.id_org
      || ';titre_action='    || :OLD.titre_action
      || ';statut_action='   || :OLD.statut_action
      || ';date_debut='      || TO_CHAR(:OLD.date_debut_action,'YYYY-MM-DD')
      || ';date_fin='        || TO_CHAR(:OLD.date_fin_action,'YYYY-MM-DD');

    v_new_values :=
         'id_action='        || :NEW.id_action
      || ';id_org='          || :NEW.id_org
      || ';titre_action='    || :NEW.titre_action
      || ';statut_action='   || :NEW.statut_action
      || ';date_debut='      || TO_CHAR(:NEW.date_debut_action,'YYYY-MM-DD')
      || ';date_fin='        || TO_CHAR(:NEW.date_fin_action,'YYYY-MM-DD');

  ELSIF DELETING THEN
    v_operation := 'DELETE';
    v_old_values :=
         'id_action='        || :OLD.id_action
      || ';id_org='          || :OLD.id_org
      || ';titre_action='    || :OLD.titre_action
      || ';statut_action='   || :OLD.statut_action
      || ';date_debut='      || TO_CHAR(:OLD.date_debut_action,'YYYY-MM-DD')
      || ';date_fin='        || TO_CHAR(:OLD.date_fin_action,'YYYY-MM-DD');
  END IF;

  INSERT INTO Business_Log_Audit (
    table_name,
    record_pk,
    operation,
    old_values,
    new_values,
    changed_by,
    change_date
  ) VALUES (
    ORA_DICT_OBJ_NAME,
    NVL(:NEW.id_org, :OLD.id_org),
    v_operation,
    v_old_values,
    v_new_values,
    NVL(SYS_CONTEXT('APP_CTX','USER_EMAIL'), USER),
    SYSDATE
  );
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: TRG_ACTION_STATUS_VALIDATION
-- ============================================================

CREATE OR REPLACE TRIGGER trg_action_status_validation
BEFORE UPDATE OF statut_action
ON Action_social
FOR EACH ROW
BEGIN
  IF :OLD.statut_action = :NEW.statut_action THEN
    RETURN;
  END IF;

  -- DRAFT -> ACTIVE
  -- ACTIVE -> CLOSED or COMPLETED
  -- CLOSED -> COMPLETED (optional)
  IF NOT (
        (:OLD.statut_action = 'DRAFT' AND :NEW.statut_action = 'ACTIVE')
     OR (:OLD.statut_action = 'ACTIVE' AND :NEW.statut_action IN ('CLOSED','COMPLETED'))
     OR (:OLD.statut_action = 'CLOSED' AND :NEW.statut_action = 'COMPLETED')
  ) THEN
    RAISE_APPLICATION_ERROR(
      -20002,
      'Invalid action status transition: '
      || :OLD.statut_action || ' -> ' || :NEW.statut_action
    );
  END IF;
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: TRG_ACTION_AUTO_CLOSE
-- ============================================================

CREATE OR REPLACE TRIGGER trg_action_auto_close
BEFORE INSERT OR UPDATE ON Action_social
FOR EACH ROW
BEGIN
  IF :NEW.statut_action = 'ACTIVE'
     AND :NEW.date_fin_action < SYSDATE THEN
    :NEW.statut_action := 'CLOSED';
  END IF;
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: TRG_BESOIN_AUDIT
-- ============================================================

create or replace TRIGGER trg_besoin_audit
AFTER INSERT OR UPDATE OR DELETE
ON Besoin
FOR EACH ROW
DECLARE
  v_old_values  VARCHAR2(2000);
  v_new_values  VARCHAR2(2000);
  v_operation VARCHAR2(10);
BEGIN

  IF UPDATING THEN
    v_operation := 'UPDATE';
    v_old_values :=
         'id_besoin='        || :OLD.id_besoin
      || ';id_action='       || :OLD.id_action
      || ';nom_besoin='      || :OLD.nom_besoin
      || ';unite_demande='   || :OLD.unite_demande
      || ';unite_recue='     || :OLD.unite_recue;

    v_new_values :=
         'id_besoin='        || :NEW.id_besoin
      || ';id_action='       || :NEW.id_action
      || ';nom_besoin='      || :NEW.nom_besoin
      || ';unite_demande='   || :NEW.unite_demande
      || ';unite_recue='     || :NEW.unite_recue;

  ELSIF DELETING THEN
    v_operation := 'DELETE';
    v_old_values :=
         'id_besoin='        || :OLD.id_besoin
      || ';id_action='       || :OLD.id_action
      || ';nom_besoin='      || :OLD.nom_besoin
      || ';unite_demande='   || :OLD.unite_demande
      || ';unite_recue='     || :OLD.unite_recue;
  END IF;

  INSERT INTO Business_Log_Audit(
      table_name,
      record_pk,
      operation,
      old_values,
      new_values,
      changed_by,
      change_date
    ) VALUES (
      'Besoin',
      NVL(:NEW.id_besoin, :OLD.id_besoin),
      v_operation,
      v_old_values,
      v_new_values,
      NVL(
        SYS_CONTEXT('APP_CTX','USER_EMAIL'),
        SYS_CONTEXT('USERENV','SESSION_USER')
      ),
      SYSDATE
    );

END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: trg_don_prevent_closed_campaign
-- ============================================================

CREATE OR REPLACE TRIGGER trg_don_prevent_closed_campaign
BEFORE INSERT
ON Don
FOR EACH ROW
DECLARE
  v_statut_action Action_social.statut_action%TYPE;
BEGIN
  SELECT a.statut_action
  INTO   v_statut_action
  FROM   Besoin b
  JOIN   Action_social a
    ON   a.id_action = b.id_action
  WHERE  b.id_besoin = :NEW.id_besoin;

  IF v_statut_action IN ('CLOSED','COMPLETED') THEN
    RAISE_APPLICATION_ERROR(
      -20003,
      'Cannot donate to a closed or completed campaign.'
    );
  END IF;
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: trg_don_audit
-- ============================================================

CREATE OR REPLACE TRIGGER trg_don_audit
AFTER INSERT OR UPDATE OR DELETE
ON Don
FOR EACH ROW
DECLARE
  v_old_values  VARCHAR2(2000);
  v_new_values  VARCHAR2(2000);
  v_operation VARCHAR2(10);
BEGIN
  IF UPDATING THEN
    v_operation := 'UPDATE';
    v_old_values :=
         'id_don='       || :OLD.id_don
      || ';id_donateur=' || :OLD.id_donateur
      || ';id_besoin='   || :OLD.id_besoin
      || ';montant_don=' || :OLD.montant_don
      || ';statut_don='  || :OLD.statut_don;

    v_new_values :=
         'id_don='       || :NEW.id_don
      || ';id_donateur=' || :NEW.id_donateur
      || ';id_besoin='   || :NEW.id_besoin
      || ';montant_don=' || :NEW.montant_don
      || ';statut_don='  || :NEW.statut_don;

  ELSIF DELETING THEN
    v_operation := 'DELETE';
    v_old_values :=
         'id_don='       || :OLD.id_don
      || ';id_donateur=' || :OLD.id_donateur
      || ';id_besoin='   || :OLD.id_besoin
      || ';montant_don=' || :OLD.montant_don
      || ';statut_don='  || :OLD.statut_don;
  END IF;

  INSERT INTO Business_Log_Audit(
    table_name,
    record_pk,
    operation,
    old_values,
    new_values,
    changed_by,
    change_date
  ) VALUES (
    'Don',
    NVL(:NEW.id_don, :OLD.id_don),
    v_operation,
    v_old_values,
    v_new_values,
    NVL(
        SYS_CONTEXT('APP_CTX','USER_EMAIL'),
        SYS_CONTEXT('USERENV','SESSION_USER')
      ),
    SYSDATE
  );
END;
/
SHOW ERRORS;

-- ============================================================
-- TRIGGER: trg_payment_proofs_audit
-- ============================================================

CREATE OR REPLACE TRIGGER trg_payment_proofs_audit
AFTER INSERT OR UPDATE OR DELETE
ON Payment_Proofs
FOR EACH ROW
DECLARE
  v_old_values  VARCHAR2(2000);
  v_new_values  VARCHAR2(2000);
  v_operation VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_operation := 'INSERT';
    v_new_values :=
         'id_proof='    || :NEW.id_proof
      || ';id_don='     || :NEW.id_don
      || ';file_name='  || :NEW.file_name
      || ';file_type='  || :NEW.file_type;

  ELSIF UPDATING THEN
    v_operation := 'UPDATE';
    v_old_values :=
         'id_proof='    || :OLD.id_proof
      || ';id_don='     || :OLD.id_don
      || ';file_name='  || :OLD.file_name
      || ';file_type='  || :OLD.file_type;

    v_new_values :=
         'id_proof='    || :NEW.id_proof
      || ';id_don='     || :NEW.id_don
      || ';file_name='  || :NEW.file_name
      || ';file_type='  || :NEW.file_type;

  ELSIF DELETING THEN
    v_operation := 'DELETE';
    v_old_values :=
         'id_proof='    || :OLD.id_proof
      || ';id_don='     || :OLD.id_don
      || ';file_name='  || :OLD.file_name
      || ';file_type='  || :OLD.file_type;
  END IF;

  INSERT INTO Business_Log_Audit(
    table_name,
    record_pk,
    operation,
    old_values,
    new_values,
    changed_by,
    change_date
  ) VALUES (
    'Payment_Proofs',
    NVL(:NEW.id_proof, :OLD.id_proof),
    v_operation,
    v_old_values,
    v_new_values,
    NVL(
        SYS_CONTEXT('APP_CTX','USER_EMAIL'),
        SYS_CONTEXT('USERENV','SESSION_USER')
      ),
    SYSDATE
  );
END;
/
SHOW ERRORS;


-- ============================================================
-- TRIGGER: trg_global_error_log
-- ============================================================
/*
ALTER SESSION SET CONTAINER = XEPDB1;
GRANT ADMINISTER DATABASE TRIGGER TO donation_app;
*/

CREATE OR REPLACE TRIGGER trg_global_error_log
AFTER SERVERERROR
ON DATABASE
DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;

  v_err_code    VARCHAR2(20);
  v_err_stack   VARCHAR2(2000);
  v_backtrace   VARCHAR2(2000);
  v_user        VARCHAR2(100);
  v_module      VARCHAR2(48);
  v_machine     VARCHAR2(64);
  v_osuser      VARCHAR2(64);
  v_details     VARCHAR2(2000);
BEGIN
  -- Basic info
  v_err_code  := TO_CHAR(SQLCODE);
  v_err_stack := DBMS_UTILITY.format_error_stack;
  v_backtrace := DBMS_UTILITY.format_error_backtrace;

  -- Session context
  v_user    := NVL(SYS_CONTEXT('APP_CTX','USER_EMAIL'),
                   SYS_CONTEXT('USERENV','SESSION_USER'));
  v_module  := SYS_CONTEXT('USERENV','MODULE');
  v_machine := SYS_CONTEXT('USERENV','HOST');
  v_osuser  := SYS_CONTEXT('USERENV','OS_USER');

  -- Optional: avoid logging non‑application schemas
  IF SYS_CONTEXT('USERENV','SESSION_USER') IN ('SYS','SYSTEM') THEN
    RETURN;
  END IF;

  -- Avoid recursive logging on the log table itself
  IF ORA_DICT_OBJ_NAME = 'ERROR_LOG' THEN
    RETURN;
  END IF;

  -- Build compact details payload
  v_details :=
        'user='    || v_user
     || ';module=' || v_module
     || ';machine='|| v_machine
     || ';osuser=' || v_osuser
     || ';backtrace=' || SUBSTR(v_backtrace, 1, 1000);

  INSERT INTO Error_Log (
    error_code,
    error_message,
    source_procedure,
    error_date,
    details
  ) VALUES (
    v_err_code,
    SUBSTR(v_err_stack, 1, 500),
    v_module,
    SYSDATE,
    v_details
  );

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    -- Never let an error propagate from a SERVERERROR trigger
    NULL;
END;
/
SHOW ERRORS;