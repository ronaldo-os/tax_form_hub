class RecommendationsController < ApplicationController
  before_action :set_company

  def create
    if current_user.companies.include?(@company)
      return redirect_to @company, alert: "You cannot write a recommendation for your own company."
    end

    @recommendation = @company.recommendations.build(recommendation_params)
    @recommendation.user = current_user

    if @recommendation.save
      redirect_to @company, notice: "Recommendation submitted successfully."
    else
      redirect_to @company, alert: "Failed to submit recommendation."
    end
  end

  private

  def set_company
    @company = Company.find_by(slug: params[:company_id]) || Company.find_by(id: params[:company_id])
    unless @company
      redirect_to networks_path, alert: "Company not found."
    end
  end

  def recommendation_params
    params.require(:recommendation).permit(:text)
  end
end
