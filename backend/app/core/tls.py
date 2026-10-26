"""Use verified platform trust, including managed Windows enterprise roots.

httpx defaults to certifi rather than the OS store. ssl.create_default_context
loads platform roots and honors SSL_CERT_FILE/SSL_CERT_DIR without disabling
hostname or certificate verification.
"""
import ssl
from functools import lru_cache


@lru_cache(maxsize=1)
def tls_context():
    return ssl.create_default_context()
