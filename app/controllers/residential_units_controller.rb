class ResidentialUnitsController < ApplicationController
  load_and_authorize_resource
  before_action :set_residential_unit, except: [:new, :create, :index]

  # GET /residential_units
  # GET /residential_units.json
  def index
    #@residential_units = ResidentialUnit.all
    @units = ResidentialUnit.all.paginate(:page => params[:page], :per_page => 50)#.order("updated_at ASC")
  end

  # GET /residential_units/1
  # GET /residential_units/1.json
  def show
  end

  # GET /residential_units/new
  def new
    @unit = ResidentialUnit.new
  end

  # GET /residential_units/1/edit
  def edit
  end

  # POST /residential_units
  # POST /residential_units.json
  def create
    @unit = ResidentialUnit.new(residential_unit_params)

    respond_to do |format|
      if @unit.save
        format.html { redirect_to @unit, notice: 'Residential unit was successfully created.' }
        format.json { render :show, status: :created, location: @unit }
      else
        format.html { render :new }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /residential_units/1
  # PATCH/PUT /residential_units/1.json
  def update
    respond_to do |format|
      if @unit.update(residential_unit_params)
        format.html { redirect_to @unit, notice: 'Residential unit was successfully updated.' }
        format.json { render :show, status: :ok, location: @unit }
      else
        format.html { render :edit }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /residential_units/1
  # DELETE /residential_units/1.json
  def destroy
    @unit.destroy
    respond_to do |format|
      format.html { redirect_to residential_units_url, notice: 'Residential unit was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_residential_unit
      @unit = ResidentialUnit.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def residential_unit_params
      params[:residential_unit]
    end
end
