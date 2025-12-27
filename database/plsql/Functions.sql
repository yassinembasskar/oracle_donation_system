CREATE OR REPLACE FUNCTION has_role (
    p_user_id   IN Utilisateur.id_user%TYPE,
    p_code_role IN VARCHAR2
) RETURN BOOLEAN IS
    v_dummy NUMBER;
BEGIN
    SELECT 1
      INTO v_dummy
      FROM Utilisateur
     WHERE id_user = p_user_id
       AND UPPER(TRIM(role_user)) = UPPER(TRIM(p_code_role));

    RETURN TRUE;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
    WHEN TOO_MANY_ROWS THEN
        -- Data issue (duplicate roles), but from a security point of view: user has that role
        RETURN TRUE;
END has_role;
