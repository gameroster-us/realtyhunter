class CommercialListingsController < ApplicationController
  load_and_authorize_resource
  skip_load_resource only: [:create, :update_subtype]
  before_action :set_commercial_listing, except: [:new, :create, :index, :filter,
    :neighborhoods_modal, :features_modal, :print_public, :print_private, :send_message]
  autocomplete :building, :formatted_street_address, full: true
  autocomplete :landlord, :code, full: true
  etag { current_user.id }

  # GET /commercial_units
  # GET /commercial_units.json
  def index

    respond_to do |format|
      format.html do
        set_commercial_listings
      end
      format.csv do
        set_commercial_listings_csv
        headers['Content-Disposition'] = "attachment; filename=\"" +
          current_user.name + " - Commercial Listings.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
  end

  def filter
    set_commercial_listings
    respond_to do |format|
      format.js
      format.html do
        # catch-all
        redirect_to commercial_listings_url
      end
    end
  end

  # GET
  # handles ajax call. uses latest data in modal
  def neighborhoods_modal
    @neighborhoods = Neighborhood.unarchived
    .where(state: current_user.office.administrative_area_level_1_short)
    .to_a
    .group_by(&:borough)

    respond_to do |format|
      format.js
      format.html do
        # catch-all
        redirect_to commercial_listings_url
      end
    end
  end

  # GET /commercial_units/1
  # GET /commercial_units/1.json
  def show
  end

  # GET /commercial_units/new
  def new
    @commercial_unit = CommercialListing.new
    @commercial_unit.unit = Unit.new
    @property_sub_types = CommercialPropertyType.subtypes_for("Retail", current_user.company)
    if params[:building_id]
      building = Building.find(params[:building_id])
      @commercial_unit.unit.building_id = building.id
    end

    @panel_title = "Add a listing"
    set_property_types
  end

  # GET /commercial_units/1/edit
  def edit
    @panel_title = "Edit listing"
    set_property_types
  end

  def update_subtype
    ptype = params[:property_type]
    @property_sub_types = CommercialPropertyType.subtypes_for(ptype, current_user.company)
    respond_to do |format|
      format.js
      format.html do
        # catch-all
        redirect_to commercial_listings_url
      end
    end
  end

  # POST /commercial_units
  # POST /commercial_units.json
  def create
    ret1 = nil
    ret2 = nil
    CommercialListing.transaction do
      ret1 = Unit.new(commercial_listing_params[:unit])
      c_params= commercial_listing_params
      c_params.delete('unit')
      ret2 = CommercialListing.new(c_params)
      ret2.unit = ret1

      if !ret1.available_by?
        ret1.available_by = Date.today
      end
    end

    if ret1.save! && ret2.save!
      @commercial_unit = ret2
      redirect_to @commercial_unit
    else
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
    commercial_unit_dup = @commercial_unit.duplicate(
      commercial_listing_params[:unit][:building_unit],
      commercial_listing_params[:include_photos])

    if commercial_unit_dup.valid?
      @commercial_unit = commercial_unit_dup
      render :js => "window.location.pathname = '#{commercial_listing_path(@commercial_unit)}'"
    else
      # TODO: not sure how to handle this best...
      flash[:warning] = "Duplication failed!"
      respond_to do |format|
        format.js
      end
    end
  end

  # GET
  # handles ajax call. uses latest data in modal
  # Modal collects info and prep unit to be taken off the market
  def take_off_modal
    respond_to do |format|
      format.js
    end
  end

  # PATCH ajax
  # Takes a unit off the market
  def take_off
    new_end_date = commercial_listing_params[:available_by]
    if new_end_date
      @commercial_unit.take_off_market(new_end_date)
    end
    set_commercial_listing
    respond_to do |format|
      format.js
    end
  end

  # PATCH/PUT /commercial_units/1
  # PATCH/PUT /commercial_units/1.json
  def update
    ret1 = nil
    ret2 = nil
    CommercialListing.transaction do
      ret1 = @commercial_unit.unit.update(commercial_listing_params[:unit].merge({updated_at: Time.now}))
      c_params = commercial_listing_params
      c_params.delete('unit')
      ret2 = @commercial_unit.update(c_params.merge({updated_at: Time.now}))
    end

    if ret1 && ret2
      flash[:success] = "Unit successfully updated!"
      redirect_to commercial_listing_path(@commercial_unit, only_path: true)
    else
      set_property_types
      render 'edit'
    end
  end

  # GET
  # handles ajax call. uses latest data in modal
  def delete_modal
    respond_to do |format|
      format.js
    end
  end

  # DELETE /commercial_units/1
  # DELETE /commercial_units/1.json
  def destroy
    @commercial_unit.archive
    set_commercial_listings
    respond_to do |format|
      format.html { redirect_to commercial_units_url, notice: 'Commercial unit was successfully destroyed.' }
      format.json { head :no_content }
      format.js
    end
  end

  # GET
  # handles ajax call. uses latest data in modal
  def inaccuracy_modal
    respond_to do |format|
      format.js
    end
  end

  # PATCH
  # triggers email to staff notifying them of the inaccuracy
  def send_inaccuracy
    @commercial_unit.inaccuracy_description = commercial_listing_params[:inaccuracy_description]
    @commercial_unit.send_inaccuracy_report(current_user)
    respond_to do |format|
      format.js { flash[:notice] = "Report submitted! Thank you." }
    end
  end

  # GET /refresh_images
  # ajax call
  def refresh_images
    respond_to do |format|
      format.js
    end
  end

  # GET
  # ajax call
  def refresh_documents
    respond_to do |format|
      format.js
    end
  end

  def print_private
    ids = params[:listing_ids].split(',')
    @neighborhood_group = CommercialListing.listings_by_neighborhood(current_user, ids)

    render pdf: current_user.company.name + ' - Private Listings - ' + Date.today.strftime("%b%d%Y"),
      template: "/commercial_listings/print_private.pdf.erb",
      orientation: 'Landscape',
      layout:   "/layouts/pdf_layout.html"
  end

  # PATCH ajax
  # Takes a unit off the market
  def print_public
    ids = params[:listing_ids].split(',')
    @neighborhood_group = CommercialListing.listings_by_neighborhood(current_user, ids)

    render pdf: current_user.company.name + ' - Public Listings - ' + Date.today.strftime("%b%d%Y"),
      template: "/commercial_listings/print_public.pdf.erb",
      orientation: 'Landscape',
      layout:   "/layouts/pdf_layout.html"
  end

  # sends listings info to clients
  def send_listings
    recipients = commercial_listing_params[:recipients].split(/[\,,\s]/)
    sub = commercial_listing_params[:title]
    msg = commercial_listing_params[:message]
    listing_ids = commercial_listing_params[:listing_ids].split(',')
    listings = CommercialListing.listings_by_id(current_user, listing_ids)
    images = CommercialListing.get_images(listings)
    CommercialListing.send_listings(current_user, listings, images, recipients, sub, msg)

    respond_to do |format|
      format.js { flash[:success] = "Listings sent!"  }
    end
  end

  protected

    def correct_stale_record_version
      @commercial_unit.reload
      params[:commercial_listing].delete('lock_version')
      set_property_types
    end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_commercial_listing
      @commercial_unit = CommercialListing.find_unarchived(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "Sorry, that listing is not active."
      redirect_to :action => 'index'
    end

    def set_commercial_listings
      do_search
      @commercial_units = custom_sort

      @count_all = CommercialListing.joins(:unit)
        .where('units.archived = false')
        .where('units.status = ?', Unit.statuses["active"])
        .count
      @map_infos = CommercialListing.set_location_data(@commercial_units.to_a)
      @commercial_units = @commercial_units.page params[:page]
      @com_images = CommercialListing.get_images(@commercial_units)
    end

    # returns all data for export
    def set_commercial_listings_csv
      @commercial_units = CommercialListing.export_all(current_user)
      @commercial_units = custom_sort
      @agents = Unit.get_primary_agents(@commercial_units)
      @reverse_statuses = {
        '0': 'Offer Submitted',
        '1': 'Offer Accepted',
        '2': 'Binder Signed',
        '3': 'Off Market For Lease Execution'}
    end

    def do_search
      # default to searching for active units
      if !params[:status]
        params[:status] = "active"
      end

      # parse neighborhood ids into strings for display in the view
      @selected_neighborhoods = []
      if params[:neighborhood_ids]
        neighborhood_ids = params[:neighborhood_ids].split(",").select{|i| !i.empty?}
        @selected_neighborhoods = Neighborhood.where(id: neighborhood_ids)
      end

      @commercial_units = CommercialListing.search(params, current_user, params[:building_id])
    end

    def set_property_types
      @property_types = current_user.company.commercial_property_types
      .select(:property_type).order('property_type ASC').distinct

      if @commercial_unit.commercial_property_type
        @property_sub_types = CommercialPropertyType.subtypes_for(
          @commercial_unit.commercial_property_type.property_type, current_user.company)
      end
    end

    def custom_sort
      sort_column = params[:sort_by] || "updated_at"
      sort_order = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
      # reset params so that view helper updates correctly
      params[:sort_by] = sort_column
      params[:direction] = sort_order
      # if sorting by an actual db column, use order
      if sort_column == 'landlord_code'
        @commercial_units = @commercial_units.order("LOWER(code) " + sort_order)
      else
        @commercial_units = @commercial_units.order(sort_column + ' ' + sort_order)
      end
      @commercial_units
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def commercial_listing_params
      if params[:commercial_property_type_id]
        params[:commercial_listing][:commercial_property_type_id] = params[:commercial_property_type_id]
      end

      data = params[:commercial_listing].permit(
        :lock_version,
        :recipients, :title, :message, :listing_ids,
        :user_id, :include_photos, :sq_footage_min, :sq_footage_max,
        :sq_footage, :floor, :building_size, :build_to_suit, :minimum_divisible, :maximum_contiguous,
        :lease_type, :is_sublease, :property_description, :location_description,
        :construction_status, :lease_term_months, :primary_agent_id,
        :rate_is_negotiable, :total_lot_size, :property_type, :commercial_property_type_id,
        :commercial_unit_id, :inaccuracy_description, :has_basement, :basement_sq_footage,
        :has_ventilation, :key_money_required, :key_money_amt, :listing_title, :liquor_eligible,
        :unit => [:building_unit, :rent, :available_by, :access_info, :status, :open_house, :oh_exclusive,
          :building_id, :primary_agent_id, :primary_agent2_id, :listing_agent_id, :exclusive ],
        )

      if data[:unit]
        if data[:unit][:oh_exclusive] == "1"
          data[:unit][:oh_exclusive] = true
        else
          data[:unit][:oh_exclusive] = false
        end

        if data[:unit][:status]
          data[:unit][:status] = data[:unit][:status].downcase.gsub(/ /, '_')
        end

        # convert into a datetime obj
        if data[:unit][:available_by] && !data[:unit][:available_by].empty?
          data[:unit][:available_by] = Date::strptime(data[:unit][:available_by], "%m/%d/%Y")
        end
      end

      data
    end
end
