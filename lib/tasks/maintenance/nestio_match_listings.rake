namespace :maintenance do
	desc 'update units public url with new URL from Nestio'
	task nestio_match_listings: :environment do
		log = ActiveSupport::Logger.new('log/nestio_match_listings.log')
		start_time = Time.now

		mechanize = Mechanize.new
		mechanize.user_agent_alias = "Mac Safari"
		mechanize.add_auth('https://nestiolistings.com/api/v2/sync/listings/?listing_type=rentals&listing_type=sales', '65c4bf89794a410aac9ba57eda1e78b1', '')
		mechanize.follow_meta_refresh = true

		def number_or_nil(string)
		  num = string.to_i
		  num if num.to_s == string
		end

		def mark_done(log, start_time)
			puts "Done!\n"
  		log.info "Done!\n"
  		end_time = Time.now
	    duration = (start_time - end_time) / 1.minute
	    log.info "Task finished at #{end_time} and last #{duration} minutes."
	    log.close
		end
		
		nestio_url = "https://nestiolistings.com/api/v2/sync/listings/?listing_type=rentals&listing_type=sales"

		# begin pulling down new data
		total_pages = 99
	  page = 1
	  page_count_limit = 50
	  max_id = 1
		puts "Pulling Nestio data for all listings...";
		log.info "Pulling Nestio data for all listings...";

	  done = false
	  for j in 1..total_pages
	  	if done
	  		mark_done(log, start_time)
	  		break
	  	end

	  	# try not to exceed google's rate limit
	  	puts "Page #{j} ----------------------------"
	  	log.info "Page #{j} ----------------------------"
	  	
	  	# if page != 1
	  	# 	max_id = pointer['next_id']
	  	# end
	  	 
	  	if page != 1
	  		page = mechanize.get("#{nestio_url}&max_id=#{max_id}")	
	  	else
	  		page = mechanize.get("#{nestio_url}")
	  	end
	  	json_data = JSON.parse page.body
	  	max_id = json_data['pointer']['next_id']
	    items = json_data['items']
	    

	    for i in 0..page_count_limit-1

	      # count = (page-1) * page_count_limit + i
	      # if count >= json_data['total_items']
	      #   done = true
	      #   break
	      # end
	      item = items[i]

	      if item.nil?
	      	done = true
	    	break
	      end
	      listing_id = item['description'][/MyspaceNYCListingID.*/].split(":")[1].strip.to_i
				unit = Unit.where(listing_id: listing_id).first
				nestio_id = item['id']
				public_url = "http://www.myspace-nyc.com/listings/#{nestio_id}/"
				if !unit
					puts "Listing id [#{listing_id}] nestio id: [#{nestio_id}]"
					#puts "#{unit.public_url != public_url} #{unit.public_url} #{public_url}"
				end

				if unit && (unit.public_url != public_url)
					puts "[#{i}] #{item['building']['street_address']} #{item['unit_number']} - updating unit"
	      	log.info "[#{i}] #{item['building']['street_address']} #{item['unit_number']} - updating unit"
					unit.update_columns(public_url: public_url)
				end
	    end


	  end
	  if !done
		  mark_done(log, start_time)
		end
	end
end
