class ResidentialListingsController < ApplicationController
  load_and_authorize_resource
  skip_load_resource only: :create
  before_action :set_specific_residential_listing, only: [:specific_edit]
  before_action :set_residential_listing, only: [:show, :agent_show, :edit, :agent_edit, :agent_update, :specific_edit, :duplicate_modal, :duplicate,
    :mark_app_submitted, :update, :delete_modal, :destroy,
    :inaccuracy_modal, :send_inaccuracy, :refresh_images, :refresh_documents, :favourite_listings]
  autocomplete :building, :formatted_street_address, full: true
  autocomplete :landlord, :code, full: true
  include KnackInterface

  def index
    building = Building.all.map(&:point_of_contact).compact.uniq
    @user = []
    building.each do |build|
      u = User.find(build)
      @user << [u.name, u.id]
    end
    respond_to do |format|
      format.html.phone do
        set_residential_listings
      end
      # tablets get treated the same as desktops
      format.html.desktop do
        set_residential_listings
      end
      format.js do
        set_residential_listings
      end
      format.csv do
        set_residential_listings_csv
        headers['Content-Disposition'] = "attachment; filename=\"" +
          current_user.name + " - Residential Listings.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
  end

  def index_main
    respond_to do |format|
      format.html.phone do
        set_residential_listings
      end
      # tablets get treated the same as desktops
      format.html.desktop do
        set_residential_listings
      end
      format.js do
        set_residential_listings
      end
      format.csv do
        set_residential_listings_csv
        headers['Content-Disposition'] = "attachment; filename=\"" +
          current_user.name + " - Residential Listings.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
  end

  def index_streeteasy
    respond_to do |format|
      format.html.phone do
        set_residential_listings
      end
      # tablets get treated the same as desktops
      format.html.desktop do
        set_residential_listings
      end
      format.js do
        set_residential_listings
      end
      format.csv do
        set_residential_listings_csv
        headers['Content-Disposition'] = "attachment; filename=\"" +
          current_user.name + " - Residential Listings.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
  end

  # AJAX call
  def filter
    set_residential_listings
    respond_to do |format|
      format.js
      format.html do
        # catch-all
        redirect_to residential_listings_url
      end
    end
  end

  def show
  end

  def new
    @residential_unit = ResidentialListing.new
    @residential_unit.unit = Unit.new
    if params[:building_id]
      building = Building.find(params[:building_id])
      @residential_unit.unit.building_id = building.id
    end
    @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
    @panel_title = "Add a listing"
  end

  def edit
    @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
    @panel_title = "Edit listing"
  end

  def rental_mobile_search

  end

  def rental_mobile_search_result
    #@result = Building.where("formatted_street_address LIKE ?", "%#{params[:address]}%")
    running_list = ResidentialListing.joins(unit: {building: [:company, :landlord]})
      .joins('left join neighborhoods on neighborhoods.id = buildings.neighborhood_id')
      .joins('left join users on users.id = units.primary_agent_id')
      .where('units.archived = false')
      .where('companies.id = ?', current_user.company_id)
      .select('buildings.formatted_street_address',
        'buildings.id AS building_id', 'buildings.street_number', 'buildings.route',
        'buildings.lat', 'buildings.lng', 'units.id AS unit_id',
        'units.building_unit', 'units.status','units.rent', 'residential_listings.beds',
        'units.primary_agent_id',  'units.has_stock_photos',
        'buildings.street_number || \' \' || buildings.route as street_address_and_unit',
        'residential_listings.id', 'residential_listings.baths','units.access_info',
        'residential_listings.favorites',
        'residential_listings.has_fee', 'residential_listings.updated_at',
        'residential_listings.tenant_occupied',
        'neighborhoods.name AS neighborhood_name', 'neighborhoods.id AS neighborhood_id',
        'landlords.code',
        'landlords.id AS landlord_id',
        'units.listing_id', 'units.available_by', 'units.public_url', 'units.exclusive',
        'users.name')
      #abort running_list.inspect
    if !params && !building_id
      running_list
    elsif !params && building_id
      running_list = running_list.where(building_id: building_id)
    else
      running_list = ResidentialListing._filter_query(running_list, current_user, params)
    end
    @result = running_list
  end

  # def send_custom_email

  # end

  # def generate_custom_email
  #   #abort params[:to_address].split(/\s*,\s*/).inspect
  #   UnitMailer.send_custom_email_with_mailgun(params[:from_address],params[:to_address], params[:subject],params[:body]).deliver!
  #   redirect_to send_custom_email_path
  # end
  def agent_edit
    @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
    @panel_title = "Edit listing"
  end

  def agent_update
    residential_listing = ResidentialListing.find(params[:id])
    if params[:residential_listing][:naked_apartment] == "1"
      claim_for_naked_aprt = residential_listing.claim_for_naked_apartment << current_user.id
    else
      claim_for_naked_aprt = residential_listing.claim_for_naked_apartment - ["#{current_user.id}"]
    end
    residential_listing.update(description: params[:residential_listing][:description], naked_apartment: params[:residential_listing][:naked_apartment], claim_for_naked_apartment: claim_for_naked_aprt, updated_at: Time.now())
    flash[:success] = 'Residential unit was successfully Updated.'
    redirect_to agent_show_path(residential_listing)
  end

  def agent_show
    
  end


  def specific_edit
    @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
    @panel_title = "Edit listing"
  end

  def specific_update
    
    if params[:residential_listing][:unit][:gross_price].to_i > 0
      params[:residential_listing][:unit][:rent] = (params[:residential_listing][:unit][:gross_price].to_i * (params[:residential_listing][:lease_start].to_i - params[:residential_listing][:unit][:maths_free].to_f)) / params[:residential_listing][:lease_start].to_i
      params[:residential_listing][:unit][:rent] = params[:residential_listing][:unit][:rent].round

    else
      params[:residential_listing][:unit][:gross_price] = 0
    end
    #abort params[:residential_listing][:unit][:open_houses_attributes].to_a.inspect
    #abort params[:id].inspect
    #abort params[:residential_listing][:unit][:open_houses_attributes].to_a[1][1].inspect
    residential_listing = ResidentialListing.find(params[:id])

    # residential_listing.residential_amenities.each.map{ |a| "#{a.id}" }
    # abort params[:residential_listing][:residential_amenity_ids].inspect
    residential_listing.residential_amenities.delete_all
    params[:residential_listing][:residential_amenity_ids].each do |id|
      if !id.blank?
        #abort residential_listing.residential_amenities.find(id).present?.inspect
        te = ResidentialAmenity.find(id)
        if residential_listing.residential_amenities.blank?
          #abort residential_listing.residential_amenities.inspect
          residential_listing.residential_amenities << te
        else
        #   #abort residential_listing.residential_amenities.find(id).present?.inspect
        #   if !residential_listing.residential_amenities.find(id).present?
        #     abort residential_listing.residential_amenities.find(id).present?.inspect
             residential_listing.residential_amenities << te
        #   end
        end
          #residential_listing.residential_amenities << haha
      end
    end

    if params[:residential_listing][:streeteasy_flag_one] == "0"
      residential_listing.update(streeteasy_claim: true, updated_at: Time.now())
      residential_listing.unit.update(streeteasy_primary_agent_id: nil)
    end

    if params[:residential_listing][:streeteasy_flag_one] == "1"
      residential_listing.update(streeteasy_flag: false, streeteasy_claim: false, updated_at: Time.now())
      residential_listing.unit.update(streeteasy_primary_agent_id: current_user.id, updated_at: Time.now())
    end

    tee = residential_listing.update(lease_start: params[:residential_listing][:lease_start], lease_end: params[:residential_listing][:lease_end], description: params[:residential_listing][:description], streeteasy_flag_one: params[:residential_listing][:streeteasy_flag_one], updated_at: Time.now())

    #unit_available_by = Date::strptime(params[:residential_listing][:unit][:available_by], "%m/%d/%Y") + 1.day
    unit = residential_listing.unit
    tee = unit.update_columns(has_stock_photos: params[:residential_listing][:unit][:has_stock_photos], rent: params[:residential_listing][:unit][:rent], gross_price: params[:residential_listing][:unit][:gross_price], maths_free: params[:residential_listing][:unit][:maths_free], updated_at: Time.now())

    #find_open_house.delete_all
    params[:residential_listing][:unit][:open_houses_attributes].to_a.each do |a|
      if a[1][:"_destroy"].present?
        tt = OpenHouse.find(a[1][:id])

        tt.destroy
        #exit
      end
      #abort a[1][:day].inspect
      day = Date::strptime(a[1][:day], "%m/%d/%Y")
      #abort a[1][:"start_time(5i)"].inspect
      start_time =  a[1][:"start_time(4i)"] + ":" + a[1][:"start_time(5i)"] + ":" + "00"
      end_time =  a[1][:"end_time(4i)"] + ":" + a[1][:"end_time(5i)"] + ":" + "00"
      unit_id = unit.id
      find_open_house = OpenHouse.where(unit_id: unit_id, day: day)
      if !a[1][:"_destroy"].present?
        if find_open_house.blank?
          #abort a[1].inspect
          openhouse = OpenHouse.create(day: day, start_time: start_time, end_time: end_time, unit_id: unit_id)
          #abort openhouse.inspect
        end
      end
    end

      flash[:success] = 'Residential unit was successfully Updated.'
      redirect_to residential_listing_url(residential_listing)
  end

  def create
    new_unit = nil
    if params[:residential_listing][:unit][:price_calculation] == "1"
      params[:residential_listing][:unit][:rent] = (params[:residential_listing][:unit][:gross_price].to_i * (params[:residential_listing][:lease_start].to_i - params[:residential_listing][:unit][:maths_free].to_f)) / params[:residential_listing][:lease_start].to_i
      params[:residential_listing][:unit][:rent] = params[:residential_listing][:unit][:rent].round
    else
      if params[:residential_listing][:unit][:gross_price].blank?
        params[:residential_listing][:unit][:gross_price] = 0
      end
    end
    ResidentialListing.transaction do
      new_unit = Unit.new(residential_listing_params[:unit])
      r_params = residential_listing_params
      r_params.delete('unit')
      @residential_unit = ResidentialListing.new(r_params)
      @residential_unit.unit = new_unit
    end

    if !new_unit.available_by?
      new_unit.available_by = Date.today
    end

    if new_unit.save && @residential_unit.save
      @bb = Building.find(params[:residential_listing][:unit][:building_id])
      if !params[:residential_listing][:unit][:available_by].blank?
        @avail_date = params[:residential_listing][:unit][:available_by]
      end
      if params[:residential_listing][:lease_start]
        @lease_st = params[:residential_listing][:lease_start]
      end
      if params[:residential_listing][:lease_end]
        @lease_ed = params[:residential_listing][:lease_end]
      end
      if @residential_unit.unit.building.landlord
        @ll_code = @residential_unit.unit.building.landlord.code
      end
      if params[:residential_listing][:has_fee] == "0"
        if !params[:residential_listing][:op_fee_percentage].blank?
          @has_fee = "Op Pays: #{params[:residential_listing][:op_fee_percentage]}% \n"
        end
      end
      if params[:residential_listing][:has_fee] == "1"
        if !params[:residential_listing][:tp_fee_percentage].blank?
          @has_fee = "Tp Pays: #{params[:residential_listing][:tp_fee_percentage]}% \n"
        end
      end
      if @bb.neighborhood.parent_neighborhood_id == 55 || @bb.neighborhood.parent_neighborhood_id == 56 || @bb.neighborhood.parent_neighborhood_id == 57
        notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
          defaults channel: "#default",
                   username: "notifier"
        end
      elsif @bb.neighborhood.parent_neighborhood_id == 54
        notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
          defaults channel: "#default",
                   username: "notifier"
        end
      end
      notifier.ping "*New* *Unit* \n #{current_user.name} Added New Unit \n #{@bb.street_number} #{@bb.route}, #{params[:residential_listing][:unit][:building_unit]} \n #{@bb.neighborhood.name} \n #{params[:residential_listing][:beds]} Beds / #{params[:residential_listing][:baths]} Baths \n Net #{params[:residential_listing][:unit][:rent]} / Gross #{params[:residential_listing][:unit][:gross_price]} \n Avail: #{@avail_date} \n Lease: #{@lease_st} to #{@lease_ed} Months \n #{@has_fee} \n LLC: #{@ll_code} \n POC: #{@poc} \n Access: #{params[:residential_listing][:unit][:access_info]} \n ---"

      UnitMailer.send_email_at_new_unit_create(params[:residential_listing][:unit][:building_id], params[:residential_listing][:unit][:building_unit],params[:residential_listing][:beds],params[:residential_listing][:baths],params[:residential_listing][:unit][:rent],params[:residential_listing][:residential_amenity_ids].reject(&:empty?),params[:residential_listing][:unit][:access_info],params[:residential_listing][:notes],params[:residential_listing][:unit][:available_by],params[:residential_listing][:has_fee],params[:residential_listing][:tp_fee_percentage],params[:residential_listing][:op_fee_percentage], params[:residential_listing][:lease_start], params[:residential_listing][:lease_end],current_user.name).deliver!
      # keep track of whether this listing just came on or off the market
      is_now_active = @residential_unit.unit.status == 'active'
      Resque.enqueue(CreateResidentialListing, @residential_unit.id, is_now_active) # send to Knack
      redirect_to @residential_unit
    else
      @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
      render 'new'
    end
  end

  # GET
  # handles ajax call. uses latest data in modal
  def duplicate_modal
    respond_to do |format|
      format.js
    end
  end

  # POST
  # handles ajax call. uses latest data in modal
  def duplicate
    residential_unit_dup = @residential_unit.duplicate(
      residential_listing_params[:unit][:building_unit],residential_listing_params[:unit][:streeteasy_unit],
      residential_listing_params[:include_photos])
    if residential_unit_dup.valid?
      @residential_unit = residential_unit_dup
      # UnitMailer.send_email_at_new_unit_duplicate(@residential_unit.unit.building.id, residential_listing_params[:unit][:building_unit],@residential_unit.beds,@residential_unit.baths,@residential_unit.unit.rent,@residential_unit.residential_amenities.each.map(&:name).join(","),@residential_unit.unit.access_info,@residential_unit.notes,@residential_unit.unit.available_by.strftime("%m/%d/%Y"),@residential_unit.tp_fee_percentage,@residential_unit.op_fee_percentage, @residential_unit.lease_start, @residential_unit.lease_end,current_user.name).deliver!
      # keep track of whether this listing just came on or off the market
      is_now_active = @residential_unit.unit.status == 'active'
      Resque.enqueue(CreateResidentialListing, @residential_unit.id, is_now_active) # send to Knack
      render js: "window.location.pathname = '#{residential_listing_path(@residential_unit)}'"
    else
      @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
      # TODO: not sure how to handle this best...
      flash[:warning] = "Duplication failed!"
      respond_to do |format|
        format.js
      end
    end
  end

  def mark_app_submitted
    @residential_unit.unit.mark_app_submitted(current_user, 'residential', 'pending')
    @residential_unit.set_rented_date
    set_residential_listings
    flash[:info] = 'Application submitted on ' +
      @residential_unit.unit.building.street_address + ' and announcement sent!'
    redirect_to request.referer
  end

  # sends listings info to clients
  def send_listings
    recipients = residential_listing_params[:recipients].split(/[\,,\s]/)
    sub = residential_listing_params[:title]
    msg = residential_listing_params[:message]
    from = residential_listing_params[:from]
    listing_ids = residential_listing_params[:listing_ids].split(',')
    ResidentialListing.send_listings(current_user.id, listing_ids, recipients, sub, msg)

    respond_to do |format|
      format.js { flash[:success] = "Email sent!" }
    end
  end

  def print_private
    ids = params[:listing_ids].split(',')
    @neighborhood_group = ResidentialListing.listings_by_neighborhood(current_user, ids)

    render pdf: current_user.company.name + ' - Private Listings - ' + Date.today.strftime("%b%d%Y"),
      template: "/residential_listings/print_private.pdf.erb",
      orientation: 'Landscape',
      layout:   "/layouts/pdf_layout.html"
  end

  def print_public
    ids = params[:listing_ids].split(',')
    @neighborhood_group = ResidentialListing.listings_by_neighborhood(current_user, ids)

    render pdf: current_user.company.name + ' - Public Listings - ' + Date.today.strftime("%b%d%Y"),
      template: "/residential_listings/print_public.pdf.erb",
      orientation: 'Landscape',
      layout:   "/layouts/pdf_layout.html"
  end

  # def access_email_generate
  #   UnitMailer.send_access_information(params[:address],params[:unit], params[:rent], params[:access_info], params[:tenant_occupied]).deliver!
  # end 

  def streeteasy_active_by_agent
    residential_listing = ResidentialListing.find(params[:id])

    if params[:streeteasy_status] == "true"
      residential_listing.update(streeteasy_flag_one: true, streeteasy_claim: false, updated_at: Time.now())
      UnitMailer.send_email_at_claim_for_streeteasy(residential_listing,current_user).deliver!
      flash[:success] = "listing active on Streeteasy"
    else
      residential_listing.update(streeteasy_flag_one: false, updated_at: Time.now())
      flash[:success] = "listing deactive on Streeteasy"
    end
    residential_listing.unit.update(streeteasy_primary_agent_id: current_user.id, updated_at: Time.now())

    redirect_to claim_for_streeteasy_path
    rescue ActionController::RedirectBackError
    redirect_to root_path
  end

  def update
    unit_updated = nil
    listing_updated = nil
    is_now_active = nil

    if params[:residential_listing][:unit][:price_calculation] == "1"
      params[:residential_listing][:unit][:rent] = (params[:residential_listing][:unit][:gross_price].to_i * (params[:residential_listing][:lease_start].to_i - params[:residential_listing][:unit][:maths_free].to_f)) / params[:residential_listing][:lease_start].to_i
      params[:residential_listing][:unit][:rent] = params[:residential_listing][:unit][:rent].round
    else
      if params[:residential_listing][:unit][:gross_price].blank?
        params[:residential_listing][:unit][:gross_price] = 0
      end
    end
    #Start Slack Message when status change neighbourhood wise channel
    if @residential_unit.unit.status != params[:residential_listing][:unit][:status].downcase
      #Slack Message when status change from off to active start
      if @residential_unit.unit.status == "off" && params[:residential_listing][:unit][:status].downcase == "active"
        @building_utilities = ""
        if @residential_unit.unit.building.utilities
          @residential_unit.unit.building.utilities.each{|i| @building_utilities += i.name + "," }
        end
        if !params[:residential_listing][:unit][:available_by].blank?
          @avail_date = params[:residential_listing][:unit][:available_by]
        end
        if params[:residential_listing][:lease_start]
          @lease_st = params[:residential_listing][:lease_start]
        end
        if params[:residential_listing][:lease_end]
          @lease_ed = params[:residential_listing][:lease_end]
        end
        if @residential_unit.unit.building.landlord
          @ll_code = @residential_unit.unit.building.landlord.code
        end
        if @residential_unit.unit.building
          if !@residential_unit.unit.building.point_of_contact.nil?
            @poc = User.find(@residential_unit.unit.building.point_of_contact).name
          end
        end
        
        if @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 55 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 56 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 57
          notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
        elsif @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 54
          notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
        end
          notifier.ping "*New* *Unit* \n #{current_user.name} Added New Unit \n #{@residential_unit.unit.building.street_number} #{@residential_unit.unit.building.route}, #{@residential_unit.unit.building_unit} \n #{@residential_unit.unit.building.neighborhood.name} \n #{params[:residential_listing][:beds]} Beds / #{params[:residential_listing][:baths]} Baths \n Net #{params[:residential_listing][:unit][:rent]} / Gross #{params[:residential_listing][:unit][:gross_price]} \n Avail: #{@avail_date} \n Lease: #{@lease_st} to #{@lease_ed} Months \n LLC: #{@ll_code} \n POC: #{@poc} \n Access: #{params[:residential_listing][:unit][:access_info]} \n ---"
      end
      #Slack Message when status change from off to active End

      #Slack Message when status change from pending to active start
      if @residential_unit.unit.status == "pending" && params[:residential_listing][:unit][:status].downcase == "active"
        if @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 55 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 56 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 57
          notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
        elsif @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 54
          notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
        end
          notifier.ping "*BACK* *ON* *MARKET* \n #{@residential_unit.unit.building.street_number} #{@residential_unit.unit.building.route}, #{@residential_unit.unit.building_unit} \n #{@residential_unit.unit.building.neighborhood.name} \n #{params[:residential_listing][:beds]} Beds / #{params[:residential_listing][:baths]} Baths \n Price: $#{params[:residential_listing][:unit][:rent]} \n Changes made by #{current_user.name} \n ---"
      end
      #Slack Message when status change from pending to active End

      #Slack Message when status change from active to off or pending to off start
      if (@residential_unit.unit.status == "active" && params[:residential_listing][:unit][:status].downcase == "off") || (@residential_unit.unit.status == "pending" && params[:residential_listing][:unit][:status].downcase == "off")
        if @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 55 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 56 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 57
          notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
        elsif @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 54
          notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
        end
          notifier.ping "*TAKE* *OFF* \n #{@residential_unit.unit.building.street_number} #{@residential_unit.unit.building.route}, #{@residential_unit.unit.building_unit} \n #{@residential_unit.unit.building.neighborhood.name} \n #{params[:residential_listing][:beds]} Beds / #{params[:residential_listing][:baths]} Baths \n Price: $#{params[:residential_listing][:unit][:rent]} \n Changes made by #{current_user.name} \n ---"
      end
      #Slack Message when status change from active to off or pending to off End

      #Slack Message when status change from active to pending start
      if @residential_unit.unit.status == "active" && params[:residential_listing][:unit][:status].downcase == "pending"
        notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
            defaults channel: "#default",
                     username: "notifier"
          end
          notifier.ping "*APP* *RECEIVED* \n #{@residential_unit.unit.building.street_number} #{@residential_unit.unit.building.route}, #{@residential_unit.unit.building_unit} \n #{@residential_unit.unit.building.neighborhood.name} \n #{params[:residential_listing][:beds]} Beds / #{params[:residential_listing][:baths]} Baths \n Price: $#{params[:residential_listing][:unit][:rent]} \n Changes made by #{current_user.name} \n ---"
      end
      #Slack Message when status change from active to pending End
      UnitMailer.send_status_change(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:unit][:rent],params[:residential_listing][:unit][:status], current_user.name, @residential_unit.id, @residential_unit.unit.status).deliver!
    else
      if(params[:residential_listing][:unit][:status] != "Off" && params[:residential_listing][:unit][:status] != "Pending")
        if ((@residential_unit.unit.access_info != params[:residential_listing][:unit][:access_info]) || (@residential_unit.unit.available_by.nil? || @residential_unit.unit.available_by.strftime("%m/%d/%Y") != params[:residential_listing][:unit][:available_by]) || (@residential_unit.unit.rent != params[:residential_listing][:unit][:rent].to_i) || (params[:residential_listing][:has_fee] == "0" || params[:residential_listing][:has_fee] == "1"))
          
          if params[:residential_listing][:has_fee] == "0"
            if !params[:residential_listing][:op_fee_percentage].blank?
              if !@residential_unit.op_fee_percentage.nil? && @residential_unit.op_fee_percentage != params[:residential_listing][:op_fee_percentage].to_i
                @has_fee = "Owner Pay Changed to #{params[:residential_listing][:op_fee_percentage]} \n"
              end
            end
          end
          if params[:residential_listing][:has_fee] == "1"
            if !params[:residential_listing][:tp_fee_percentage].blank?
              if !@residential_unit.tp_fee_percentage.nil? && @residential_unit.tp_fee_percentage != params[:residential_listing][:tp_fee_percentage].to_i
                @has_fee = "Tenant Pay Changed to #{params[:residential_listing][:tp_fee_percentage]} \n"
              end
            end
          end

          @price_diff = params[:residential_listing][:unit][:rent].to_i - @residential_unit.unit.rent

          if @price_diff > 25 || @price_diff < -25
            if @residential_unit.unit.rent != params[:residential_listing][:unit][:rent].to_i
              @rent_info = "Price Changed from $#{@residential_unit.unit.rent} to $#{params[:residential_listing][:unit][:rent]} \n"
            end
          end

          if @residential_unit.unit.available_by.nil? || @residential_unit.unit.available_by.strftime("%m/%d/%Y") != params[:residential_listing][:unit][:available_by]
            @avail_info = "Available by changed to #{params[:residential_listing][:unit][:available_by]} \n"
          end

          if @residential_unit.unit.access_info != params[:residential_listing][:unit][:access_info]
            @accs_info = "Access Changed to #{params[:residential_listing][:unit][:access_info]} \n"
          end
          
          if @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 55 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 56 || @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 57
            notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
              defaults channel: "#default",
                       username: "notifier"
            end
          elsif @residential_unit.unit.building.neighborhood.parent_neighborhood_id == 54
            notifier = Slack::Notifier.new "https://hooks.slack.com/services/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" do
              defaults channel: "#default",
                       username: "notifier"
            end
          end
        end
        if !@has_fee.nil? || !@rent_info.nil? || !@avail_info.nil? || !@accs_info.nil?
          notifier.ping "*Unit* *Update* \n #{@residential_unit.unit.building.street_number} #{@residential_unit.unit.building.route}, #{@residential_unit.unit.building_unit} \n #{@residential_unit.unit.building.neighborhood.name} \n #{params[:residential_listing][:beds]} Beds / #{params[:residential_listing][:baths]} Baths \n $#{params[:residential_listing][:unit][:rent]} \n #{@rent_info} #{@avail_info} #{@accs_info} #{@has_fee} \n Changes made by #{current_user.name}\n ---"
        end
      end
    end
    #End Slack Message when status change neighbourhood wise channel

    if params[:residential_listing][:streeteasy_flag] == "0" and params[:residential_listing][:unit][:status] == "Active"
      if params[:residential_listing][:streeteasy_flag] == "0"
        params[:residential_listing][:streeteasy_flag] = false
      end

      if @residential_unit.streeteasy_flag != params[:residential_listing][:streeteasy_flag]
        @residential_unit.update_columns(streeteasy_claim: true, updated_at: Time.now())
        @residential_unit.unit.update_columns(streeteasy_primary_agent_id: nil, updated_at: Time.now())
      end
    end
    if params[:residential_listing][:streeteasy_flag_one] == "0"
        @residential_unit.unit.update(streeteasy_primary_agent_id: nil, updated_at: Time.now())
      end
    # if params[:residential_listing][:streeteasy_flag_one] == "0" and params[:residential_listing][:streeteasy_flag] == "0" and params[:residential_listing][:unit][:status] == "Active"
    #   abort (@residential_unit.streeteasy_flag != params[:residential_listing][:streeteasy_flag]).inspect
    #   if @residential_unit.streeteasy_flag != params[:residential_listing][:streeteasy_flag]
    #     exit
    #     @residential_unit.update_columns(streeteasy_claim: true)
    #     @residential_unit.unit.update_columns(streeteasy_primary_agent_id: nil, primary_agent_id: nil)
    #   end
    # end

    #email option normalization
    #email send when available dates changed
    # if params[:residential_listing][:unit][:available_by] != @residential_unit.unit.available_by.strftime("%m/%d/%Y")
    #   UnitMailer.send_available_by_info(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:unit][:rent],params[:residential_listing][:unit][:available_by], current_user.name).deliver!
    # end

    # #email send when anyone click on update button
    # if params[:update_status_info] == "update"
    #   UnitMailer.send_details_of_user_activity(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],current_user.name).deliver!
    # end

    # #email send when anyone click on unit email button
    # if params[:update_status_info] == "unit_email"
    #   UnitMailer.send_unit_email(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:beds],params[:residential_listing][:baths],params[:residential_listing][:unit][:rent],params[:residential_listing][:residential_amenity_ids].reject(&:empty?),params[:residential_listing][:unit][:access_info],params[:residential_listing][:notes],params[:residential_listing][:unit][:available_by],params[:residential_listing][:has_fee],params[:residential_listing][:tp_fee_percentage],params[:residential_listing][:op_fee_percentage],params[:residential_listing][:lease_start], params[:residential_listing][:lease_end],current_user.name).deliver!
    # end

    # # ResidentialListing.transaction do
    #   if params[:update_status_info] == "access"
    #     UnitMailer.send_access_information(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:unit][:rent], params[:residential_listing][:unit][:access_info], params[:residential_listing][:tenant_occupied], current_user.name).deliver!   
    #   end

    #   if params[:update_status_info] == "update_and_email" || params[:update_status_info] == "access"
    #     #abort params[:residential_listing][:unit][:status].inspect
    #     #send an email when price change
    #     if params[:residential_listing][:unit][:rent].to_i != @residential_unit.unit.rent
    #       UnitMailer.send_price_change(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:unit][:rent], @residential_unit.unit.rent, params[:residential_listing][:notes], params[:residential_listing][:unit][:access_info], current_user.name).deliver!
    #     end
    #     #send an email when available dates changed
    #     if params[:residential_listing][:unit][:available_by] != @residential_unit.unit.available_by.strftime("%m/%d/%Y")
    #       UnitMailer.send_available_by_info(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:unit][:rent],params[:residential_listing][:unit][:available_by], current_user.name).deliver!
    #     end
    #     #send an email when status changed
    #     if params[:residential_listing][:unit][:status] == "Off" && @residential_unit.unit.status != params[:residential_listing][:unit][:status].downcase
    #       UnitMailer.send_status_off(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit], current_user.name).deliver!
    #     elsif params[:residential_listing][:unit][:status] == "Pending" && @residential_unit.unit.status != params[:residential_listing][:unit][:status].downcase
    #       UnitMailer.send_status_pending(params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit], current_user.name).deliver!
    #     elsif params[:residential_listing][:unit][:status] == "Active" && @residential_unit.unit.status != params[:residential_listing][:unit][:status].downcase
    #       UnitMailer.send_status_active(params[:residential_listing][:unit][:available_by],params[:residential_listing][:unit][:building_id],params[:residential_listing][:unit][:building_unit],params[:residential_listing][:unit][:rent],params[:residential_listing][:residential_amenity_ids].reject(&:empty?),params[:residential_listing][:notes],params[:residential_listing][:unit][:access_info],params[:id],params[:residential_listing][:lease_start], params[:residential_listing][:lease_end],params[:residential_listing][:has_fee],params[:residential_listing][:op_fee_percentage], params[:residential_listing][:tp_fee_percentage], current_user.name).deliver!
    #     end
    #   else
    #   end

      if @residential_unit.unit.primary_agent_id != residential_listing_params[:unit][:primary_agent_id].to_i
        Unit.update_primary_agent(
            residential_listing_params[:unit][:primary_agent_id],
            @residential_unit.unit.primary_agent_id,
            @residential_unit.unit.listing_id)
      end

      # keep track of whether this listing just came on or off the market
      if @residential_unit.unit.status != residential_listing_params[:unit][:status] &&
          residential_listing_params[:unit][:status] != 'pending'
        is_now_active = residential_listing_params[:unit][:status] == 'active'
      end

      # update fields on the unit first, then update fields on the residential_listing
      if !params[:residential_listing][:building][:point_of_contact].nil?
        @residential_unit.unit.building.update(point_of_contact: params[:residential_listing][:building][:point_of_contact])
      end
      unit_updated = @residential_unit.unit.update(
          residential_listing_params[:unit].merge({updated_at: Time.now}))
      r_params = residential_listing_params
      r_params.delete('unit')
      listing_updated = @residential_unit.update(r_params.merge({updated_at: Time.now}))
    # end
    # update res
    if params[:residential_listing][:streeteasy_flag] == "1" and params[:residential_listing][:unit][:status] == "Active" and params[:residential_listing][:unit][:primary_agent_id] == ""
      flash[:warning] == "You must need to select Primary Agent if you want to disply listing on Streeteast"
      #@residential_unit.unit.update_columns(primary_agent_id: current_user.id)
    end

    #listing active for streeteasy agent to claim
    if params[:residential_listing][:unit][:status] == "Off" || params[:residential_listing][:unit][:status] == "Pending"
      @residential_unit.update_columns(streeteasy_claim: false, streeteasy_flag_one: false, updated_at: Time.now())
      @residential_unit.unit.update_columns(streeteasy_primary_agent_id: nil, updated_at: Time.now())
    end

    if params[:residential_listing][:streeteasy_flag] == "1" || params[:residential_listing][:streeteasy_flag_one] == "1"
      @residential_unit.update_columns(streeteasy_claim: false)

    end

    if params[:residential_listing][:streeteasy_flag] == "1"
      StreeteasyCounter.create(residential_listing_id: params[:id], streeteasy_flag_check: true)
    end

    if unit_updated && listing_updated

      Resque.enqueue(UpdateResidentialListing, @residential_unit.id, is_now_active) # send to Knack
      flash[:success] = "Unit successfully updated!"
      redirect_to residential_listing_path(@residential_unit)
    else
      @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
      render 'edit'
    end
  end

  def favorite_listings
    set_residential_listings
    @favorite_units = @residential_units.where(favorites: true)
    #abort @favorite_units.inspect
  end

  def claim_for_streeteasy
    if current_user.is_streeteasy_agent?
      set_residential_listings
      @residential_units = ResidentialListing.search(params, current_user, params[:building_id])
      #abort @residential_units.inspect
      #abort @residential_units.each.map(&:id).inspect
      @residential_listings = ResidentialListing.where(streeteasy_claim: true)
      @residential_listings = @residential_units.each.map(&:id) & @residential_listings.each.map(&:id)
      @residential_listings = ResidentialListing.where(id: @residential_listings)
      @map_list = []
      @residential_listings.each do |res_list|
        @map_list << ["#{res_list.unit.building.street_number}" + " " +"#{res_list.unit.building.route}" + " #" + "#{res_list.unit.building_unit}",res_list.unit.building.lat,res_list.unit.building.lng]
      end
    else 
      flash[:warning] = "You don't have access to this URL"
      redirect_to root_path
    end
  end

  def room_index
    @residential_listings = ResidentialListing.where(roomshare_department: true)
    @residential_units = ResidentialListing.search(params, current_user, params[:building_id])

    @residential_listings = @residential_units.each.map(&:id) & @residential_listings.each.map(&:id)
    @residential_listings = ResidentialListing.where(id: @residential_listings)
    #room count code as per roooms status start
    @room_active = 0
    @room_pending = 0
    @room_off = 0

    @residential_listings.each do |room_count|
      room_count.rooms.each do |room|
        if room.status == 0
         @room_active = @room_active + 1
        elsif room.status == 1
          @room_pending = @room_pending + 1
        elsif room.status == 2
          @room_off = @room_off + 1
        end
      end
    end
    #room count code as per roooms status End
    set_residential_listings

  end

  def claim_for_individual_syndication_page
    residential_listing = ResidentialListing.find(params[:id])
    if residential_listing.claim_for_individual_syndication_page.blank?
      a = residential_listing.claim_for_individual_syndication_page << current_user.id
      residential_listing = residential_listing.update(claim_for_individual_syndication_page: a)
    else
      claim_user = residential_listing.claim_for_individual_syndication_page << current_user.id
      residential_listing = residential_listing.update(claim_for_individual_syndication_page: claim_user)
    end
    redirect_to root_url
  end

  def disclaim_for_individual_syndication_page
    residential_listing = ResidentialListing.find(params[:id])
    disclaim = residential_listing.claim_for_individual_syndication_page - ["#{current_user.id}"]
    residential_listing = residential_listing.update(claim_for_individual_syndication_page: disclaim)
    redirect_to root_url
  end


  def claim_naked_apartment
    residential_listing = ResidentialListing.find(params[:id])
    if residential_listing.claim_for_naked_apartment.blank?
      a = residential_listing.claim_for_naked_apartment << current_user.id
      residential_listing = residential_listing.update(claim_for_naked_apartment: a, naked_apartment: true, updated_at: Time.now)
    else
      claim_user = residential_listing.claim_for_naked_apartment << current_user.id
      residential_listing = residential_listing.update(claim_for_naked_apartment: claim_user, naked_apartment: true, updated_at: Time.now)
    end
    redirect_to agent_rental_url
  end

  def disclaim_naked_apartment
    residential_listing = ResidentialListing.find(params[:id])
    disclaim = residential_listing.claim_for_naked_apartment - ["#{current_user.id}"]
    residential_listing = residential_listing.update(claim_for_naked_apartment: disclaim, naked_apartment: false, updated_at: Time.now)
    redirect_to agent_rental_url
  end

  def agent_rental
    respond_to do |format|
      format.html.phone do
        set_residential_listings
      end
      # tablets get treated the same as desktops
      format.html.desktop do
        set_residential_listings
      end
      format.js do
        set_residential_listings
      end
      format.csv do
        set_residential_listings_csv
        headers['Content-Disposition'] = "attachment; filename=\"" +
          current_user.name + " - Residential Listings.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
  end

  # GET
  # handles ajax call. uses latest data in modal
  def delete_modal
    @params_copy = params
    @params_copy.delete('action')
    @params_copy.delete('controller')
    @params_copy.delete('id')
    respond_to do |format|
      format.js
    end
  end

  def destroy
    #UnitMailer.notification_at_listing_deleted(@residential_unit).deliver!
    if !@residential_unit.claim_for_individual_syndication_page.blank?
      @residential_unit.claim_for_individual_syndication_page.each do |user|
        UnitMailer.notification_at_listing_deleted(@residential_unit,user).deliver!
      end
    end
    @residential_unit.archive
    set_residential_listings
    respond_to do |format|
      format.html { redirect_to residential_listings_url,
          notice: 'Residential unit was successfully destroyed.' }
      format.json { head :no_content }
      format.js
    end
  end

  # PATCH
  # triggers email to staff notifying them of the inaccuracy
  def send_inaccuracy
    if !residential_listing_params[:inaccuracy_description].blank? ||
        params[:feedback_category] || params[:photo_error_type]
      @residential_unit.send_inaccuracy_report(current_user,
          residential_listing_params[:inaccuracy_description],
          params[:feedback_category], params[:photo_error_type])
      flash[:success] = "Report submitted! Thank you."
    end
    respond_to do |format|
      format.html { redirect_to @residential_unit }
      format.js { }
    end
  end

  # GET
  # ajax call
  def refresh_documents
    respond_to do |format|
      format.js
    end
  end

  # GET /refresh_images
  # ajax call
  def refresh_images
    respond_to do |format|
      format.js
    end
  end

  def fee_options
    building = Building.find(params[:building_id])
    if building
      @landlord = building.landlord
    end
    respond_to do |format|
      format.js
    end
  end

  def update_announcements
    @announcement_items = Announcement.search({limit: params[:limit]})
  end

  # uses different template, so must be separated into it's own function
  def update_announcements_mobile
    @announcement_items = Announcement.search({limit: params[:limit]})
  end

  def assign_modal
    @listings = ResidentialListing.joins(:unit)
      .where("units.listing_id IN (?)", params[:listing_ids])
    respond_to do |format|
      format.js
    end

  end

  def assign
    @listings = ResidentialListing.joins(:unit)
      .where("units.listing_id IN (?)", params[:listing_ids].split(" "))
    @agent = User.find(params[:primary_agent_id])

    if @agent && @listings.length > 0
      @listings.each do |l|
        if l.unit.primary_agent_id != @agent.id
          Unit.update_primary_agent(l.unit.primary_agent_id, @agent.id, l.unit.listing_id)
          l.unit.update_attribute(:primary_agent_id, @agent.id)
        end
      end

      flash[:success] = "Primary agent successfully assigned!"
    end

    params.delete('listing_ids')
    params.delete('primary_agent_id')
    set_residential_listings
    respond_to do |format|
      format.js
    end
  end

  def unassign_modal
    @listings = ResidentialListing.joins(:unit)
      .where("units.listing_id IN (?)", params[:listing_ids])
    respond_to do |format|
      format.js
    end

  end

  def unassign
    listings = ResidentialListing.joins(:unit)
      .where("units.listing_id IN (?)", params[:listing_ids].split(" "))

    if listings.length > 0
      listings.each do |l|
        Unit.update_primary_agent(l.unit.primary_agent_id, nil, l.unit.listing_id)
        l.unit.update_attribute(:primary_agent_id, nil)
        l.unit.update_attribute(:primary_agent2_id, nil)
      end

      flash[:success] = "Primary agent successfully removed!"
    end

    params.delete('listing_ids')
    set_residential_listings
    respond_to do |format|
      format.js
    end
  end

  def check_in_options
    @check_in_listings = ResidentialListing.get_check_in_options(
        params[:current_location], params[:distance])
    respond_to do |format|
      format.js
    end
  end

  def check_in
    return unless params[:listing_id]

    unit = Unit.where('units.listing_id = ?', params[:listing_id]).first
    if unit
      unit.checkins << Checkin.create!(user: current_user)
    end

    head :ok#, content_type: "text/html" #render no output
  end

  protected

    def correct_stale_record_version
      @residential_unit.reload
      @buildings = current_user.company.buildings
        .where(archived: false)
        .order("formatted_street_address ASC")
        .collect {|b| [b.street_address, b.id]}
      params[:residential_listing]. delete('lock_version')
    end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_residential_listing
      @residential_unit = ResidentialListing.find_unarchived(params[:id])
      if @residential_unit
        @similar_listings = @residential_unit.find_similar
      else
        flash[:warning] = "Sorry, that listing is not active."
        redirect_to action: 'index'
      end
    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "Sorry, that listing is not active."
      redirect_to action: 'index'
    end

    def set_specific_residential_listing
      @specific_residential_unit = ResidentialListing.find_unarchived(params[:id])
      if @specific_residential_unit
        @similar_listings = @specific_residential_unit.find_similar
      else
        flash[:warning] = "Sorry, that listing is not active."
        redirect_to action: 'index'
      end
    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "Sorry, that listing is not active."
      redirect_to action: 'index'
    end

    def set_residential_listings
      @neighborhoods = Neighborhood.unarchived
          .where(state: current_user.office.administrative_area_level_1_short)
          .to_a
          .group_by(&:borough_cat)
      @building_amenities = BuildingAmenity.where(company: current_user.company)
      @unit_amenities = ResidentialAmenity.where(company: current_user.company)

      do_search
      @bldg_images = Building.get_bldg_images_from_units(@residential_units)
      @res_images = ResidentialListing.get_images(@residential_units)
      custom_sort

      # display all found listings on the map
      #@residential_units = @residential_units.to_a & @residential_listings.to_a
      if action_name == "room_index"
        @map_infos = ResidentialListing.set_location_data(
          @residential_units.to_a & @residential_listings.to_a, @res_images, @bldg_images)
      else
        @map_infos = ResidentialListing.set_location_data(
          @residential_units.to_a, @res_images, @bldg_images)
      end

      # only get data + images for paginated responses
      @residential_units = @residential_units.page params[:page]
      if request.variant != ":phone"
        @favorite_units = @residential_units
      end

      # convert params back into something the form can recognize
      if !params[:bed_min].blank? && params[:bed_min] == 0
        params[:bed_min] = 'Studio/Loft'
      end
      if !params[:bed_max].blank? && params[:bed_max] == 0
        params[:bed_max] = 'Studio/Loft'
      end
    end

    # returns all data for export
    def set_residential_listings_csv
      @residential_units = ResidentialListing.export_all(current_user, params)
      @utilities = Building.get_utilities(@residential_units)
      @amenities = ResidentialListing.get_amenities(@residential_units)
      @reverse_statuses = {
        '0': 'Active',
        '1': 'Pending',
        '2': 'Off'}
      @residential_units = custom_sort
    end

    def do_search
      # first, fix up parameters and set some view variables

      # default to searching for active units
      if !params[:status]
        params[:status] = "active".freeze
      end
      # parse neighborhood ids into strings for display in the view
      @selected_neighborhoods = []
      if params[:neighborhood_ids]
        neighborhood_ids = params[:neighborhood_ids].split(",").select{|i| !i.empty?}
        @selected_neighborhoods = Neighborhood.where(id: neighborhood_ids)
      end
      # parse feature ids into strings for display in the view
      @unit_features = []
      if params[:unit_feature_ids]
        feature_ids = params[:unit_feature_ids].split(",").select{|i| !i.empty?}
        @unit_features = ResidentialAmenity.where(id: feature_ids)
      end

      @bldg_features = []
      if params[:building_feature_ids]
        building_feature_ids = params[:building_feature_ids].split(",").select{|i| !i.empty?}
        @bldg_features = BuildingAmenity.where(id: building_feature_ids)
      end

      @residential_units = ResidentialListing.search(params, current_user, params[:building_id])
      # remove listing who has more then 2 rooms booked
      # @residential_units.each do |res_list|
      #   if !res_list.rooms.blank?
      #     if res_list.rooms.where(status: [1,2]).count >= 2
      #       @residential_units = @residential_units.where("residential_listings.id != :id", id: res_list.id)
      #     end
      #   end
      # end
      #end of more then 2 rooms book code

      #abort @residential_units.inspect
      @announcement_items = Announcement.search({limit: 4})
    end

    def custom_sort
      #puts "GOT ---#{params.inspect} #{params[:sort_by]} --- #{params[:direction]}---"
      sort_column = params[:sort_by] || "updated_at".freeze
      sort_order = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc".freeze
      params[:sort_by] = sort_column
      params[:direction] = sort_order
      if sort_column == 'bed_and_baths_sorter'.freeze
        @residential_units = @residential_units.order("beds #{sort_order}, baths #{sort_order}".freeze)
      else
        @residential_units = @residential_units.order("#{sort_column} #{sort_order}".freeze)
      end
      @residential_units
    end

    def residential_listing_params
      data = params[:residential_listing].permit(
        :lock_version,
        :id,
        :recipients, :building_rating, :landlord_rating, :title, :message, :listing_ids, :listing_id,
        :tenant_occupied,
        :beds, :baths, :notes, :description, :rooms_description, :lease_start, :lease_end,
        :include_photos, :inaccuracy_description,
        :has_fee, :op_fee_percentage, :tp_fee_percentage,
        :available_starting, :available_before, :custom_amenities,
        :roomsharing_filter, :unassigned_filter, :tenant_occupied_filter, :streeteasy_filter,
        :no_description,:no_images, :roomshare_department,
        :primary_agent_id, :favorites, :show,:claim_for_naked_apartment, :claim_for_individual_syndication_page, :expose_address, :floor, :total_room_count, :condition, :showing_instruction,
        :commission_amount, :cyof, :rented_date, :rlsny, :share_with_brokers,
        :rls_flag, :streeteasy_flag, :streeteasy_flag_one,:streeteasy_claim, :naked_apartment,
        unit: [:building_unit, :streeteasy_unit, :streeteasy_primary_agent_id, :streeteasy_listing_email, :streeteasy_listing_number, :rent, :gross_price, :maths_free, :available_by, :access_info, :status,
          :exclusive, :featured, :hide_on_website, :building_id, :primary_agent_id, :listing_agent_id,
          :syndication_status, :has_stock_photos, :is_exclusive_agreement_signed,
          :exclusive_agreement_expires_at, :public_url, :price_calculation,
          open_houses_attributes: [:day, :start_time, :end_time, :_destroy, :id],
          building: [:point_of_contact] ],
        residential_amenity_ids: []
        )

      if data[:unit]
        if data[:unit][:status]
          data[:unit][:status] = data[:unit][:status].downcase
        end

        # convert into a datetime obj
        if !data[:unit][:available_by].blank?
          begin
            data[:unit][:available_by] = Date::strptime(data[:unit][:available_by], "%m/%d/%Y")
          rescue
            data[:unit].delete(:available_by)
          end
        end

        if data[:unit][:open_houses_attributes]
          data[:unit][:open_houses_attributes].each do |idx, oh_data|
            begin
              oh_data[:day] = Date::strptime(oh_data[:day], "%m/%d/%Y")
            rescue
            end
          end
        end
      end

      if !data[:has_fee].nil?
        if data[:has_fee] == "1".freeze
          data[:has_fee] = true
        else
          data[:has_fee] = false
        end
      end
      
      if data[:total_room_count].blank?
        data[:total_room_count] = (data[:beds].to_i + 2)
      end

      if !data[:include_photos].nil?
        if data[:include_photos] == "1".freeze
          data[:include_photos] = true
        else
          data[:include_photos] = false
        end
      end

      if !data[:description].blank?
        data[:description] = data[:description].gsub(/&nbsp;/, ' ')
      end

      data
    end
end
