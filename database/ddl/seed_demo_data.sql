-- ============================================================
-- Seed Demo Data - Oracle Donation Management System
-- To run as: DONATION_APP on XEPDB1
-- ============================================================

-- Clean existing data (optional for development)
DELETE FROM Payment_Proofs;
DELETE FROM Don;
DELETE FROM Besoin;
DELETE FROM Action_social;
DELETE FROM Organisation;
DELETE FROM User_Role;
DELETE FROM Role;
DELETE FROM Utilisateur;
COMMIT;

-- ============================================================
-- 1. Seed Roles
-- ============================================================
INSERT INTO Role (code_role, libelle) VALUES ('ADMIN', 'Administrateur');
INSERT INTO Role (code_role, libelle) VALUES ('ORG',   'Organisation');
INSERT INTO Role (code_role, libelle) VALUES ('DONOR', 'Donateur');
COMMIT;

-- ============================================================
-- 2. Seed Users (Admins, Orgs, Donors)
-- ============================================================

-- Admins
INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Admin One',   'admin1@example.com', '0600000001', 'Agadir',   'admin1pwd', 'ACTIVE');

INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Admin Two',   'admin2@example.com', '0600000002', 'Agadir',   'admin2pwd', 'ACTIVE');

-- Organisations owners (users)
INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Org User One', 'org1@example.com',   '0600000011', 'Agadir', 'org1pwd', 'ACTIVE');

INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Org User Two', 'org2@example.com',   '0600000012', 'Agadir', 'org2pwd', 'ACTIVE');

-- Donors
INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Donor One',   'donor1@example.com',  '0600000101', 'Agadir', 'donor1pwd', 'ACTIVE');

INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Donor Two',   'donor2@example.com',  '0600000102', 'Agadir', 'donor2pwd', 'ACTIVE');

INSERT INTO Utilisateur (nom_user, email_user, tel_user, adresse_user, password_hash, statut_user)
VALUES ('Donor Three', 'donor3@example.com',  '0600000103', 'Agadir', 'donor3pwd', 'ACTIVE');

COMMIT;

-- ============================================================
-- 3. Assign Roles to Users (User_Role)
-- ============================================================

-- Get role IDs
DECLARE
    v_admin_role_id  Role.id_role%TYPE;
    v_org_role_id    Role.id_role%TYPE;
    v_donor_role_id  Role.id_role%TYPE;
BEGIN
    SELECT id_role INTO v_admin_role_id FROM Role WHERE code_role = 'ADMIN';
    SELECT id_role INTO v_org_role_id   FROM Role WHERE code_role = 'ORG';
    SELECT id_role INTO v_donor_role_id FROM Role WHERE code_role = 'DONOR';

    -- Assign roles
    INSERT INTO User_Role (id_user, id_role)
    SELECT id_user, v_admin_role_id
    FROM Utilisateur
    WHERE email_user IN ('admin1@example.com', 'admin2@example.com');

    INSERT INTO User_Role (id_user, v_org_role_id)
    FROM Utilisateur
    WHERE email_user IN ('org1@example.com', 'org2@example.com');

    INSERT INTO User_Role (id_user, v_donor_role_id)
    FROM Utilisateur
    WHERE email_user IN ('donor1@example.com', 'donor2@example.com', 'donor3@example.com');

    COMMIT;
END;
/

-- ============================================================
-- 4. Seed Organisations
-- ============================================================

DECLARE
    v_org_user1_id Utilisateur.id_user%TYPE;
    v_org_user2_id Utilisateur.id_user%TYPE;
BEGIN
    SELECT id_user INTO v_org_user1_id FROM Utilisateur WHERE email_user = 'org1@example.com';
    SELECT id_user INTO v_org_user2_id FROM Utilisateur WHERE email_user = 'org2@example.com';

    INSERT INTO Organisation (id_user_owner, nom_org, desc_org, tel_org, num_patente, lieu_org, statut_org)
    VALUES (v_org_user1_id, 'Association Espoir', 'Aide alimentaire', '0601000001', 'PAT-001', 'Agadir', 'ACTIVE');

    INSERT INTO Organisation (id_user_owner, nom_org, desc_org, tel_org, num_patente, lieu_org, statut_org)
    VALUES (v_org_user2_id, 'Association Futur', 'Soutien scolaire', '0601000002', 'PAT-002', 'Agadir', 'ACTIVE');

    COMMIT;
END;
/

-- ============================================================
-- 5. Seed Action_social (Campaigns)
-- ============================================================

DECLARE
    v_org1_id Organisation.id_org%TYPE;
    v_org2_id Organisation.id_org%TYPE;
BEGIN
    SELECT id_org INTO v_org1_id FROM Organisation WHERE nom_org = 'Association Espoir';
    SELECT id_org INTO v_org2_id FROM Organisation WHERE nom_org = 'Association Futur';

    INSERT INTO Action_social (
        id_org, titre_action, desc_action, affiche_action,
        date_debut_action, date_fin_action,
        montant_objectif_action, montant_recu_action, statut_action
    ) VALUES (
        v_org1_id,
        'Campagne Ramadan',
        'Distribution de paniers alimentaires pour les familles nécessiteuses.',
        'ramadan.png',
        DATE '2025-03-01',
        DATE '2025-04-15',
        50000,
        0,
        'ACTIVE'
    );

    INSERT INTO Action_social (
        id_org, titre_action, desc_action, affiche_action,
        date_debut_action, date_fin_action,
        montant_objectif_action, montant_recu_action, statut_action
    ) VALUES (
        v_org2_id,
        'Rentrée Scolaire',
        'Fournitures scolaires pour les élèves défavorisés.',
        'rentree.png',
        DATE '2025-08-15',
        DATE '2025-09-30',
        30000,
        0,
        'ACTIVE'
    );

    COMMIT;
