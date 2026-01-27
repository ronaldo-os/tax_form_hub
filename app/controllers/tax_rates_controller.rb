class TaxRatesController < ApplicationController
  before_action :authenticate_user!

  def create
    company = current_user.company # Assuming user has one company
    @tax_rate = TaxRate.new(tax_rate_params)
    @tax_rate.company = company
    @tax_rate.custom = true

    if @tax_rate.save
      render json: { success: true, tax_rate: @tax_rate }
    else
      render json: { success: false, errors: @tax_rate.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @tax_rate = TaxRate.find(params[:id])
    if @tax_rate.custom && @tax_rate.company == current_user.company
      @tax_rate.destroy
      render json: { success: true }
    else
      render json: { success: false, message: "Unauthorized or System Rate" }, status: :unauthorized
    end
  end

  private

  def tax_rate_params
    params.require(:tax_rate).permit(:name, :rate)
  end
end
