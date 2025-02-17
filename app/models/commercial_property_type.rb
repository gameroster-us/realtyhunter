class CommercialPropertyType < ApplicationRecord
	belongs_to :company, touch: true
	has_many :commercial_units

	def self.subtypes_for(term, company)
		CommercialPropertyType.where(company: company)
			.where('property_type ILIKE (?)', "%#{term}").distinct
	end

end
