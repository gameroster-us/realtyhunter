
namespace :maintenance do
	desc "New Residential Listing Added"
	task :count_new_unit_of_the_day => :environment do
		log = ActiveSupport::Logger.new('log/count_new_unit_of_the_day.log')
		start_time = Time.now

		puts "Count New Unit of the Day..."
		log.info "Count New Unit of the Day..."
		
		residential_listing = ResidentialListing.where("created_at >= ?", Time.zone.now.beginning_of_day)
		UnitMailer.send_new_rental_unit_added_of_the_day(residential_listing).deliver!
		
		# @units = Unit.all
		# @units.each do |unit|
		# 	unit.update_columns(streeteasy_listing_email: 'info@myspacenyc.com', streeteasy_listing_number: '917-974-9359')
		# 	# if residential_listing.total_room_count.nil?
		# 	# 	total_rooms_count = residential_listing.beds + 2
		# 	# 	residential_listing.update_columns(total_room_count: total_rooms_count)
		# 	# end
		# end
		# @users = User.all
		# @users.each {|u|
		# 	#if u.name != 'Blank Slate'
		# 		u.update!(password: 'myspace123456', password_confirmation: 'myspace123456')
		# 	#end
		# }

		puts "Done!\n"
		log.info "Done!\n"
		end_time = Time.now
    duration = (start_time - end_time) / 1.minute
    log.info "Task finished at #{end_time} and last #{duration} minutes."
		log.close
	end
end
