class RecommendationsController < ApplicationController
  before_action :set_company

  def create
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
    @company = Company.find(params[:company_id])
  end

  def recommendation_params
    params.require(:recommendation).permit(:text)
  end
end
