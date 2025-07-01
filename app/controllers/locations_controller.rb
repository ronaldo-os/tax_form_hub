class LocationsController < ApplicationController
  before_action :set_location, only: %i[update destroy]

  def index
    @locations = current_user.locations
  end

  def new
    @location = Location.new
  end

  def create
    @location = current_user.locations.build(location_params)

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
    @location = current_user.locations.find(params[:id])
    respond_to do |format|
      format.json { render json: @location }
    end
  end

  def update
    @location = current_user.locations.find(params[:id])

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
    @location = current_user.locations.find(params[:id])
  end

  def location_params
    params.require(:location).permit(
      :location_type, :location_name, :country, :company_name, :tax_number,
      :post_box, :street, :building, :additional_street, :zip_code, :city
    )
  end
end
