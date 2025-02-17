class DealsController < ApplicationController
  load_and_authorize_resource
  skip_load_resource only: :create
  before_action :set_deal, except: [:index, :new, :create, :filter,
    :autocomplete_building_formatted_street_address, :autocomplete_landlord_code,
    :autocomplete_user_name, :get_units]
  autocomplete :building, :formatted_street_address, full: true
  autocomplete :landlord, :code, full: true
  autocomplete :user, :name, full: true

	def index
    respond_to do |format|
      format.html do
        set_deals
      end
      format.js do
        set_deals
      end
      format.csv do
        set_deals_csv
        headers['Content-Disposition'] = "attachment; filename=\"deals-list.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
    end
	end

	def show
	end

	def new
    @listings = Unit.none
    if params[:unit_id]
  		@deal = Deal.new(unit_id: params[:unit_id])
      if @deal.unit
        @listings = Unit.joins(:building)
        .where("buildings.id = ?", @deal.unit.building_id)
        .order('building_unit asc')
      end
    else
      @deal = Deal.new
    end

    if params[:user_id]
      @deal.user = User.find(params[:user_id])
    end
	end

	def create
		@deal = Deal.new(deal_params[:deal])
		if @deal.save
			redirect_to @deal
		else
			render 'new'
		end
	end

	def edit
    @listings = Unit.joins(:building)
      .where("buildings.id = ?", @deal.unit.building_id)
      .order('building_unit asc')
	end

	def update
    if @deal.update(deal_params[:deal])
			flash[:success] = "Deal updated!"
      redirect_to deal_path(@deal)
    else
    	render 'edit'
		end
	end

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
		@deal.archive
		set_deals
		respond_to do |format|
      format.html { redirect_to deals_url, notice: 'Deal was successfully destroyed.' }
      format.json { head :no_content }
      format.js
    end
	end

	def filter
    set_deals
    respond_to do |format|
      format.js
    end
  end

  def get_units
    @listings = Unit.joins(:building)
      .where("buildings.id = ?", params[:building_id])
    @landlord = Building.where("buildings.id = ?", params[:building_id]).limit(1).first.landlord

    respond_to do |format|
      format.js
    end
  end

	protected

		def correct_stale_record_version
      @deal.reload
      params[:deal].delete('lock_version')
    end

  private

  	def set_deal
  		@deal = Deal.find_unarchived(params[:id])
      @landlord = Landlord.where(code: @deal.landlord_code).limit(1).first
    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "Sorry, that deal is not active."
      redirect_to action: 'index'
  	end

		def set_deals
      # set a default status if none otherwise specified
      if params[:state].blank?
        params[:state] = 'Any'
      end

			@deals = Deal.search(deal_params)
      @deals = custom_sort
			@deals = @deals.page params[:page]
		end

		def set_deals_csv
			@deals = Deal.search_csv(deal_params)
			@deals = custom_sort
		end

		def custom_sort
      sort_column = params[:sort_by] || "closed_date"
      sort_order = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
      params[:sort_by] = sort_column
      params[:direction] = sort_order
      #if Deal.column_names.include?(params[:sort_by])
      @deals = @deals.order(sort_column + ' ' + sort_order)
      #end
      @deals
    end

    def deal_params
    	data = params.permit(:sort_by, :direction, :page, :address, :agent, :closed_date_start,
        :closed_date_end, :landlord_code, :state, :user_name,
    		deal: [:lock_version, :price, :client, :lease_term, :lease_start_date, :lease_expiration_date,
    			:closed_date, :move_in_date, :commission, :deal_notes, :listing_type, :is_sale_deal,
    			:unit_id, :user_id, :building_unit, :building_id, :landlord_code, :state])

      if data[:deal]
        # convert into a datetime obj
        if !data[:deal][:lease_start_date].blank?
          data[:deal][:lease_start_date] = Date::strptime(data[:deal][:lease_start_date], "%m/%d/%Y")
        end

        if !data[:deal][:lease_expiration_date].blank?
          data[:deal][:lease_expiration_date] = Date::strptime(data[:deal][:lease_expiration_date], "%m/%d/%Y")
        end

        if !data[:deal][:lease_start_date].blank? && !data[:deal][:lease_expiration_date].blank?
          data[:deal][:lease_term] = ((data[:deal][:lease_expiration_date] - data[:deal][:lease_start_date])/30).round
        end

        if !data[:deal][:closed_date].blank?
          data[:deal][:closed_date] = Date::strptime(data[:deal][:closed_date], "%m/%d/%Y")
        end

        if !data[:deal][:move_in_date].blank?
          data[:deal][:move_in_date] = Date::strptime(data[:deal][:move_in_date], "%m/%d/%Y")
        end

        # there is some data we write out explicitly, because we want to record
        # a snapshot of the listing at this time
        if !data[:deal][:unit_id].blank?
          unit = Unit.find(data[:deal][:unit_id])

          if unit
            #data[:deal][:landlord_code] = unit.building.landlord.code
            data[:deal][:full_address]  = unit.building.formatted_street_address
            data[:deal][:building_unit] = unit.building_unit
          end
        end

        if data[:deal][:state]
          data[:deal][:state] = data[:deal][:state].downcase
        end

      end

      data
    end

end
