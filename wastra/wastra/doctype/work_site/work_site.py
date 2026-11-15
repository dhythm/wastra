from frappe.model.document import Document


class WorkSite(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		address: DF.SmallText | None
		client: DF.Link
		equipment_notes: DF.Text | None
		site_name: DF.Data
	# end: auto-generated types
