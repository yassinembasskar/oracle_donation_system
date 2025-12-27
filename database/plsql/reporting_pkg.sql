CREATE OR REPLACE PACKAGE BODY REPORTING_PKG AS

    ------------------------------------------------------------------
    -- Helper: resolve role and org ownership
    ------------------------------------------------------------------
    FUNCTION get_role_for_user (
        p_user_id IN NUMBER
    ) RETURN VARCHAR2 IS
        v_role Utilisateur.role_user%TYPE;
    BEGIN
        SELECT role_user
          INTO v_role
          FROM Utilisateur
         WHERE id_user = p_user_id;
        RETURN v_role;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_role_for_user;

    FUNCTION get_owned_org_id (
        p_user_id IN NUMBER
    ) RETURN NUMBER IS
        v_org_id Organisation.id_org%TYPE;
    BEGIN
        SELECT id_org
          INTO v_org_id
          FROM Organisation
         WHERE id_user_owner = p_user_id
           AND ROWNUM = 1;
        RETURN v_org_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_owned_org_id;

    ------------------------------------------------------------------
    -- 1. KPI functions
    ------------------------------------------------------------------

    FUNCTION rpt_get_total_donations_amount (
        p_user_id    IN NUMBER,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date   IN DATE DEFAULT NULL
    ) RETURN NUMBER IS
        v_total_amount NUMBER := 0;
        v_role         VARCHAR2(30) := get_role_for_user(p_user_id);
        v_org_id       NUMBER       := get_owned_org_id(p_user_id);
    BEGIN
        SELECT NVL(SUM(d.montant_don), 0)
          INTO v_total_amount
          FROM Don d
          JOIN Besoin b        ON d.id_besoin = b.id_besoin
          JOIN Action_social a ON b.id_action = a.id_action
         WHERE d.statut_don = 'CONFIRMED'
           AND (p_start_date IS NULL OR d.date_don >= p_start_date)
           AND (p_end_date   IS NULL OR d.date_don <= p_end_date)
           AND (
                 v_role = 'ADMIN'
              OR (v_role = 'ORG'   AND a.id_org IN (
                     SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                 ))
              OR (v_role = 'DONOR' AND d.id_donateur = p_user_id)
           );

        RETURN v_total_amount;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END rpt_get_total_donations_amount;

    FUNCTION rpt_get_total_donors_count (
        p_user_id    IN NUMBER,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date   IN DATE DEFAULT NULL
    ) RETURN NUMBER IS
        v_total_count NUMBER := 0;
        v_role        VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        SELECT COUNT(DISTINCT d.id_donateur)
          INTO v_total_count
          FROM Don d
          JOIN Besoin b        ON d.id_besoin = b.id_besoin
          JOIN Action_social a ON b.id_action = a.id_action
         WHERE d.statut_don = 'CONFIRMED'
           AND (p_start_date IS NULL OR d.date_don >= p_start_date)
           AND (p_end_date   IS NULL OR d.date_don <= p_end_date)
           AND (
                 v_role = 'ADMIN'
              OR (v_role = 'ORG'   AND a.id_org IN (
                     SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                 ))
              OR (v_role = 'DONOR' AND d.id_donateur = p_user_id)
           );

        RETURN v_total_count;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END rpt_get_total_donors_count;

    FUNCTION rpt_get_active_campaigns_count (
        p_user_id IN NUMBER
    ) RETURN NUMBER IS
        v_total_count NUMBER := 0;
        v_role        VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        SELECT COUNT(a.id_action)
          INTO v_total_count
          FROM Action_social a
         WHERE a.statut_action = 'ACTIVE'
           AND (
                 v_role = 'ADMIN'
              OR (v_role = 'ORG'   AND a.id_org IN (
                     SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                 ))
              OR (v_role = 'DONOR') -- donors can see all active campaigns
           );

        RETURN v_total_count;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END rpt_get_active_campaigns_count;

    FUNCTION rpt_get_avg_campaign_completion_rate (
        p_user_id IN NUMBER
    ) RETURN NUMBER IS
        v_avg_rate NUMBER := 0;
        v_role     VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        SELECT NVL(AVG(
                   CASE
                     WHEN montant_objectif_action > 0
                     THEN (montant_recu_action / montant_objectif_action) * 100
                     ELSE 0
                   END
               ), 0)
          INTO v_avg_rate
          FROM Action_social a
         WHERE a.statut_action IN ('ACTIVE', 'CLOSED', 'COMPLETED')
           AND (
                 v_role = 'ADMIN'
              OR (v_role = 'ORG'   AND a.id_org IN (
                     SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                 ))
              OR (v_role = 'DONOR') -- donors see global average
           );

        RETURN ROUND(v_avg_rate, 2);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END rpt_get_avg_campaign_completion_rate;

    ------------------------------------------------------------------
    -- 2. Reporting procedures (SYS_REFCURSOR)
    ------------------------------------------------------------------

    PROCEDURE rpt_get_donation_history (
        p_user_id         IN NUMBER,
        p_start_date      IN DATE DEFAULT NULL,
        p_end_date        IN DATE DEFAULT NULL,
        p_statut_don      IN VARCHAR2 DEFAULT NULL,
        p_organisation_id IN NUMBER DEFAULT NULL,
        p_action_id       IN NUMBER DEFAULT NULL,
        p_result_cursor   OUT t_ref_cursor
    ) IS
        v_role VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        OPEN p_result_cursor FOR
            SELECT
                d.id_don,
                d.montant_don,
                d.date_don,
                d.statut_don,
                u.nom_user       AS nom_donateur,
                o.nom_org        AS nom_organisation,
                a.titre_action   AS nom_campagne,
                b.nom_besoin
            FROM Don d
            JOIN Utilisateur   u ON d.id_donateur = u.id_user
            JOIN Besoin        b ON d.id_besoin   = b.id_besoin
            JOIN Action_social a ON b.id_action   = a.id_action
            JOIN Organisation  o ON a.id_org      = o.id_org
           WHERE (p_start_date IS NULL OR d.date_don >= p_start_date)
             AND (p_end_date   IS NULL OR d.date_don <= p_end_date)
             AND (p_statut_don IS NULL OR d.statut_don = p_statut_don)
             AND (p_action_id  IS NULL OR a.id_action  = p_action_id)
             AND (p_organisation_id IS NULL OR o.id_org = p_organisation_id)
             AND (
                   v_role = 'ADMIN'
                OR (v_role = 'ORG'   AND o.id_org IN (
                       SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                   ))
                OR (v_role = 'DONOR' AND d.id_donateur = p_user_id)
             )
           ORDER BY d.date_don DESC;
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_don,
                    CAST(NULL AS NUMBER)        AS montant_don,
                    CAST(NULL AS DATE)          AS date_don,
                    CAST(NULL AS VARCHAR2(20))  AS statut_don,
                    CAST(NULL AS VARCHAR2(100)) AS nom_donateur,
                    CAST(NULL AS VARCHAR2(100)) AS nom_organisation,
                    CAST(NULL AS VARCHAR2(100)) AS nom_campagne,
                    CAST(NULL AS VARCHAR2(100)) AS nom_besoin
                FROM DUAL WHERE 1 = 0;
    END rpt_get_donation_history;

    PROCEDURE rpt_get_monthly_donations_summary (
        p_user_id       IN NUMBER,
        p_year          IN NUMBER DEFAULT NULL,
        p_result_cursor OUT t_ref_cursor
    ) IS
        v_role VARCHAR2(30) := get_role_for_user(p_user_id);
        v_year NUMBER       := NVL(p_year, TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY')));
    BEGIN
        OPEN p_result_cursor FOR
            SELECT
                TO_CHAR(d.date_don, 'YYYY-MM')                                       AS annee_mois,
                TO_CHAR(d.date_don, 'Month', 'NLS_DATE_LANGUAGE=FRENCH')             AS mois_libelle,
                COUNT(d.id_don)                                                      AS nombre_dons,
                SUM(d.montant_don)                                                   AS montant_total
            FROM Don d
            JOIN Besoin        b ON d.id_besoin = b.id_besoin
            JOIN Action_social a ON b.id_action = a.id_action
           WHERE d.statut_don = 'CONFIRMED'
             AND TO_NUMBER(TO_CHAR(d.date_don, 'YYYY')) = v_year
             AND (
                   v_role = 'ADMIN'
                OR (v_role = 'ORG'   AND a.id_org IN (
                       SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                   ))
                OR (v_role = 'DONOR' AND d.id_donateur = p_user_id)
             )
           GROUP BY
                TO_CHAR(d.date_don, 'YYYY-MM'),
                TO_CHAR(d.date_don, 'Month', 'NLS_DATE_LANGUAGE=FRENCH')
           ORDER BY annee_mois;
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS VARCHAR2(7))  AS annee_mois,
                    CAST(NULL AS VARCHAR2(20)) AS mois_libelle,
                    CAST(NULL AS NUMBER)       AS nombre_dons,
                    CAST(NULL AS NUMBER)       AS montant_total
                FROM DUAL WHERE 1 = 0;
    END rpt_get_monthly_donations_summary;

    PROCEDURE rpt_get_org_ranking_by_donations (
        p_user_id       IN NUMBER,
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_result_cursor OUT t_ref_cursor
    ) IS
        v_role VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        IF v_role = 'DONOR' THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_org,
                    CAST(NULL AS VARCHAR2(100)) AS nom_org,
                    CAST(NULL AS NUMBER)        AS montant_total_don,
                    CAST(NULL AS NUMBER)        AS rang
                FROM DUAL WHERE 1 = 0;
            RETURN;
        END IF;

        OPEN p_result_cursor FOR
            WITH OrgDonations AS (
                SELECT
                    o.id_org,
                    o.nom_org,
                    NVL(SUM(d.montant_don), 0) AS montant_total_don
                FROM Organisation o
                LEFT JOIN Action_social a ON o.id_org = a.id_org
                LEFT JOIN Besoin        b ON a.id_action = b.id_action
                LEFT JOIN Don          d ON b.id_besoin = d.id_besoin
                                          AND d.statut_don = 'CONFIRMED'
                                          AND (p_start_date IS NULL OR d.date_don >= p_start_date)
                                          AND (p_end_date   IS NULL OR d.date_don <= p_end_date)
               WHERE (v_role = 'ADMIN'
                  OR (v_role = 'ORG' AND o.id_org IN (
                         SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                     )))
               GROUP BY o.id_org, o.nom_org
            )
            SELECT
                od.id_org,
                od.nom_org,
                od.montant_total_don,
                RANK() OVER (ORDER BY od.montant_total_don DESC) AS rang
            FROM OrgDonations od
            ORDER BY rang;
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_org,
                    CAST(NULL AS VARCHAR2(100)) AS nom_org,
                    CAST(NULL AS NUMBER)        AS montant_total_don,
                    CAST(NULL AS NUMBER)        AS rang
                FROM DUAL WHERE 1 = 0;
    END rpt_get_org_ranking_by_donations;

    PROCEDURE rpt_get_campaign_activity (
        p_user_id       IN NUMBER,
        p_action_id     IN NUMBER,
        p_result_cursor OUT t_ref_cursor
    ) IS
        v_role VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        OPEN p_result_cursor FOR
            SELECT
                a.titre_action,
                a.date_debut_action,
                a.date_fin_action,
                a.montant_objectif_action,
                a.montant_recu_action,
                a.statut_action,
                o.nom_org,
                b.nom_besoin,
                b.unite_demande,
                b.unite_recue,
                b.pourcentage_rempli
            FROM Action_social a
            JOIN Organisation o ON a.id_org = o.id_org
            LEFT JOIN Besoin b  ON a.id_action = b.id_action
           WHERE a.id_action = p_action_id
             AND (
                   v_role = 'ADMIN'
                OR (v_role = 'ORG'   AND a.id_org IN (
                       SELECT id_org FROM Organisation WHERE id_user_owner = p_user_id
                   ))
                OR (v_role = 'DONOR')
             );
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS VARCHAR2(100)) AS titre_action,
                    CAST(NULL AS DATE)          AS date_debut_action,
                    CAST(NULL AS DATE)          AS date_fin_action,
                    CAST(NULL AS NUMBER)        AS montant_objectif_action,
                    CAST(NULL AS NUMBER)        AS montant_recu_action,
                    CAST(NULL AS VARCHAR2(20))  AS statut_action,
                    CAST(NULL AS VARCHAR2(100)) AS nom_org,
                    CAST(NULL AS VARCHAR2(100)) AS nom_besoin,
                    CAST(NULL AS NUMBER)        AS unite_demande,
                    CAST(NULL AS NUMBER)        AS unite_recue,
                    CAST(NULL AS NUMBER)        AS pourcentage_rempli
                FROM DUAL WHERE 1 = 0;
    END rpt_get_campaign_activity;

    PROCEDURE rpt_get_donor_personal_history (
        p_user_id       IN NUMBER,
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_result_cursor OUT t_ref_cursor
    ) IS
        v_role VARCHAR2(30) := get_role_for_user(p_user_id);
    BEGIN
        IF v_role NOT IN ('ADMIN', 'DONOR') THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_don,
                    CAST(NULL AS NUMBER)        AS montant_don,
                    CAST(NULL AS DATE)          AS date_don,
                    CAST(NULL AS VARCHAR2(20))  AS statut_don,
                    CAST(NULL AS VARCHAR2(100)) AS nom_organisation,
                    CAST(NULL AS VARCHAR2(100)) AS nom_campagne
                FROM DUAL WHERE 1 = 0;
            RETURN;
        END IF;

        OPEN p_result_cursor FOR
            SELECT
                d.id_don,
                d.montant_don,
                d.date_don,
                d.statut_don,
                o.nom_org      AS nom_organisation,
                a.titre_action AS nom_campagne
            FROM Don d
            JOIN Besoin        b ON d.id_besoin = b.id_besoin
            JOIN Action_social a ON b.id_action = a.id_action
            JOIN Organisation  o ON a.id_org    = o.id_org
           WHERE d.id_donateur = p_user_id
             AND (p_start_date IS NULL OR d.date_don >= p_start_date)
             AND (p_end_date   IS NULL OR d.date_don <= p_end_date)
           ORDER BY d.date_don DESC;
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_don,
                    CAST(NULL AS NUMBER)        AS montant_don,
                    CAST(NULL AS DATE)          AS date_don,
                    CAST(NULL AS VARCHAR2(20))  AS statut_don,
                    CAST(NULL AS VARCHAR2(100)) AS nom_organisation,
                    CAST(NULL AS VARCHAR2(100)) AS nom_campagne
                FROM DUAL WHERE 1 = 0;
    END rpt_get_donor_personal_history;
    
    PROCEDURE log_error (
        p_start_date      IN DATE DEFAULT NULL,
        p_end_date        IN DATE DEFAULT NULL,
        p_source_procedure IN VARCHAR2,
        p_result_cursor   OUT t_ref_cursor
    ) IS
    BEGIN
        OPEN p_result_cursor FOR
            SELECT
                id_error,
                error_code,
                error_message,
                source_procedure,
                error_date,
                details
            FROM Error_Log
            WHERE (p_start_date IS NULL OR error_date >= p_start_date)
              AND (p_end_date   IS NULL OR error_date <= p_end_date)
              AND (p_source_procedure IS NULL OR source_procedure = p_source_procedure)
            ORDER BY error_date DESC;
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_error,
                    CAST(NULL AS VARCHAR2(50))  AS error_code,
                    CAST(NULL AS VARCHAR2(500)) AS error_message,
                    CAST(NULL AS VARCHAR2(100)) AS source_procedure,
                    CAST(NULL AS DATE)          AS error_date,
                    CAST(NULL AS CLOB)          AS details
                FROM DUAL
                WHERE 1 = 0;
    END log_error;

    PROCEDURE log_business_event (
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_table_name    IN VARCHAR2,
        p_operation     IN VARCHAR2,
        p_changed_by    IN NUMBER,
        p_result_cursor OUT t_ref_cursor
    ) IS
    BEGIN
        OPEN p_result_cursor FOR
            SELECT
                id_audit,
                table_name,
                record_pk,
                operation,
                old_values,
                new_values,
                changed_by,
                change_date
            FROM Business_Log_Audit
            WHERE (p_start_date IS NULL OR change_date >= p_start_date)
              AND (p_end_date   IS NULL OR change_date <= p_end_date)
              AND (p_table_name IS NULL OR table_name = p_table_name)
              AND (p_operation  IS NULL OR operation  = p_operation)
              AND (p_changed_by IS NULL OR changed_by = p_changed_by)
            ORDER BY change_date DESC;
    EXCEPTION
        WHEN OTHERS THEN
            OPEN p_result_cursor FOR
                SELECT
                    CAST(NULL AS NUMBER)        AS id_audit,
                    CAST(NULL AS VARCHAR2(50))  AS table_name,
                    CAST(NULL AS NUMBER)        AS record_pk,
                    CAST(NULL AS VARCHAR2(10))  AS operation,
                    CAST(NULL AS VARCHAR2(2000)) AS old_values,
                    CAST(NULL AS VARCHAR2(2000)) AS new_values,
                    CAST(NULL AS NUMBER)        AS changed_by,
                    CAST(NULL AS DATE)          AS change_date
                FROM DUAL
                WHERE 1 = 0;
    END log_business_event;


END REPORTING_PKG;
/
