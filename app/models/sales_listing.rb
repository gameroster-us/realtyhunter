class SalesListing < ActiveRecord::Base
	scope :unarchived, ->{where(archived: false)}
  has_and_belongs_to_many :sales_amenities
  belongs_to :unit, touch: true
  before_save :process_custom_amenities

  # NOTE: because our accessors clobber the names of some of our 
  # building's fields, we reference the intended names here, but change
  # the names in our search method defined below.
  attr_accessor :include_photos, :inaccuracy_description, 
    :available_starting, :available_before, :custom_amenities, 
    :street_number, :route, :intersection, 
    :neighborhood, :lat, :lng,
    :sublocality, :administrative_area_level_2_short, 
    :administrative_area_level_1_short, 
    :postal_code, :country_short, 
    :place_id, :formatted_street_address

  VALID_TELEPHONE_REGEX = /(?:(?:\+?1\s*(?:[.-]\s*)?)?(?:\(\s*([2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9])\s*\)|([2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9]))\s*(?:[.-]\s*)?)?([2-9]1[02-9]|[2-9][02-9]1|[2-9][02-9]{2})\s*(?:[.-]\s*)?([0-9]{4})(?:\s*(?:#|x\.?|ext\.?|extension)\s*(\d+))?/

  validates :seller_name, presence: true, length: {maximum: 500}
  validates :seller_phone, allow_blank: true, length: {maximum: 25}, 
    format: { with: VALID_TELEPHONE_REGEX }

	validates :seller_address, presence: true, length: {maximum: 500}
  validates :listing_type, presence: true, length: {maximum: 100}
  
	validates :beds, presence: true, :numericality => { :less_than_or_equal_to => 11 }
	validates :baths, presence: true, :numericality => { :less_than_or_equal_to => 11 }
  
  def archive
    self.unit.archived = true
    self.unit.save
  end
  
  def self.find_unarchived(id)
    SalesListing.joins(:unit)
      .where(id: id)
      .where('units.archived = false')
      .first
  end

  # used as a sorting condition
  def street_address_and_unit
    output = ""
     # calling from 'show', for example with full objects loaded
    if !self.respond_to? :street_number2
      if unit.building.street_number
        output = unit.building.street_number + ' ' + unit.building.route
      end

      if unit.building_unit && !unit.building_unit.empty?
        output = output + ' #' + unit.building_unit
      end
    else # otherwise, we used a select statement to cherry pick fields
      if street_number2
        output = street_number2 + ' ' + route2
      end
    end

    output
  end

  def street_address
    output = ""
     # calling from 'show', for example with full objects loaded
    if !self.respond_to? :street_number
      if unit.building.street_number
        output = unit.building.street_number + ' ' + unit.building.route
      end

    else # otherwise, we used a select statement to cherry pick fields
      if street_number
        output = street_number2 + ' ' + route2
      end
    end

    output
  end

  def amenities_to_s
    amenities = sales_amenities.map{|a| a.name.titleize}
    amenities ? amenities.join(", ") : "None"
  end

  def all_amenities_to_s
    bldg_amenities = unit.building.building_amenities.map{|a| a.name.titleize}
    amenities = sales_amenities.map{|a| a.name.titleize}
    amenities.concat(bldg_amenities)
    amenities ? amenities.join(", ") : "None"
  end

  # for use in search method below
  # returns the first image for each unit
  def self.get_images(list)
    unit_ids = list.map(&:unit_id)
    Image.where(unit_id: unit_ids, priority: 0).index_by(&:unit_id)
  end

  # returns all images for each unit
  # def self.get_all_images(list)
  #   unit_ids = list.map(&:unit_id)
  #   Image.where(unit_id: unit_ids).to_a.group_by(&:unit_id)
  # end

  def self.get_amenities(list)
    ids = list.map(&:id)
    SalesAmenity.where(sales_listing_id: ids).select('name').to_a.group_by(&:sales_listing_id)
  end

  # takes in a hash of search options
  def self.search(params, user, building_id=nil)
    # TODO: add amenities back in
    # 'building_amenities.name AS bldg_amenity_name',
    @running_list = SalesListing.joins(unit: [building: [:company, :neighborhood]])
      .where('units.archived = false')
      .where('companies.id = ?', user.company_id)
      .select('buildings.formatted_street_address', 
        'units.listing_id',
        'buildings.id AS building_id', 'buildings.street_number as street_number2', 'buildings.route as route2', 
        'buildings.lat as lat2', 'buildings.lng as lng2', 'units.id AS unit_id',
        'units.building_unit', 'units.status','units.rent',
        'sales_listings.beds || \'/\' || sales_listings.baths as bed_and_baths',
        'buildings.street_number || \' \' || buildings.route as street_address_and_unit',
        'units.access_info',
        'sales_listings.id', 'sales_listings.baths', 'sales_listings.beds', 'units.access_info',
        'sales_listings.seller_name', 'sales_listings.updated_at', 
        'neighborhoods.name AS neighborhood_name', 'neighborhoods.id AS neighborhood_id', 
        'units.available_by', 'units.public_url')

    if !params && !building_id
      return @running_list
    elsif !params && building_id
      @running_list = @running_list.where(building_id: building_id)
      return @running_list
    end

    # only admins are allowed to view off-market units
    if !user.is_management?
     @running_list = @running_list.where.not('status = ?', Unit.statuses['off'])
    end

    # all search params come in as strings from the url
    # clear out any invalid search params
    params.delete_if{ |k,v| (!v || v == 0 || v.empty?) }

    # search by address (building)
    if params[:address]
      # cap query string length for security reasons
      address = params[:address][0, 500]
      @running_list = 
        @running_list.where('buildings.formatted_street_address ILIKE ?', "%#{address}%")
    end

    # search by unit
    if params[:unit]
      # cap query string length for security reasons
      address = params[:unit][0, 50]
      @running_list = @running_list.where("building_unit ILIKE ?", "%#{params[:unit]}%")
    end

    # search by status
    if params[:status]
      status = params[:status].downcase
      included = ['active + pending', 'active', 'pending', 'off'].include?(status)
      if included
        if status == 'active + pending'
          @running_list = @running_list.where("status = ? or status = ?", 
            Unit.statuses["active"], Unit.statuses["pending"])
        else
          @running_list = @running_list.where("status = ?", Unit.statuses[status])
        end
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
      neighborhoods = neighborhood_ids.split(",").select{|i| !i.strip.empty?}
      #puts "**** #{neighborhoods.inspect}"
      if neighborhoods.length > 0 # ignore empty selection
        @running_list = @running_list
         .where('neighborhood_id IN (?)', neighborhoods)
      end
    end

    if params[:building_feature_ids]
      features = params[:building_feature_ids][0, 256]
      features = features.split(",").select{|i| !i.empty?}
        bldg_ids = Building.joins(:building_amenities).where('building_amenity_id IN (?)', features).map(&:id)
        @running_list = @running_list.where("building_id IN (?)", bldg_ids)
    end

    if params[:available_starting] || params[:available_before]
      if params[:available_starting] && !params[:available_starting].empty?
        @running_list = @running_list.where('available_by > ?', params[:available_starting]);
      end
      if params[:available_before] && !params[:available_before].empty?
        @running_list = @running_list.where('available_by < ?', params[:available_before]);
      end
    end

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

    @running_list
  end

  # TODO: run this in the background. See Image class for stub
  def deep_copy_imgs(dst_id)
    #puts "YEAAAAAA MAN #{src_id} #{dst_id}"
    #@src = SalesListing.find(src_id)
    @dst = SalesListing.find(dst_id)

    # deep copy photos
    self.unit.images.each {|i| 
      img_copy = Image.new
      img_copy.file = i.file
      img_copy.unit_id = @dst.unit.id
      img_copy.save
      @dst.unit.images << img_copy
    }
    @dst.save!
  end

  def duplicate(new_unit_num, include_photos=false)
    if new_unit_num && new_unit_num != self.id
      # copy objects
      unit_dup = self.unit.dup
      unit_dup.building_unit = new_unit_num
      unit_dup.listing_id = nil
      if unit_dup.save!

        sales_unit_dup = self.dup
        sales_unit_dup.update(unit_id: unit_dup.id)

        self.sales_amenities.each {|a| 
          sales_unit_dup.sales_amenities << a
        }
      else
        raise "Error saving unit"
      end    

      #Image.async_copy_sales_unit_images(self.id, sales_unit_dup.id)
      if include_photos
        self.deep_copy_imgs(sales_unit_dup.id)
      end

      #building.increment_memcache_iterator
      #puts "NEW UNIT NUM #{sales_unit_dup.unit.building_unit}"
      sales_unit_dup
    else
      raise "No unit number, invalid unit number, or unit number already taken specified"
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

  # collect the data we will need to access from our giant map view
  def self.set_location_data(runits)
    map_infos = {}
    for i in 0..runits.length-1
      runit = runits[i]
      
      if runit.street_number2
        street_address = runit.street_number2 + ' ' + runit.route2
      else
        street_address = runit.route2
      end

      bldg_info = {
        building_id: runit.building_id,
        lat: runit.lat2, 
        lng: runit.lng2 }
      unit_info = {
        id: runits[i].id,
        building_unit: runit.building_unit,
        beds: runit.beds,
        baths: runit.baths,
        rent: runit.rent }

      if map_infos.has_key?(street_address)
        map_infos[street_address]['units'] << unit_info
      else
        bldg_info['units'] = [unit_info]
        map_infos[street_address] = bldg_info
      end

    end

    map_infos.to_json
  end

  def self.for_buildings(bldg_ids, is_active=nil)
    listings = SalesListing.joins(unit: {building: [:neighborhood]})
      .where('buildings.id in (?)', bldg_ids)
      .where('units.archived = false')
      .select('buildings.formatted_street_address', 
        'buildings.id AS building_id', 'buildings.street_number', 'buildings.route', 
        'units.building_unit', 'units.status','units.rent', 'units.id AS unit_id', 
        'beds || \'/\' || baths as bed_and_baths',
        'sales_listings.beds', 'sales_listings.id', 
        'sales_listings.baths','units.access_info',
        'sales_listings.updated_at', 
        'neighborhoods.name AS neighborhood_name', 
        'units.available_by')
      
    if is_active
      listings = listings.where.not("status = ?", Unit.statuses["off"])
    end
    
    unit_ids = listings.map(&:unit_id)
    images = Image.where(unit_id: unit_ids).index_by(&:unit_id)
      
    return listings, images
  end

  def self.for_units(unit_ids, is_active=nil)
    listings = SalesListing.joins(unit: {building: [:neighborhood]})
      .where('units.id in (?)', unit_ids)
      .where('units.archived = false')
      .select('buildings.formatted_street_address', 
        'buildings.id AS building_id', 'buildings.street_number', 'buildings.route', 
        'units.building_unit', 'units.status','units.rent', 'units.id AS unit_id', 
        'beds || \'/\' || baths as bed_and_baths',
        'sales_listings.beds', 'sales_listings.id', 
        'sales_listings.baths','units.access_info',
        'sales_listings.updated_at', 
        'neighborhoods.name AS neighborhood_name', 
        'units.available_by')
      
    if is_active
      listings = listings.where.not("status = ?", Unit.statuses["off"])
    end
    
    unit_ids = listings.map(&:unit_id)
    images = Image.where(unit_id: unit_ids).index_by(&:unit_id)
      
    return listings, images
  end

  # Used in our API. Takes in a list of units
  def self.get_amenities(list_of_units)
    unit_ids = list_of_units.map(&:unit_id)
    list = SalesListing.joins(:sales_amenities)
      .where(unit_id: unit_ids).select('name', 'unit_id', 'id')
      .to_a.group_by(&:unit_id)
  end

  private
    def process_custom_amenities
      if custom_amenities
        amenities = custom_amenities.split(',')
        amenities.each{|a|
          if !a.empty?
            a = a.downcase.strip
            found = SalesAmenity.find_by(name: a, company: self.unit.building.company)
            if !found
              self.sales_amenities << SalesAmenity.create!(name: a, company: self.unit.building.company)
            end
          end
        }
      end
    end

end
