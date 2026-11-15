import csv
import json
from pathlib import Path
from typing import Any

from frappe.tests import UnitTestCase

APP = Path(__file__).parent.parent
JA_CSV = APP / "translations" / "ja.csv"
WASTRA_ROLES = {"Field Manager", "Field Worker"}


def doctypes() -> list[dict[str, Any]]:
	return [json.loads(path.read_text(encoding="utf-8")) for path in sorted(APP.glob("**/doctype/*/*.json"))]


class TestDocTypeConventions(UnitTestCase):
	def test_every_doctype_grants_permissions_only_to_wastra_roles(self) -> None:
		violations = [
			f"{doctype['name']}: permission row uses role {row['role']!r}. "
			f"Use one of {sorted(WASTRA_ROLES)}, or add the new role to WASTRA_ROLES in {Path(__file__).name}."
			for doctype in doctypes()
			for row in doctype["permissions"]
			if row["role"] not in WASTRA_ROLES
		]

		self.assertEqual(violations, [])

	def test_every_doctype_name_field_label_and_permitted_role_is_translated_to_japanese(self) -> None:
		with JA_CSV.open(encoding="utf-8", newline="") as ja_csv:
			translated = {row[0] for row in csv.reader(ja_csv) if len(row) > 1 and row[1]}

		violations = [
			f"{doctype['name']}: {source!r} has no Japanese translation. "
			f"Add a line `{source},<日本語>` to wastra/translations/ja.csv."
			for doctype in doctypes()
			for source in [
				doctype["name"],
				*(field["label"] for field in doctype["fields"] if "label" in field),
				*(row["role"] for row in doctype["permissions"]),
			]
			if source not in translated
		]

		self.assertEqual(violations, [])
