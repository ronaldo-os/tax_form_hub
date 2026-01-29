class UnitsController < ApplicationController
  before_action :authenticate_user!

  def create
    @unit = current_user.company.units.build(unit_params)
    @unit.custom = true

    if @unit.save
      render json: { id: @unit.id, name: @unit.name }, status: :created
    else
      render json: { errors: @unit.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @unit = current_user.company.units.find(params[:id])
    if @unit.destroy
      head :no_content
    else
      render json: { error: "Failed to delete" }, status: :unprocessable_entity
    end
  end

  private

  def unit_params
    params.require(:unit).permit(:name)
  end
end