END;
/

-- ============================================================
-- 6. Seed Besoin (Needs) for each action
-- ============================================================

DECLARE
    v_action1_id Action_social.id_action%TYPE;
    v_action2_id Action_social.id_action%TYPE;
BEGIN
    SELECT id_action INTO v_action1_id
    FROM Action_social
    WHERE titre_action = 'Campagne Ramadan';

    SELECT id_action INTO v_action2_id
    FROM Action_social
    WHERE titre_action = 'Rentrée Scolaire';

    -- Needs for Campagne Ramadan
    INSERT INTO Besoin (id_action, nom_besoin, description_besoin, type_besoin,
                        unite_demande, unite_recue, prix_unitaire, statut_besoin)
    VALUES (v_action1_id, 'Paniers alimentaires', 'Paniers contenant produits essentiels.',
            'NOURRITURE', 200, 50, 250, 'EN_COURS');

    INSERT INTO Besoin (id_action, nom_besoin, description_besoin, type_besoin,
                        unite_demande, unite_recue, prix_unitaire, statut_besoin)
    VALUES (v_action1_id, 'Bouteilles d''huile', 'Huile végétale 1L.',
            'NOURRITURE', 500, 100, 20, 'EN_COURS');

    -- Needs for Rentrée Scolaire
    INSERT INTO Besoin (id_action, nom_besoin, description_besoin, type_besoin,
                        unite_demande, unite_recue, prix_unitaire, statut_besoin)
    VALUES (v_action2_id, 'Kits scolaires', 'Sac + cahiers + stylos.',
            'FOURNITURES', 150, 30, 300, 'EN_COURS');

    INSERT INTO Besoin (id_action, nom_besoin, description_besoin, type_besoin,
                        unite_demande, unite_recue, prix_unitaire, statut_besoin)
    VALUES (v_action2_id, 'Chaussures', 'Chaussures pour enfants.',
            'VÊTEMENTS', 100, 20, 200, 'EN_COURS');

    COMMIT;
END;
/

-- ============================================================
-- 7. Seed Don (Donations)
-- ============================================================

DECLARE
    v_donor1_id Utilisateur.id_user%TYPE;
    v_donor2_id Utilisateur.id_user%TYPE;
    v_donor3_id Utilisateur.id_user%TYPE;

    v_besoin1_id Besoin.id_besoin%TYPE;
    v_besoin2_id Besoin.id_besoin%TYPE;
    v_besoin3_id Besoin.id_besoin%TYPE;
    v_besoin4_id Besoin.id_besoin%TYPE;
BEGIN
    SELECT id_user INTO v_donor1_id FROM Utilisateur WHERE email_user = 'donor1@example.com';
    SELECT id_user INTO v_donor2_id FROM Utilisateur WHERE email_user = 'donor2@example.com';
    SELECT id_user INTO v_donor3_id FROM Utilisateur WHERE email_user = 'donor3@example.com';

    SELECT id_besoin INTO v_besoin1_id FROM Besoin WHERE nom_besoin = 'Paniers alimentaires';
    SELECT id_besoin INTO v_besoin2_id FROM Besoin WHERE nom_besoin = 'Bouteilles d''huile';
    SELECT id_besoin INTO v_besoin3_id FROM Besoin WHERE nom_besoin = 'Kits scolaires';
    SELECT id_besoin INTO v_besoin4_id FROM Besoin WHERE nom_besoin = 'Chaussures';

    -- Donations on Ramadan campaign needs
    INSERT INTO Don (id_donateur, id_besoin, montant_don, statut_don, preuve_don)
    VALUES (v_donor1_id, v_besoin1_id, 2000, 'VALIDÉ', 'preuve_ramadan1.png');

    INSERT INTO Don (id_donateur, id_besoin, montant_don, statut_don, preuve_don)
    VALUES (v_donor2_id, v_besoin1_id, 1500, 'PENDING', 'preuve_ramadan2.png');

    INSERT INTO Don (id_donateur, id_besoin, montant_don, statut_don, preuve_don)
    VALUES (v_donor3_id, v_besoin2_id, 1000, 'VALIDÉ', 'preuve_ramadan3.png');

    -- Donations on Rentrée Scolaire needs
    INSERT INTO Don (id_donateur, id_besoin, montant_don, statut_don, preuve_don)
    VALUES (v_donor1_id, v_besoin3_id, 3000, 'VALIDÉ', 'preuve_rentree1.png');

    INSERT INTO Don (id_donateur, id_besoin, montant_don, statut_don, preuve_don)
    VALUES (v_donor2_id, v_besoin4_id, 1200, 'PENDING', 'preuve_rentree2.png');

    COMMIT;
END;
/

-- ============================================================
-- 8. Quick sanity checks
-- ============================================================
SELECT COUNT(*) AS nb_users       FROM Utilisateur;
SELECT COUNT(*) AS nb_roles       FROM Role;
SELECT COUNT(*) AS nb_orgs        FROM Organisation;
SELECT COUNT(*) AS nb_actions     FROM Action_social;
SELECT COUNT(*) AS nb_besoins     FROM Besoin;
SELECT COUNT(*) AS nb_dons        FROM Don;



SELECT * FROM Utilisateur;
SELECT * FROM Organisation;
SELECT * FROM Action_social;
SELECT * FROM Besoin;
SELECT * FROM Don;

