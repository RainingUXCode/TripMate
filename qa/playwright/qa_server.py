"""Start Django against a disposable database and media directory."""

from __future__ import annotations

import os
import re
import socket
import sys
import tempfile
import time
import uuid
from pathlib import Path
from wsgiref.simple_server import WSGIServer, make_server


REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = REPO_ROOT / "backend"
PORT = 8765


def main() -> None:
    if not (BACKEND_ROOT / "manage.py").is_file():
        raise SystemExit("Backend TripMate não encontrado.")

    # Bind check is limited to loopback; never attach QA to a remote host.
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", PORT))

    qa_root = Path(tempfile.gettempdir()) / "tripmate-qa-runs"
    qa_root.mkdir(parents=True, exist_ok=True)
    run_id = os.environ.get("TRIPMATE_QA_RUN_ID", uuid.uuid4().hex)
    if re.fullmatch(r"[A-Za-z0-9_-]{1,80}", run_id) is None:
        raise SystemExit("TRIPMATE_QA_RUN_ID possui caracteres não permitidos.")
    run_dir = (qa_root / f"run-{run_id}").resolve()
    if run_dir.exists():
        raise SystemExit("O diretório desta execução QA já existe; não será reutilizado.")
    run_dir.mkdir()
    database_path = (run_dir / "qa.sqlite3").resolve()
    media_path = (run_dir / "media").resolve()
    media_path.mkdir()
    stop_path = run_dir / "STOP"

    if database_path == (BACKEND_ROOT / "db.sqlite3").resolve():
        raise SystemExit("Recusando usar o banco SQLite de desenvolvimento.")
    if not database_path.is_relative_to(qa_root.resolve()):
        raise SystemExit("Banco de QA fora do diretório temporário permitido.")

    sys.path.insert(0, str(BACKEND_ROOT))
    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"

    try:
        import django

        django.setup()

        from django.conf import settings
        from django.core.management import call_command
        from django.db import connections
        from django.core.wsgi import get_wsgi_application

        settings.DATABASES["default"]["NAME"] = str(database_path)
        settings.MEDIA_ROOT = media_path
        settings.ALLOWED_HOSTS = ["127.0.0.1", "localhost"]

        configured_database = Path(settings.DATABASES["default"]["NAME"]).resolve()
        if configured_database != database_path:
            raise SystemExit("O banco configurado não corresponde ao banco QA.")

        print(f"QA isolated DB: {database_path}", flush=True)
        print(f"QA isolated media: {media_path}", flush=True)
        call_command("migrate", interactive=False, verbosity=0)
        application = get_wsgi_application()
        with make_server("127.0.0.1", PORT, application, WSGIServer) as server:
            server.timeout = 0.5
            print(f"QA API ready: http://127.0.0.1:{PORT}", flush=True)
            while not stop_path.exists():
                server.handle_request()
                time.sleep(0.02)
        connections.close_all()
    finally:
        # This removes only the unique directory created above.
        import shutil

        shutil.rmtree(run_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
