CREATE OR REPLACE PACKAGE REPORTING_PKG AS

    ------------------------------------------------------------------
    -- Types
    ------------------------------------------------------------------
    TYPE t_ref_cursor IS REF CURSOR;

    ------------------------------------------------------------------
    -- Helper functions (internal use, but must be declared in spec)
    ------------------------------------------------------------------
    FUNCTION get_role_for_user (
        p_user_id IN NUMBER
    ) RETURN VARCHAR2;

    FUNCTION get_owned_org_id (
        p_user_id IN NUMBER
    ) RETURN NUMBER;

    ------------------------------------------------------------------
    -- KPI functions
    ------------------------------------------------------------------
    FUNCTION rpt_get_total_donations_amount (
        p_user_id    IN NUMBER,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date   IN DATE DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION rpt_get_total_donors_count (
        p_user_id    IN NUMBER,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date   IN DATE DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION rpt_get_active_campaigns_count (
        p_user_id IN NUMBER
    ) RETURN NUMBER;

    FUNCTION rpt_get_avg_campaign_completion_rate (
        p_user_id IN NUMBER
    ) RETURN NUMBER;

    ------------------------------------------------------------------
    -- Reporting procedures (REF CURSOR)
    ------------------------------------------------------------------
    PROCEDURE rpt_get_donation_history (
        p_user_id         IN NUMBER,
        p_start_date      IN DATE DEFAULT NULL,
        p_end_date        IN DATE DEFAULT NULL,
        p_statut_don      IN VARCHAR2 DEFAULT NULL,
        p_organisation_id IN NUMBER   DEFAULT NULL,
        p_action_id       IN NUMBER   DEFAULT NULL,
        p_result_cursor   OUT t_ref_cursor
    );

    PROCEDURE rpt_get_monthly_donations_summary (
        p_user_id       IN NUMBER,
        p_year          IN NUMBER DEFAULT NULL,
        p_result_cursor OUT t_ref_cursor
    );

    PROCEDURE rpt_get_org_ranking_by_donations (
        p_user_id       IN NUMBER,
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_result_cursor OUT t_ref_cursor
    );

    PROCEDURE rpt_get_campaign_activity (
        p_user_id       IN NUMBER,
        p_action_id     IN NUMBER,
        p_result_cursor OUT t_ref_cursor
    );

    PROCEDURE rpt_get_donor_personal_history (
        p_user_id       IN NUMBER,
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_result_cursor OUT t_ref_cursor
    );
    
    
    PROCEDURE log_error (
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_source_procedure IN VARCHAR2,
        p_result_cursor OUT t_ref_cursor
    );


    PROCEDURE log_business_event (
        p_start_date    IN DATE DEFAULT NULL,
        p_end_date      IN DATE DEFAULT NULL,
        p_table_name  IN VARCHAR2,
        p_operation   IN VARCHAR2,  
        p_changed_by  IN NUMBER,
        p_result_cursor OUT t_ref_cursor
    );

END REPORTING_PKG;
