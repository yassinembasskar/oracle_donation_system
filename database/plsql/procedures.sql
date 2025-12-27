CREATE OR REPLACE PROCEDURE SP_CREATE_ORGANISATION (
    p_owner_id    IN Utilisateur.id_user%TYPE,
    p_nom_org     IN VARCHAR2,
    p_desc_org    IN VARCHAR2,
    p_tel_org     IN VARCHAR2,
    p_num_patente IN VARCHAR2,
    p_lieu_org    IN VARCHAR2,
    p_id_org      OUT Organisation.id_org%TYPE,
    p_status      OUT VARCHAR2,
    p_message     OUT VARCHAR2
) AS
    v_err_code VARCHAR2(50);
    v_err_msg  VARCHAR2(500);
BEGIN
    p_id_org := NULL;
    p_status := 'ERROR';
    p_message := 'UNKNOWN_ERROR';

    IF NOT has_role(p_owner_id, 'ORG') THEN
        p_status  := 'NO_ORG_ROLE';
        p_message := 'User is not allowed to create organisations.';
        RETURN;
    END IF;

    INSERT INTO Organisation (
        id_user_owner, nom_org, desc_org, tel_org,
        num_patente, lieu_org, statut_org
    ) VALUES (
        p_owner_id, p_nom_org, p_desc_org, p_tel_org,
        p_num_patente, p_lieu_org, 'PENDING'
    )
    RETURNING id_org INTO p_id_org;

    p_status  := 'OK';
    p_message := 'Organisation created successfully.';
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code,
            error_message,
            source_procedure,
            error_date,
            details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_CREATE_ORGANISATION',
            SYSDATE,
            'owner_id=' || TO_CHAR(p_owner_id) ||
            ', nom_org=' || p_nom_org ||
            ', num_patente=' || p_num_patente
        );

        p_id_org := NULL;
        p_status := 'ORG_ALREADY_EXISTS';
        p_message := 'An organisation with the same unique data already exists.';
    WHEN OTHERS THEN
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code,
            error_message,
            source_procedure,
            error_date,
            details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_CREATE_ORGANISATION',
            SYSDATE,
            'owner_id=' || TO_CHAR(p_owner_id) ||
            ', nom_org=' || p_nom_org
        );

        p_id_org := NULL;
        p_status := 'ERROR';
        p_message := 'Unexpected error: ' || v_err_msg;
END SP_CREATE_ORGANISATION;
/
SHOW ERRORS;


CREATE OR REPLACE PROCEDURE SP_CREATE_ACTION (
    p_user_id           IN Utilisateur.id_user%TYPE,
    p_org_id            IN Organisation.id_org%TYPE,
    p_titre_action      IN VARCHAR2,
    p_desc_action       IN VARCHAR2,
    p_affiche_action    IN VARCHAR2,
    p_date_debut_action IN DATE,
    p_date_fin_action   IN DATE,
    p_montant_objectif  IN NUMBER,
    p_id_action         OUT Action_social.id_action%TYPE,
    p_status            OUT VARCHAR2,
    p_message           OUT VARCHAR2
) AS
    v_owner_id   Organisation.id_user_owner%TYPE;
    v_statut_org Organisation.statut_org%TYPE;
    v_err_code   VARCHAR2(50);
    v_err_msg    VARCHAR2(500);
BEGIN
    p_id_action := NULL;
    p_status    := 'ERROR';
    p_message   := 'UNKNOWN_ERROR';

    IF p_montant_objectif IS NOT NULL AND p_montant_objectif <= 0 THEN
        p_status  := 'INVALID_AMOUNT';
        p_message := 'Objective amount must be positive.';
        RETURN;
    END IF;

    SELECT id_user_owner, statut_org
      INTO v_owner_id, v_statut_org
      FROM Organisation
     WHERE id_org = p_org_id;

    IF v_statut_org <> 'ACTIVE' THEN
        p_status  := 'ORG_INACTIVE';
        p_message := 'Organisation is not active.';
        RETURN;
    END IF;

    IF p_user_id <> v_owner_id THEN
        p_status  := 'NOT_ORG_OWNER';
        p_message := 'User is not allowed to create actions for this organisation.';
        RETURN;
    END IF;

    INSERT INTO Action_social (
        id_org, titre_action, desc_action, affiche_action,
        date_debut_action, date_fin_action,
        montant_objectif_action, montant_recu_action,
        statut_action
    ) VALUES (
        p_org_id, p_titre_action, p_desc_action, p_affiche_action,
        p_date_debut_action, p_date_fin_action,
        p_montant_objectif, 0,
        'DRAFT'
    )
    RETURNING id_action INTO p_id_action;

    p_status  := 'OK';
    p_message := 'Action created successfully.';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_id_action := NULL;
        p_status    := 'ERROR';
        p_message   := 'Organisation not found.';
    WHEN OTHERS THEN
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code,
            error_message,
            source_procedure,
            error_date,
            details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_CREATE_ACTION',
            SYSDATE,
            'user_id=' || TO_CHAR(p_user_id) ||
            ', org_id=' || TO_CHAR(p_org_id)
        );

        p_id_action := NULL;
        p_status    := 'ERROR';
        p_message   := 'Unexpected error: ' || v_err_msg;
