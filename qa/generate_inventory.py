"""Build a sanitized case inventory from repository test declarations."""

from __future__ import annotations

import argparse
import ast
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "qa" / "inventario-de-testes.md"


def dart_cases() -> list[tuple[str, str, str, str]]:
    cases: list[tuple[str, str, str, str]] = []
    pattern = re.compile(r"\b(testWidgets|test)\s*\(\s*(['\"])(.*?)\2", re.S)
    for path in sorted((ROOT / "test").glob("*_test.dart")):
        content = path.read_text(encoding="utf-8")
        for kind, _, title in pattern.findall(content):
            cases.append((path.relative_to(ROOT).as_posix(), path.stem, title.strip(), "Widget" if kind == "testWidgets" else "Unit/widget"))
    return cases


def django_cases() -> list[tuple[str, str, str, str]]:
    cases: list[tuple[str, str, str, str]] = []
    for path in sorted((ROOT / "backend").glob("*/test*.py")):
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"))
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test_"):
                module = path.parent.name
                cases.append((path.relative_to(ROOT).as_posix(), module, node.name.removeprefix("test_").replace("_", " "), "API/model/domain"))
    return cases


def playwright_cases() -> list[tuple[str, str, str, str, str]]:
    report = ROOT / "qa" / "playwright" / "test-results" / "report.json"
    if not report.exists():
        return []
    payload = json.loads(report.read_text(encoding="utf-8"))
    cases: list[tuple[str, str, str, str, str]] = []

    def walk(suites: list[dict], file: str = "") -> None:
        for suite in suites:
            current_file = suite.get("file", file)
            for spec in suite.get("specs", []):
                statuses = [test.get("status") for test in spec.get("tests", [])]
                status = "Aprovado" if statuses and all(value == "expected" for value in statuses) else "Reprovado"
                cases.append((current_file, current_file.removesuffix(".spec.ts").title(), spec.get("title", ""), "API Playwright", status))
            walk(suite.get("suites", []), current_file)

    walk(payload.get("suites", []))
    return cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--flutter", choices=["Aprovado", "Reprovado", "Bloqueado", "Não executado"], default="Não executado")
    parser.add_argument("--django", choices=["Aprovado", "Reprovado", "Bloqueado", "Não executado"], default="Não executado")
    parser.add_argument("--integration", choices=["Aprovado", "Reprovado", "Bloqueado", "Não executado"], default="Não executado")
    args = parser.parse_args()

    rows: list[tuple[str, str, str, str, str, str]] = []
    for index, item in enumerate(dart_cases(), 1):
        file, module, title, kind = item
        rows.append((f"QA-FLT-{index:03d}", file, module, title, kind, args.flutter))
    for index, item in enumerate(django_cases(), 1):
        file, module, title, kind = item
        rows.append((f"QA-DJ-{index:03d}", file, module, title, kind, args.django))
    for index, item in enumerate(playwright_cases(), 1):
        file, module, title, kind, status = item
        rows.append((f"QA-API-{index:03d}", f"qa/playwright/tests/{file}", module, title, kind, status))
    integration = ROOT / "integration_test" / "tripmate_smoke_test.dart"
    if integration.exists():
        for index, (_, title) in enumerate(re.compile(r"\btestWidgets\s*\(\s*(['\"])(.*?)\1", re.S).findall(integration.read_text(encoding="utf-8")), 1):
            rows.append((f"QA-INT-{index:03d}", integration.relative_to(ROOT).as_posix(), "Android", title.strip(), "Integration", args.integration))

    lines = [
        "# Inventário automatizado de testes",
        "",
        "Gerado por `python qa/generate_inventory.py` a partir das declarações de teste. Status Flutter/Django/Android representam a última execução indicada explicitamente pelos argumentos do gerador; Playwright vem do relatório JSON da execução. Não contém tokens, credenciais ou dados de fixture.",
        "",
        "| ID | Arquivo | Módulo | Cenário | Tipo | Resultado |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        safe = [value.replace("|", "\\|").replace("\n", " ") for value in row]
        lines.append("| " + " | ".join(safe) + " |")
    lines += ["", f"Total inventariado: **{len(rows)}** casos declarados (inclui integração preparada)."]
    DOC.parent.mkdir(parents=True, exist_ok=True)
    DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Inventário gravado: {DOC} ({len(rows)} casos)")


if __name__ == "__main__":
    main()
