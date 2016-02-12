class BuildingsController < ApplicationController
  load_and_authorize_resource
  skip_load_resource :only => :create
  before_action :set_building, except: [:index, :new, :create, :filter, :filter_listings,
    :refresh_images, :neighborhood_options, :autocomplete_building_formatted_street_address]
  autocomplete :building, :formatted_street_address, where: {archived: false}, full: true
  etag { current_user.id }

  # GET /buildings
  # GET /buildings.json
  def index
    set_buildings

    respond_to do |format|
      format.html
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"buildings-list.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
  end

  # GET /filter_buildings
  # AJAX call
  def filter
    set_buildings
    respond_to do |format|
      format.js
    end
  end

  # AJAX call
  def filter_listings
    set_units
    respond_to do |format|
      format.js
    end
  end

  # GET /buildings/1
  # GET /buildings/1.json
  def show
  end

  # GET /buildings/new
  def new
    @building = Building.new
    landlord_id = params[:landlord_id]
    if landlord_id && Landlord.where("id = ?", landlord_id)
      @building.landlord_id = landlord_id
    end
  end

  # GET /buildings/1/edit
  def edit
  end

  # POST /buildings
  # POST /buildings.json
  def create
      # if this building has already been entered, redirect to that page
      #puts building_params[:building]
      @bldg = Building.where(
        street_number: building_params[:street_number],
        route: building_params[:route],
        archived: false
        ).first
      #puts "FOUND BLDG #{@bldg.inspect} #{building_params[:street_number]} #{building_params[:route]}"
      if @bldg
        flash[:info] = "Building already exists!"
        redirect_to @bldg
      else
        @formatted_street_address = building_params[:building][:formatted_street_address]
        bldg_params = format_params_before_save(true)
        if @building.save(bldg_params)
          redirect_to @building
        else
          # error
          render 'new'
      end
    end
  end

  # PATCH/PUT /buildings/1
  # PATCH/PUT /buildings/1.json
  def update
    if @building.update(format_params_before_save(false).merge({updated_at: Time.now}))
      flash[:success] = "Building updated!"
      redirect_to building_path(@building, only_path: true)
    else
      render 'edit'
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
  # handles ajax call. uses latest data in modal
  def delete_modal
    respond_to do |format|
      format.js
    end
  end

  # DELETE /buildings/1
  # DELETE /buildings/1.json
  def destroy
    @building.archive
    set_buildings
    respond_to do |format|
      format.html { redirect_to buildings_url, notice: 'Building was successfully deleted.' }
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

  # triggers email to staff notifying them of the inaccuracy
  def send_inaccuracy
    @building.inaccuracy_description = building_params[:inaccuracy_description]
    @building.send_inaccuracy_report(current_user)
    respond_to do |format|
      format.js { flash[:notice] = "Report submitted! Thank you." }
    end
  end

  def neighborhood_options
    @building = Building.new
    @building.sublocality = params[:sublocality]

    respond_to do |format|
      format.js
    end
  end

  protected

   def correct_stale_record_version
      # @building.reload.attributes = building_params[:building].reject do |attrb, value|
      #  attrb.to_sym == :lock_version
      # end
      @building.reload
      params[:building].delete('lock_version')
   end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_building
      @building = Building.find_unarchived(params[:id])
      if @building.neighborhood
        @building.custom_neighborhood_id = @building.neighborhood.id
      end
      set_units
    end

    def set_units
      active_only = params[:active_only] == "true"
      @residential_units, @res_images = @building.residential_units(active_only)
      @residential_units = @residential_units.page params[:page]
      @commercial_units, @com_images = @building.commercial_units(active_only)
      @commercial_units = @commercial_units.page params[:page]
    end

    def set_buildings
      @buildings = Building.search(
        building_params[:filter],
        building_params[:status])

      @buildings = custom_sort
      @buildings = @buildings.page params[:page]
      @bldg_imgs = Building.get_images(@buildings)
    end

    def custom_sort
      sort_column = building_params[:sort_by] || "formatted_street_address"
      sort_order = %w[asc desc].include?(building_params[:direction]) ? building_params[:direction] : "asc"
      # reset params so that view helper updates correctly
      params[:sort_by] = sort_column
      params[:direction] = sort_order
      @buildings = @buildings.order(sort_column + ' ' + sort_order)
      @buildings
    end

    def format_params_before_save(is_new)
      # get the whitelisted set of params, then arrange data
      # into the right format for our model
      param_obj = building_params
      param_obj[:building].each{ |k,v| param_obj[k] = v };

      param_obj.delete("building")
      # delete so that this field doesn't conflict with our foreign key
      @neighborhood_name = param_obj[:neighborhood]
      param_obj.delete("neighborhood")

      if is_new
        @building = Building.new(param_obj)
      end

      @building.company = current_user.company
      @building.neighborhood = @building.find_or_create_neighborhood(@neighborhood_name, param_obj[:sublocality],
        param_obj[:administrative_area_level_2_short], param_obj[:administrative_area_level_1_short])

      param_obj
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    # Need to take in additional params here. Can't rename them, or the geocode plugin
    # will not map to them correctly
    def building_params
      params.permit(:sort_by, :direction, :filter, :active_only, :status, :street_number, :route,
        :intersection, :neighborhood,
        :sublocality, :administrative_area_level_2_short,
        :administrative_area_level_1_short,
        :postal_code, :country_short, :lat, :lng, :place_id, :landlord_id, :file,
        building: [:lock_version, :formatted_street_address, :notes, :landlord_id, :user_id,
          :inaccuracy_description, :pet_policy_id, :rental_term_id, :custom_rental_term, :file,
          :custom_amenities, :custom_utilities, :neighborhood_id, :neighborhood,
          building_amenity_ids: [], images_files: [], utility_ids: [] ])
    end
end