END SP_CREATE_ACTION;
/
SHOW ERRORS;

CREATE OR REPLACE PROCEDURE SP_UPDATE_ACTION_STATUS (
    p_user_id    IN Utilisateur.id_user%TYPE,
    p_action_id  IN Action_social.id_action%TYPE,
    p_new_status IN VARCHAR2,
    p_status     OUT VARCHAR2,
    p_message    OUT VARCHAR2
) AS
    v_old_status Action_social.statut_action%TYPE;
    v_org_id     Action_social.id_org%TYPE;
    v_owner_id   Organisation.id_user_owner%TYPE;
    v_err_code   VARCHAR2(50);
    v_err_msg    VARCHAR2(500);
BEGIN
    p_status  := 'ERROR';
    p_message := 'UNKNOWN_ERROR';

    IF p_new_status NOT IN ('DRAFT','ACTIVE','CLOSED','COMPLETED') THEN
        p_status  := 'INVALID_STATUS';
        p_message := 'New status is not allowed.';
        RETURN;
    END IF;

    SELECT statut_action, id_org
      INTO v_old_status, v_org_id
      FROM Action_social
     WHERE id_action = p_action_id;

    SELECT id_user_owner
      INTO v_owner_id
      FROM Organisation
     WHERE id_org = v_org_id;

    IF NOT (p_user_id = v_owner_id OR has_role(p_user_id, 'ADMIN')) THEN
        p_status  := 'NOT_AUTHORIZED';
        p_message := 'User not allowed to change status.';
        RETURN;
    END IF;

    IF v_old_status = 'DRAFT' AND p_new_status <> 'ACTIVE' THEN
        p_status  := 'INVALID_TRANSITION';
        p_message := 'DRAFT can only go to ACTIVE.';
        RETURN;
    ELSIF v_old_status = 'ACTIVE' AND p_new_status NOT IN ('CLOSED', 'COMPLETED') THEN
        p_status  := 'INVALID_TRANSITION';
        p_message := 'ACTIVE can only go to CLOSED or COMPLETED.';
        RETURN;
    END IF;

    UPDATE Action_social
       SET statut_action = p_new_status
     WHERE id_action = p_action_id;

    p_status  := 'OK';
    p_message := 'Status updated successfully.';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_status  := 'ERROR';
        p_message := 'Action or organisation not found.';
    WHEN OTHERS THEN
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code, error_message, source_procedure, error_date, details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_UPDATE_ACTION_STATUS',
            SYSDATE,
            'user_id=' || TO_CHAR(p_user_id) ||
            ', action_id=' || TO_CHAR(p_action_id) ||
            ', new_status=' || p_new_status
        );

        p_status  := 'ERROR';
        p_message := 'Unexpected error: ' || v_err_msg;
END SP_UPDATE_ACTION_STATUS;
/
SHOW ERRORS;


CREATE OR REPLACE PROCEDURE SP_ADD_NEED (
    p_user_id       IN Utilisateur.id_user%TYPE,
    p_action_id     IN Action_social.id_action%TYPE,
    p_nom_besoin    IN VARCHAR2,
    p_description   IN VARCHAR2,
    p_type_besoin   IN VARCHAR2,
    p_unite_demande IN NUMBER,
    p_prix_unitaire IN NUMBER,
    p_id_besoin     OUT Besoin.id_besoin%TYPE,
    p_status        OUT VARCHAR2,
    p_message       OUT VARCHAR2
) AS
    v_statut_action Action_social.statut_action%TYPE;
    v_org_id        Action_social.id_org%TYPE;
    v_owner_id      Organisation.id_user_owner%TYPE;
    v_err_code      VARCHAR2(50);
    v_err_msg       VARCHAR2(500);
