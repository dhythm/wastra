from frappe.model.document import Document


class Client(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		client_name: DF.Data
		contact_person: DF.Data | None
		email: DF.Data | None
		phone: DF.Data | None
	# end: auto-generated types
