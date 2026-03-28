class PredictionsController < ApplicationController
  def index
    @predictions = Prediction.order(created_at: :desc).includes(:team1, :team2, :predicted_winner).limit(20)
  end

  def new
    @teams = Team.order(:name)
  end

  def create
    team1 = Team.find(params[:team1_id])
    team2 = Team.find(params[:team2_id])
    venue = params[:venue].presence

    if team1 == team2
      redirect_to new_prediction_path, alert: "Please select two different teams." and return
    end

    @prediction = PredictionService.new(team1, team2, venue: venue).predict_and_save
    redirect_to prediction_path(@prediction)
  rescue ActiveRecord::RecordNotFound
    redirect_to new_prediction_path, alert: "Invalid team selection."
  end

  def show
    @prediction = Prediction.includes(:team1, :team2, :predicted_winner).find(params[:id])
    service = PredictionService.new(@prediction.team1, @prediction.team2, venue: @prediction.venue)
    @breakdown = service.breakdown
  end
end