BEGIN
    p_id_besoin := NULL;
    p_status    := 'ERROR';
    p_message   := 'UNKNOWN_ERROR';

    IF p_unite_demande IS NULL OR p_unite_demande <= 0 THEN
        p_status  := 'INVALID_DATA';
        p_message := 'Requested units must be positive.';
        RETURN;
    END IF;

    SELECT statut_action, id_org
      INTO v_statut_action, v_org_id
      FROM Action_social
     WHERE id_action = p_action_id;

    IF v_statut_action IN ('CLOSED', 'COMPLETED') THEN
        p_status  := 'ACTION_CLOSED';
        p_message := 'Cannot add needs to closed/completed action.';
        RETURN;
    END IF;

    SELECT id_user_owner
      INTO v_owner_id
      FROM Organisation
     WHERE id_org = v_org_id;

    IF NOT (p_user_id = v_owner_id OR has_role(p_user_id, 'ADMIN')) THEN
        p_status  := 'NOT_AUTHORIZED';
        p_message := 'User not allowed to add needs for this action.';
        RETURN;
    END IF;

    INSERT INTO Besoin (
        id_action, nom_besoin, description_besoin, type_besoin,
        unite_demande, unite_recue, prix_unitaire, statut_besoin
    ) VALUES (
        p_action_id, p_nom_besoin, p_description, p_type_besoin,
        p_unite_demande, 0, p_prix_unitaire, 'EN_COURS'
    )
    RETURNING id_besoin INTO p_id_besoin;

    p_status  := 'OK';
    p_message := 'Need created successfully.';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_status  := 'ERROR';
        p_message := 'Action or organisation not found.';
    WHEN OTHERS THEN
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code, error_message, source_procedure, error_date, details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_ADD_NEED',
            SYSDATE,
            'user_id=' || TO_CHAR(p_user_id) ||
            ', action_id=' || TO_CHAR(p_action_id) ||
            ', nom_besoin=' || p_nom_besoin
        );

        p_id_besoin := NULL;
        p_status    := 'ERROR';
        p_message   := 'Unexpected error: ' || v_err_msg;
END SP_ADD_NEED;
/
SHOW ERRORS;

CREATE OR REPLACE PROCEDURE SP_UPDATE_NEED_QTY (
    p_user_id   IN Utilisateur.id_user%TYPE,
    p_besoin_id IN Besoin.id_besoin%TYPE,
    p_delta     IN NUMBER,
    p_status    OUT VARCHAR2,
    p_message   OUT VARCHAR2
) AS
    v_current   Besoin.unite_recue%TYPE;
    v_new       Besoin.unite_recue%TYPE;
    v_owner_id  Organisation.id_user_owner%TYPE;
    v_err_code  VARCHAR2(50);
    v_err_msg   VARCHAR2(500);
BEGIN
    p_status  := 'ERROR';
    p_message := 'UNKNOWN_ERROR';

    IF p_delta IS NULL THEN
        p_status  := 'INVALID_DATA';
        p_message := 'Delta quantity is required.';
        RETURN;
    END IF;

    SELECT b.unite_recue,
           o.id_user_owner
      INTO v_current,
           v_owner_id
      FROM Besoin        b
      JOIN Action_social a ON a.id_action = b.id_action
      JOIN Organisation  o ON o.id_org    = a.id_org
     WHERE b.id_besoin = p_besoin_id;

    IF NOT (p_user_id = v_owner_id OR has_role(p_user_id, 'ADMIN')) THEN
        p_status  := 'NOT_AUTHORIZED';
        p_message := 'User not allowed to update this need.';
        RETURN;
    END IF;

    v_new := v_current + p_delta;

    IF v_new < 0 THEN
        p_status  := 'NEGATIVE_QTY';
        p_message := 'New quantity cannot be negative.';
        RETURN;
    END IF;

    UPDATE Besoin
       SET unite_recue = v_new
     WHERE id_besoin   = p_besoin_id;

    p_status  := 'OK';
    p_message := 'Quantity updated successfully.';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_status  := 'ERROR';
        p_message := 'Besoin or related organisation not found.';
    WHEN OTHERS THEN
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code, error_message, source_procedure, error_date, details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_UPDATE_NEED_QTY',
            SYSDATE,
            'user_id='    || TO_CHAR(p_user_id)   ||
            ', besoin_id=' || TO_CHAR(p_besoin_id) ||
            ', delta='    || TO_CHAR(p_delta)
        );

        p_status  := 'ERROR';
        p_message := 'Unexpected error: ' || v_err_msg;
END SP_UPDATE_NEED_QTY;
/
SHOW ERRORS;

