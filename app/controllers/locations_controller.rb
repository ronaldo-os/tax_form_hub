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
        format.json { render json: @location, status: :created }
      else
        format.html { redirect_to locations_path, alert: @location.errors.full_messages.to_sentence }
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
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to locations_path, notice: "Location was successfully updated." }
        format.json { render json: @location, status: :ok }
      else
        format.html { redirect_to locations_path, alert: @location.errors.full_messages.to_sentence }
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

  def bulk_action
    action_type = params[:bulk_action].to_s
    location_ids = Array(params[:location_ids]).map(&:to_i).reject(&:zero?)

    if location_ids.empty?
      redirect_to locations_path, status: :see_other, alert: "No locations selected."
      return
    end

    # Authorization: strictly scope to current_user (tenant isolation)
    locations = current_user.locations.where(id: location_ids)

    if locations.empty?
      redirect_to locations_path, status: :see_other, alert: "No authorized locations found to perform this action."
      return
    end

    case action_type
    when "destroy", "delete"
      deleted_count = 0
      skipped_count = 0
      locations.each do |loc|
        begin
          if loc.destroy
            deleted_count += 1
          else
            skipped_count += 1
          end
        rescue StandardError => e
          Rails.logger.error("Failed to delete location #{loc.id}: #{e.message}")
          skipped_count += 1
        end
      end

      if deleted_count > 0 && skipped_count > 0
        notice = "Successfully deleted #{deleted_count} #{'location'.pluralize(deleted_count)}. #{skipped_count} #{'location'.pluralize(skipped_count)} skipped due to errors."
        respond_to do |format|
          format.html { redirect_to locations_path, status: :see_other, notice: notice }
          format.json { render json: { notice: notice, deleted_count: deleted_count, skipped_count: skipped_count }, status: :ok }
        end
      elsif deleted_count > 0
        notice = "Successfully deleted #{deleted_count} #{'location'.pluralize(deleted_count)}."
        respond_to do |format|
          format.html { redirect_to locations_path, status: :see_other, notice: notice }
          format.json { render json: { notice: notice, deleted_count: deleted_count }, status: :ok }
        end
      else
        alert = "Could not delete the selected locations."
        respond_to do |format|
          format.html { redirect_to locations_path, status: :see_other, alert: alert }
          format.json { render json: { alert: alert }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to locations_path, status: :see_other, alert: "Invalid action." }
        format.json { render json: { alert: "Invalid action." }, status: :unprocessable_entity }
      end
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
