-- ============================================================
-- TRIGGER: TRG_AUDIT_UTILISATEUR
-- Audits INSERT/UPDATE/DELETE on Utilisateur
-- ============================================================

CREATE OR REPLACE TRIGGER TRG_AUDIT_UTILISATEUR
AFTER INSERT OR UPDATE OR DELETE ON Utilisateur
FOR EACH ROW
DECLARE
    v_operation   VARCHAR2(20);
    v_old_values  VARCHAR2(2000);
    v_new_values  VARCHAR2(2000);
    v_user_id     NUMBER;
BEGIN
    IF INSERTING THEN
        v_operation  := 'INSERT';
        v_old_values := NULL;
        v_new_values :=
              'nom=' || :NEW.nom_user
           || ', email=' || :NEW.email_user
           || ', tel=' || :NEW.tel_user
           || ', statut=' || :NEW.statut_user;

        v_user_id := :NEW.id_user;

    ELSIF UPDATING THEN
        v_operation  := 'UPDATE';
        v_old_values :=
              'nom=' || :OLD.nom_user
           || ', email=' || :OLD.email_user
           || ', tel=' || :OLD.tel_user
           || ', statut=' || :OLD.statut_user;

        v_new_values :=
              'nom=' || :NEW.nom_user
           || ', email=' || :NEW.email_user
           || ', tel=' || :NEW.tel_user
           || ', statut=' || :NEW.statut_user;

        v_user_id := :OLD.id_user;

    ELSIF DELETING THEN
        v_operation  := 'DELETE';
        v_old_values :=
              'nom=' || :OLD.nom_user
           || ', email=' || :OLD.email_user
           || ', tel=' || :OLD.tel_user
           || ', statut=' || :OLD.statut_user;

        v_new_values := NULL;
        v_user_id := :OLD.id_user;
    END IF;

    INSERT INTO Audit_Log_Utilisateur (
        id_user,
        operation,
        old_values,
        new_values,
        changed_by,
        change_date
    ) VALUES (
        v_user_id,
        v_operation,
        v_old_values,
        v_new_values,
        USER,
        SYSDATE
    );
END;
/
SHOW ERRORS;


-- ============================================================
-- TRIGGER: TRG_BESOIN_PROTECT_DELETE
-- Prevent delete of Besoin when Don rows exist
-- ============================================================

CREATE OR REPLACE TRIGGER TRG_BESOIN_PROTECT_DELETE
BEFORE DELETE ON Besoin
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Don
    WHERE id_besoin = :OLD.id_besoin;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Impossible de supprimer ce besoin: des dons y sont déjà associés.'
        );
    END IF;
END;
/
SHOW ERRORS;


-- ============================================================
-- TRIGGER: TRG_DON_UPDATE_NEED
-- After a donation, update Besoin.unite_recue
-- ============================================================

CREATE OR REPLACE TRIGGER TRG_DON_UPDATE_NEED
AFTER INSERT ON Don
FOR EACH ROW
DECLARE
    v_status   VARCHAR2(50);
    v_message  VARCHAR2(200);
    v_delta    NUMBER;
BEGIN
    -- Example logic: 1 unité pour 100 de montant
    v_delta := FLOOR(:NEW.montant_don / 100);

    IF v_delta IS NULL OR v_delta <= 0 THEN
        RETURN; -- no impact on quantity
    END IF;

    SP_UPDATE_NEED_QTY(
        p_besoin_id => :NEW.id_besoin,
        p_delta     => v_delta,
        p_status    => v_status,
        p_message   => v_message
    );

    IF v_status <> 'OK' THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Echec de mise à jour du besoin: ' || v_message
        );
    END IF;
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

