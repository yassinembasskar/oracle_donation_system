CREATE OR REPLACE PACKAGE SECURITY_PKG AS

    ------------------------------------------------------------------
    -- Role helper
    ------------------------------------------------------------------
    FUNCTION has_role (
        p_user_id   IN Utilisateur.id_user%TYPE,
        p_code_role IN VARCHAR2
    ) RETURN BOOLEAN;

    ------------------------------------------------------------------
    -- User registration / login / logout
    ------------------------------------------------------------------
    PROCEDURE SP_REGISTER_USER (
        p_nom      IN VARCHAR2,
        p_role     IN VARCHAR2,
        p_email    IN VARCHAR2,
        p_tel      IN VARCHAR2,
        p_adresse  IN VARCHAR2,
        p_password IN VARCHAR2,
        p_id_user  OUT Utilisateur.id_user%TYPE,
        p_status   OUT VARCHAR2,
        p_message  OUT VARCHAR2
    );

    PROCEDURE set_app_user(
        p_user_id IN Utilisateur.id_user%TYPE,
        p_email   IN VARCHAR2
    );

    PROCEDURE clear_app_user;

    PROCEDURE SP_LOGIN (
        p_email     IN VARCHAR2,
        p_password  IN VARCHAR2,
        p_id_user   OUT Utilisateur.id_user%TYPE,
        p_main_role OUT Utilisateur.role_user%TYPE,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );

    PROCEDURE SP_LOGOUT (
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

END SECURITY_PKG;
