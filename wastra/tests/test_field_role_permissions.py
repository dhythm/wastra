import frappe
from frappe.tests import IntegrationTestCase


def user_with_role(role: str) -> str:
	email = f"{frappe.scrub(role)}@example.com"
	frappe.get_doc(
		{"doctype": "User", "email": email, "first_name": role, "roles": [{"role": role}]}
	).insert()
	return email


def work_site_of_new_client(client_name: str, site_name: str) -> None:
	frappe.get_doc({"doctype": "Client", "client_name": client_name}).insert()
	frappe.get_doc({"doctype": "Work Site", "site_name": site_name, "client": client_name}).insert()


class TestFieldRolePermissions(IntegrationTestCase):
	def setUp(self) -> None:
		super().setUp()
		self.addCleanup(frappe.set_user, "Administrator")
		self.addCleanup(frappe.db.rollback)

	def test_field_manager_can_create_a_client_and_a_work_site_for_it(self) -> None:
		frappe.set_user(user_with_role("Field Manager"))

		work_site_of_new_client("山田ビル管理", "本社ビル")

		self.assertIn("山田ビル管理", frappe.get_list("Work Site", pluck="client"))

	def test_field_worker_can_read_a_work_site(self) -> None:
		work_site_of_new_client("山田ビル管理", "本社ビル")
		frappe.set_user(user_with_role("Field Worker"))

		self.assertIn("本社ビル", frappe.get_list("Work Site", pluck="site_name"))

	def test_field_worker_cannot_create_a_work_site(self) -> None:
		frappe.get_doc({"doctype": "Client", "client_name": "山田ビル管理"}).insert()
		frappe.set_user(user_with_role("Field Worker"))

		with self.assertRaises(frappe.PermissionError):
			frappe.get_doc(
				{"doctype": "Work Site", "site_name": "本社ビル", "client": "山田ビル管理"}
			).insert()
