import oracledb
from ..config import settings


def get_connection():
    """
    Retourne une connexion Oracle en utilisant les variables d'environnement.
    À appeler plus tard dans les routes.
    """
    connection = oracledb.connect(
        user=settings.oracle_user,
        password=settings.oracle_password,
        dsn=settings.oracle_dsn,
    )
    return connection


def test_connection():
    """
    Petit test pour vérifier que la connexion fonctionne.
    Tu pourras l'appeler dans un script séparé plus tard.
    """
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT 1 FROM dual")
    result = cursor.fetchone()
    cursor.close()
    conn.close()
    return result
