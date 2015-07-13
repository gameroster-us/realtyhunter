class ResidentialUnit < ActiveRecord::Base
	acts_as :unit
  scope :unarchived, ->{where(archived: false)}
  has_and_belongs_to_many :residential_amenities
  before_validation :generate_unique_id
  after_update :clear_cache
  after_destroy :clear_cache

  attr_accessor :include_photos, :inaccuracy_description, 
    :pet_policy_shorthand, :available_starting, :available_before

  validates :building_unit, presence: true, length: {maximum: 50}

	validates :lease_duration, presence: true, length: {maximum: 50}
  
  validates :rent, presence: true, :numericality => { :greater_than => 0 }
	validates :beds, presence: true, :numericality => { :less_than_or_equal_to => 11 }
	validates :baths, presence: true, :numericality => { :less_than_or_equal_to => 11 }
  
  validates :op_fee_percentage, allow_blank: true, length: {maximum: 3}, numericality: { only_integer: true }
  validates_inclusion_of :op_fee_percentage, :in => 0..100, allow_blank: true

  validates :tp_fee_percentage, allow_blank: true, length: {maximum: 3}, numericality: { only_integer: true }
  validates_inclusion_of :tp_fee_percentage, :in => 0..100, allow_blank: true

  #validates :weeks_free_offered, allow_blank: true, length: {maximum: 3}, numericality: { only_integer: true }

  def memcache_iterator
    # fetch the user's memcache key
    # If there isn't one yet, assign it a random integer between 0 and 10
    Rails.cache.fetch("runit-#{id}-memcache-iterator") { rand(10) }
  end

  def cache_key
    "runit-#{id}-#{self.memcache_iterator}"
  end

  def cached_building
    Rails.cache.fetch("#{cache_key}-building") {
      building
    }
  end

  def cached_neighborhood
    Rails.cache.fetch("#{cache_key}-neighborhood") {
      cached_building.neighborhood
    }
  end

  def cached_pet_policy
    Rails.cache.fetch("#{cache_key}-pet_policy") {
      cached_building.pet_policy
    }
  end

  def cached_landlord
    Rails.cache.fetch("#{cache_key}-landlord") {
      cached_building.landlord
    }
  end

  def cached_primary_img
    Rails.cache.fetch("#{cache_key}-primary_img") {
      images[0] ? images[0] : nil
    }
  end

  def cached_street_address
    Rails.cache.fetch("#{cache_key}-street_address") {
      cached_building.street_address
    }
    #building.street_address
  end

  def archive
    self.archived = true
    self.save
  end
  
  def self.find_unarchived(id)
    find_by!(id: id, archived: false)
  end
  
  # used as a sorting condition
  def street_address_and_unit
    if cached_building.street_number
      cached_building.street_number + ' ' + cached_building.route + ' #' + building_unit
    else
      cached_building.route + ' #' + building_unit
    end
  end

  # used as a sorting condition
  def landlord_by_code
    cached_landlord.code
  end

  # used as a sorting condition
  def bed_and_baths
    "#{beds} / #{baths}"
  end

	def amenities_to_s
		amenities = residential_amenities.map{|a| a.name.titleize}
		amenities ? amenities.join(", ") : "None"
	end

  def all_amenities_to_s
    bldg_amenities = building.building_amenities.map{|a| a.name.titleize}
    amenities = residential_amenities.map{|a| a.name.titleize}
    amenities.concat(bldg_amenities)
    amenities ? amenities.join(", ") : "None"
  end

  # mainly for use in our API. Returns list of any
  # agent contacts for this listing. Currently we have
  # 1 primary agent for each listing, but could change in the future.
  def contacts
    contacts = [primary_agent];
  end

  # For now, always calculate off a 12 month lease
  # def net_rent

    # months = 12

    # case(lease_duration)
    # when "year"
    #   months = 12
    # when "thirteen_months"
    #   months = 13
    # when "fourteen_months"
    #   months = 14
    # when "fifteen_months"
    #   months = 15
    # when "sixteen_months"
    #   months = 16
    # when "seventeen_months"
    #   months = 17
    # when "eighteen_months"
    #   months = 18
    # when "two_years"
    #   months = 24
    # else
    #   months = 12
    # end
    
    # total_rent = rent * months
    # rent_per_week = total_rent / (months * 4)
    # net_rent = total_rent - (rent_per_week * weeks_free_offered)
    # net_rent_per_month = net_rent / months
    # net_rent_per_month
  # end

  # mainly used in API
  # prints layout in Nestio's format
  def beds_to_s
    beds == 0 ? "Studio" : (beds.to_s + ' Bedroom')
  end

  # takes in a hash of search options
  # can be formatted_street_address, landlord
  # status, unit, bed_min, bed_max, bath_min, bath_max, rent_min, rent_max, 
  # neighborhoods, has_outdoor_space, features, pet_policy, ...
  def self.search(params, user, building_id=nil)
    #puts "PARAMS #{params.inspect}"
    if !params && !building_id
      return ResidentialUnit.unarchived
    elsif !params && building_id
      return ResidentialUnit.unarchived.where(building_id: building_id)
    end

    @running_list = Unit.includes(:building).unarchived

    # only admins are allowed to view off-market units
    if user.is_management?
      @running_list = @running_list.on_market
    end

    # all search params come in as strings from the url
    # clear out any invalid search params
    params.delete_if{ |k,v| (!v || v == 0 || v.empty?) }

    # search by address (building)
    if params[:address]
      # cap query string length for security reasons
    	address = params[:address][0, 500]
      @running_list = @running_list.joins(:building)
       .where('formatted_street_address ILIKE ?', "%#{address}%")
    end

    # search by unit
    if params[:unit]
      # cap query string length for security reasons
      address = params[:unit][0, 50]
      @running_list = @running_list.where("building_unit = ?", params[:unit])
    end

    # search by status
    if params[:status]
      status = params[:status].downcase
      included = %w[active pending off].include?(status)
      if included
       @running_list = @running_list.where("status = ?", Unit.statuses[status])
      end
    end

    # search by rent
    if params[:rent_min] && params[:rent_max]
      @running_list = @running_list.where("rent >= ? AND rent <= ?", params[:rent_min], params[:rent_max])
    elsif params[:rent_min] && !params[:rent_max]
      @running_list = @running_list.where("rent >= ?", params[:rent_min])
    elsif !params[:rent_min] && params[:rent_max]
      @running_list = @running_list.where("rent <= ?", params[:rent_max])
    end

    # search neighborhoods
    if params[:neighborhood_ids]
      neighborhood_ids = params[:neighborhood_ids][0, 256]
      neighborhoods = neighborhood_ids.split(",").select{|i| !i.empty?}
      @running_list = @running_list.joins(building: :neighborhood)
       .where('neighborhood_id IN (?)', neighborhoods)
    end

    if params[:building_feature_ids]
      features = params[:building_feature_ids][0, 256]
      features = features.split(",").select{|i| !i.empty?}
        @running_list = @running_list.joins(building: :building_amenities)
        .where('building_amenity_id IN (?)', features)
    end

    # search landlord code
    if params[:landlord]
      @running_list = @running_list.joins(building: :landlord)
      .where("code ILIKE ?", "%#{params[:landlord]}%")
    end

    # search pet policy
    if params[:pet_policy_shorthand]
      pp = params[:pet_policy_shorthand].downcase
      policies = nil
      if pp == "none"
        policies = PetPolicy.where(name: "no pets", company: user.company)
      elsif pp == "cats only"
        policies = PetPolicy.policies_that_allow_cats(user.company, true)
      elsif pp == "dogs only"
        policies = PetPolicy.policies_that_allow_dogs(user.company, true)
      end

      if policies
        @running_list = @running_list.joins(building: :pet_policy)
          .where('pet_policy_id IN (?)', policies.ids)
      end
    end

    if params[:available_starting] || params[:available_before]
      sql = nil
      if params[:available_starting]
        sql = 'available_starting > ? '
      end
      if params[:available_before]
        sql = 'available_by < ? '
      end
      @running_list = @running_list.where(sql, "%#{params[:available_before]}%", "%#{params[:available_starting]}%")
    end

    # the following fields are on ResidentialUnit not Unit, so cast the 
    # objects first
    @running_list = Unit.get_residential(@running_list)

    # search beds
    if params[:bed_min] && params[:bed_max]
      @running_list = @running_list.where("beds >= ? AND beds <= ?", params[:bed_min], params[:bed_max])
    elsif params[:bed_min] && !params[:bed_max]
      @running_list = @running_list.where("beds >= ?", params[:bed_min])
    elsif !params[:bed_min] && params[:bed_max]
      @running_list = @running_list.where("beds <= ?", params[:bed_max])
    end

    # search baths
    if params[:bath_min] && params[:bath_max]
      @running_list = @running_list.where("baths >= ? AND baths <= ?", params[:bath_min], params[:bath_max])
    elsif params[:bath_min] && !params[:bath_max]
      @running_list = @running_list.where("baths >= ?", params[:bath_min])
    elsif !params[:bath_min] && params[:bath_max]
      @running_list = @running_list.where("baths <= ?", params[:bath_max])
    end

    # search by brokers fee
    if params[:has_fee]
      has_fee = params[:has_fee].downcase
      included = %w[yes no].include?(has_fee)
      if included
        @running_list = @running_list.where(has_fee: has_fee == "yes")
      end
    end

    # search features
    if params[:unit_feature_ids]
      # sanitize input
      features = params[:unit_feature_ids][0, 256]
      features = features.split(",").select{|i| !i.empty?}
      @running_list = @running_list.joins(:residential_amenities)
        .where('residential_amenity_id IN (?)', features)
    end

    @running_list.uniq
	end

  # TODO: run this in the background. See Image class for stub
  def deep_copy(src_id, dst_id)
    #puts "YEAAAAAA MAN #{src_id} #{dst_id}"
    @src = ResidentialUnit.find(src_id)
    @dst = ResidentialUnit.find(dst_id)

    # deep copy photos
    @src.images.each {|i| 
      img_copy = Image.new
      img_copy.file = i.file
      img_copy.save
      @dst.images << img_copy
    }
    @dst.save
  end

  def duplicate(new_unit_num, include_photos)
    if new_unit_num && new_unit_num != self.id
        # copy object
        residential_unit_dup = self.dup
        residential_unit_dup.building_unit = new_unit_num
        residential_unit_dup.save

        #Image.async_copy_residential_unit_images(self.id, residential_unit_dup.id)
        self.deep_copy(self.id, residential_unit_dup.id)
        residential_unit_dup.save

        building.increment_memcache_iterator
        residential_unit_dup
    else
      raise "No unit number or invalid unit number specified"
    end
  end

  def send_inaccuracy_report(reporter)
    if reporter
      UnitMailer.inaccuracy_reported(self, reporter).deliver_now
    else 
      raise "No reporter specified"
    end
  end

  def take_off_market(new_lease_end_date)
    if new_lease_end_date
      update({status: :off,
              available_by: new_lease_end_date})
    else
      raise "No lease end date specified"
    end
  end

  def calc_lease_end_date
    end_date = Date.today
    end_date = Date.today >> 12
    # case(lease_duration)
    # when "year"
    #   end_date = Date.today >> 12
    # when "thirteen_months"
    #   end_date = Date.today >> 13
    # when "fourteen_months"
    #   end_date = Date.today >> 14
    # when "fifteen_months"
    #   end_date = Date.today >> 15
    # when "sixteen_months"
    #   end_date = Date.today >> 16
    # when "seventeen_months"
    #   end_date = Date.today >> 17
    # when "eighteen_months"
    #   end_date = Date.today >> 18
    # when "two_years"
    #   end_date = Date.today >> 24
    # else
    #   end_date = Date.today >> 12
    # end
    
    end_date
  end

  # collect the data we will need to access from our giant map view
  def self.set_location_data(runits)
    map_infos = {}
    for i in 0..runits.length-1
      bldg = runits[i].cached_building
      street_address = bldg.street_address
      bldg_info = {
        building_id: bldg.id,
        lat: bldg.lat, 
        lng: bldg.lng }
      unit_info = {
        id: runits[i].id,
        building_unit: runits[i].building_unit,
        beds: runits[i].beds,
        baths: runits[i].baths,
        rent: runits[i].rent }

      if map_infos.has_key?(street_address)
        map_infos[street_address]['units'] << unit_info
      else
        bldg_info['units'] = [unit_info]
        map_infos[street_address] = bldg_info
      end

    end

    map_infos.to_json
  end

  def clear_cache
    increment_memcache_iterator
    building.increment_memcache_iterator
  end
  
  private
    def generate_unique_id
      self.listing_id = SecureRandom.random_number(9999999)
      while ResidentialUnit.find_by(listing_id: listing_id) do
        self.listing_id = rand(9999999)
      end
      self.listing_id
    end

    # we can't expire old keys with a regex or delete_matched on dalli
    # instead use the strategy suggested here:
    # https://quickleft.com/blog/faking-regex-based-cache-keys-in-rails/
    def increment_memcache_iterator
      Rails.cache.write("runit-#{id}-memcache-iterator", self.memcache_iterator + 1)
    end

end
