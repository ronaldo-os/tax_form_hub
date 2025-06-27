class LocationsController < ApplicationController
  before_action :set_location, only: %i[ destroy ]

  def index
    @locations = Location.all
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to locations_path, notice: "Location was successfully created." }
        format.json { render :index, status: :created, location: @location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @location = Location.find(params[:id])
    respond_to do |format|
      format.json { render json: @location }
    end
  end

  def update
    @location = Location.find(params[:id])

    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to locations_path, notice: "Location was successfully updated." }
        format.json { render :index, status: :ok, location: @location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end


  def destroy
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_path, status: :see_other, notice: "Location was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    def set_location
      @location = Location.find(params[:id])
    end

    def location_params
      params.require(:location).permit(:location_type, :location_name, :country, :company_name, :tax_number, :post_box, :street, :building, :additional_street, :zip_code, :city)
    end
end
