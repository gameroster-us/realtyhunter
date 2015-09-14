class ListingSerializer < ActiveModel::Serializer
	attributes :listing_type, :property_type, :commercial_use, :min_lease_term, 
	:max_lease_term, :renter_fee, :bathrooms, :unit_amenities, :unit_description,
	:floor, :layout, :bedrooms, :unit_number, :pets, :status, :building, :date_available,
	:changed_at, :square_footage, :rent, :id

	attribute :building, serializer: BuildingSerializer

	def building
    BuildingSerializer.new(object.listing).attributes
  end

 attributes :contacts

	def contacts
		if object.primary_agents
			object
	      .primary_agents
	      .map { |x| ActiveModel::Serializer::Adapter::FlattenJson.new(PrimaryAgentSerializer.new(x)).as_json }			
		end
	end

 	attributes :photos

  def photos
  	if object.images
	    object
	      .images
	      .map { |x| ActiveModel::Serializer::Adapter::FlattenJson.new(ListingImageSerializer.new(x)).as_json }
	  end
  end

	def listing_type
		#building.respond_to?("neighborhood_name".to_sym)
		if object.listing.respond_to?(:r_id) || object.listing.respond_to?(:c_id)
			"rentals"
		else
			"sales"
		end
	end

	def property_type
		if object.listing.respond_to?(:r_id)
			"residential"
		elsif object.listing.respond_to?(:c_id)
			"commercial"
		end
	end

	def commercial_use
		nil
	# 	if object.listing.respond_to?(:c_id) && object.listing.commercial_property_type
	# 		object.listing.commercial_property_type.property_type
	# 	end
	end

	def min_lease_term
		if object.listing.respond_to?(:r_id)
			object.listing.lease_start
		elsif object.listing.respond_to?(:c_id)
			object.listing.lease_term_months
		end
	end

	def max_lease_term
		if object.listing.respond_to?(:r_id)
			object.listing.lease_end
		elsif object.listing.respond_to?(:c_id)
			object.listing.lease_term_months
		end
	end

	def renter_fee
		if object.listing.respond_to?(:r_id)
			if object.listing.tp_fee_percentage
				"Fee"
			else
				"No Fee"
			end
		elsif object.listing.respond_to?(:c_id)
			"Fee"
		end
	end

	def bathrooms
		if object.listing.respond_to?(:r_id)
			object.listing.baths
		elsif object.listing.respond_to?(:c_id)
			nil
		end
	end

	def unit_amenities
		if object.residential_amenities #object.listing.respond_to?(:r_id) &&
			object.residential_amenities.map{|a| a.name}
		else
			nil
		end
	end

	def unit_description
		if object.listing.respond_to?(:r_id)
			object.listing.description
		elsif object.listing.respond_to?(:c_id)
			object.listing.property_description
		end
	end

	def floor
		if object.listing.respond_to?(:r_id)
			nil
		elsif object.listing.respond_to?(:c_id)
			object.listing.floor
		end
	end

	def layout
		if object.listing.respond_to?(:r_id)
			object.listing.beds == 0 ? "Studio" : (object.listing.beds.to_s + ' Bedroom')
		else
			nil
		end
	end

	def bedrooms
		if object.listing.respond_to?(:r_id)
			object.listing.beds
		else
			nil
		end
	end

	def unit_number
		object.listing.building_unit
	end

	def pets
		if object.listing.respond_to?(:r_id) && object.pet_policies
			object.pet_policies[0].pet_policy_name
		else
			nil
		end
	end

	def status
		if object.listing.status == "active"
			"Active"
		elsif object.listing.status == "pending" ||
			object.listing.status == "offer_submitted" ||
			object.listing.status == "offer_accepted" ||
			object.listing.status == "binder_signed"
				"App Pending"
		elsif object.listing.status == "off" ||
			object.listing.status == "off_market_for_lease_execution"
			"Lease Out"
		end
	end


	def date_available
		if object.listing.available_by
			object.listing.available_by.strftime("%Y-%m-%d")
		else
			nil
		end
	end

	# TODO: open_house

	def changed_at
		object.listing.updated_at
	end

	def square_footage
		nil
	end

	def rent
		object.listing.rent
	end

	def id
		object.listing.listing_id
	end

end