CREATE OR REPLACE PROCEDURE SP_MAKE_DONATION (
    p_donor_id    IN Utilisateur.id_user%TYPE,
    p_besoin_id   IN Besoin.id_besoin%TYPE,
    p_montant_don IN NUMBER,
    p_preuve_don  IN VARCHAR2,
    p_statut_don  IN VARCHAR2 DEFAULT 'PENDING',
    p_id_don      OUT Don.id_don%TYPE,
    p_status      OUT VARCHAR2,
    p_message     OUT VARCHAR2
) AS
    v_statut_user Utilisateur.statut_user%TYPE;
    v_status_qty  VARCHAR2(50);
    v_msg_qty     VARCHAR2(200);
    v_err_code    VARCHAR2(50);
    v_err_msg     VARCHAR2(500);
BEGIN
    p_id_don := NULL;
    p_status := 'ERROR';
    p_message := 'UNKNOWN_ERROR';

    IF p_montant_don IS NULL OR p_montant_don <= 0 THEN
        p_status  := 'INVALID_AMOUNT';
        p_message := 'Donation amount must be positive.';
        RETURN;
    END IF;

    IF p_statut_don NOT IN ('PENDING','CONFIRMED','REJECTED') THEN
        p_status  := 'INVALID_STATUS';
        p_message := 'Donation status value is not allowed.';
        RETURN;
    END IF;

    SELECT statut_user
      INTO v_statut_user
      FROM Utilisateur
     WHERE id_user = p_donor_id;

    IF v_statut_user <> 'ACTIVE' THEN
        p_status  := 'USER_INACTIVE';
        p_message := 'Donor is not active.';
        RETURN;
    END IF;

    IF NOT has_role(p_donor_id, 'DONOR') THEN
        p_status  := 'USER_NOT_DONOR';
        p_message := 'User does not have DONOR role.';
        RETURN;
    END IF;

    SAVEPOINT sp_before_donation;

    INSERT INTO Don (
        id_donateur, id_besoin, montant_don,
        date_don, statut_don, preuve_don
    ) VALUES (
        p_donor_id, p_besoin_id, p_montant_don,
        SYSDATE, p_statut_don, p_preuve_don
    )
    RETURNING id_don INTO p_id_don;

    SP_UPDATE_NEED_QTY(
        p_donor_id,              -- or owner/admin id, depending on rule
        p_besoin_id,
        FLOOR(p_montant_don / 100),
        v_status_qty,
        v_msg_qty
    );

    IF v_status_qty <> 'OK' THEN
        ROLLBACK TO sp_before_donation;
        p_id_don := NULL;
        p_status := 'ERROR';
        p_message := 'Need quantity update failed: ' || v_msg_qty;

        INSERT INTO Error_Log (
            error_code, error_message, source_procedure, error_date, details
        ) VALUES (
            'NEED_QTY_FAIL',
            v_msg_qty,
            'SP_MAKE_DONATION',
            SYSDATE,
            'donor_id=' || TO_CHAR(p_donor_id) ||
            ', besoin_id=' || TO_CHAR(p_besoin_id)
        );
        RETURN;
    END IF;

    p_status  := 'OK';
    p_message := 'Donation created successfully.';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK TO sp_before_donation;
        p_id_don := NULL;
        p_status := 'ERROR';
        p_message := 'Donor or besoin not found.';

        INSERT INTO Error_Log (
            error_code, error_message, source_procedure, error_date, details
        ) VALUES (
            'NOT_FOUND',
            'Donor or Besoin not found in SP_MAKE_DONATION',
            'SP_MAKE_DONATION',
            SYSDATE,
            'donor_id=' || TO_CHAR(p_donor_id) ||
            ', besoin_id=' || TO_CHAR(p_besoin_id)
        );
    WHEN OTHERS THEN
        ROLLBACK TO sp_before_donation;
        p_id_don  := NULL;
        v_err_code := TO_CHAR(SQLCODE);
        v_err_msg  := SUBSTR(SQLERRM, 1, 500);

        INSERT INTO Error_Log (
            error_code, error_message, source_procedure, error_date, details
        ) VALUES (
            v_err_code,
            v_err_msg,
            'SP_MAKE_DONATION',
            SYSDATE,
            'donor_id=' || TO_CHAR(p_donor_id) ||
            ', besoin_id=' || TO_CHAR(p_besoin_id)
        );

        p_status  := 'ERROR';
        p_message := 'Unexpected error: ' || v_err_msg;
END SP_MAKE_DONATION;
/
SHOW ERRORS;

