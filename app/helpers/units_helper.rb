module UnitsHelper

	def occupancy_status(unit)
		if unit.tenant_occupied
			'<strong>Tenant Occupied</strong>'.html_safe
		else
			'<strong>Unit vacant</strong>'.html_safe
		end
	end

	def lease_duration(unit)
		str = '';

		if unit.lease_start
			str = str + unit.lease_start
		end

		if unit.lease_end
			str = ' ' + str + ' to ' + unit.lease_end
		end

		str = str + ' Months'
	end


	# Formats one audit trail record
	# Ex: Bob changed status, access info, rent from $500 to $1000 on MM/DD/YYY.
	def _pretty_print_one_audit(audit)
		retVal = []
		viewable_fields = ['beds', 'baths', 'rented date', 'access info', 'description', 'notes',
				'status', 'primary agent id', 'primary agent id2']

		audit.audited_changes.each do |key, val|
			key = key.gsub('_', ' ')
			if key == 'rent' || key == 'price'
				retVal.push("#{key} from $#{val[0]} to $#{val[1]}")
			elsif key == 'primary agent id' || key == 'primary agent id2'
				retVal.push('primary agent')
			elsif viewable_fields.include? key
				retVal.push("#{key}")
			end
		end

		if audit.user
			user_name = audit.user.name
		else
			user_name = "[System Automated Update]"
		end

		if retVal.length > 0
			return "#{user_name} changed #{retVal.join(', ')} on " + audit.created_at.strftime("%b-%d-%Y %I:%M %P")
		else
			return "#{user_name} made changes on " + audit.created_at.strftime("%b-%d-%Y %I:%M %P")
		end
	end

	# Get the set of 10 most recent changes, sorted according to timestamp. The most
	# recent will be listed first (reverse chronological order).
	# Returns a list with max 10 printed entries.
	def pretty_audit_changes(listing)
		output = {}
		# look at the unit's changes
		for i in 0..listing.unit.audits.length-1
			audit = listing.unit.audits[i]
			formatted_audit = _pretty_print_one_audit(audit)
			creation_unix_time = audit.created_at.to_time.to_i
			if !output[creation_unix_time]
				output[creation_unix_time] = [formatted_audit]
			else
				output[creation_unix_time].push(formatted_audit)
			end
		end

		# now look at the listing itself
		for i in 0..listing.audits.length-1
			audit = listing.audits[i]
			formatted_audit = _pretty_print_one_audit(audit)

			creation_unix_time = audit.created_at.to_time.to_i
			if !output[creation_unix_time]
				output[creation_unix_time] = [formatted_audit]
			else
				output[creation_unix_time].push(formatted_audit)
			end
		end

		output = output.sort{|a, b| b[0] <=> a[0]}
		output.take(10).to_h
	end

end
