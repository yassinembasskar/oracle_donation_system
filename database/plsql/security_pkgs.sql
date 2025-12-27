CREATE OR REPLACE PACKAGE BODY SECURITY_PKG AS

    FUNCTION has_role (
        p_user_id   IN Utilisateur.id_user%TYPE,
        p_code_role IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_dummy NUMBER;
    BEGIN
        SELECT 1
          INTO v_dummy
          FROM Utilisateur
         WHERE id_user = p_user_id
           AND UPPER(role_user) = UPPER(p_code_role);
    
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END has_role;


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
    ) AS
        v_count    NUMBER;
        v_err_code VARCHAR2(50);
        v_err_msg  VARCHAR2(500);
    BEGIN
        p_id_user := NULL;
        p_status  := 'ERROR';
        p_message := 'UNKNOWN_ERROR';
    
        -- Basic role validation (example; tighten as needed)
        IF p_role NOT IN ('ADMIN','ORG','DONOR') THEN
            p_status  := 'INVALID_ROLE';
            p_message := 'Role is not allowed.';
            RETURN;
        END IF;
    
        SELECT COUNT(*)
          INTO v_count
          FROM Utilisateur
         WHERE LOWER(email_user) = LOWER(p_email);
    
        IF v_count > 0 THEN
            p_status  := 'EMAIL_EXISTS';
            p_message := 'Email already registered.';
            RETURN;
        END IF;
    
        INSERT INTO Utilisateur (
            nom_user, role_user, email_user, tel_user, adresse_user,
            password_hash, statut_user
        ) VALUES (
            p_nom, p_role, p_email, p_tel, p_adresse,
            STANDARD_HASH(p_password, 'SHA256'),
            'ACTIVE'
        )
        RETURNING id_user INTO p_id_user;
    
        p_status  := 'OK';
        p_message := 'User registered successfully.';
    EXCEPTION
        WHEN OTHERS THEN
            v_err_code := TO_CHAR(SQLCODE);
            v_err_msg  := SUBSTR(SQLERRM, 1, 500);
    
            INSERT INTO Error_Log (
                error_code, error_message, source_procedure, error_date, details
            ) VALUES (
                v_err_code,
                v_err_msg,
                'SP_REGISTER_USER',
                SYSDATE,
                'email=' || p_email
            );
    
            p_id_user := NULL;
            p_status  := 'ERROR';
            p_message := 'Unexpected error: ' || v_err_msg;
    END SP_REGISTER_USER;
    
    PROCEDURE set_app_user(
        p_user_id IN Utilisateur.id_user%TYPE,
        p_email   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_SESSION.set_context('DONATION_CTX', 'USER_ID',  p_user_id);
        DBMS_SESSION.set_context('DONATION_CTX', 'EMAIL',    p_email);
    END;
    
    PROCEDURE clear_app_user IS
    BEGIN
        DBMS_SESSION.clear_context('DONATION_CTX');
    END;

    PROCEDURE SP_LOGIN (
        p_email IN VARCHAR2,
        p_password IN VARCHAR2,
        p_id_user OUT Utilisateur.id_user%TYPE,
        p_main_role OUT Utilisateur.role_user%TYPE,
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) AS
        v_password_hash Utilisateur.password_hash%TYPE;
        v_input_hash VARCHAR2(64);
        v_statut Utilisateur.statut_user%TYPE;
        v_err_code VARCHAR2(50);
        v_err_msg VARCHAR2(500);
    BEGIN
        p_id_user := NULL;
        p_main_role := NULL;
        p_status := 'ERROR';
        p_message := 'UNKNOWN_ERROR';

        SELECT id_user, role_user, password_hash, statut_user
        INTO p_id_user, p_main_role, v_password_hash, v_statut
        FROM Utilisateur
        WHERE LOWER(email_user) = LOWER(p_email);

        IF v_statut <> 'ACTIVE' THEN
            p_status := 'USER_INACTIVE';
            p_message := 'User is not active.';
            p_id_user := NULL;
            RETURN;
        END IF;

        SELECT STANDARD_HASH(p_password, 'SHA256')
        INTO v_input_hash
        FROM dual;

        IF v_password_hash <> v_input_hash THEN
            p_status := 'INVALID_CREDENTIALS';
            p_message := 'Invalid email or password.';
            p_id_user := NULL;
            RETURN;
        END IF;
        set_app_user(p_id_user,p_email);
        p_status := 'OK';
        p_message := 'Login successful.';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_id_user := NULL;
            p_main_role := NULL;
            p_status := 'INVALID_CREDENTIALS';
            p_message := 'Invalid email or password.';

        WHEN OTHERS THEN
            v_err_code := TO_CHAR(SQLCODE);
            v_err_msg := SUBSTR(SQLERRM, 1, 500);

            INSERT INTO Error_Log (
                error_code, error_message, source_procedure, error_date, details
            ) VALUES (
                v_err_code,
                v_err_msg,
                'SP_LOGIN',
                SYSDATE,
                'email=' || p_email
            );

            p_id_user := NULL;
            p_main_role := NULL;
            p_status := 'ERROR';
            p_message := 'Unexpected error: ' || v_err_msg;
    END SP_LOGIN;

    PROCEDURE SP_LOGOUT (
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) AS
    BEGIN
        clear_app_user();
        p_status := 'OK';
        p_message := 'Logout successful.';
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Logout failed: ' || SQLERRM;
    END SP_LOGOUT;

END SECURITY_PKG;
/