class PredictionsController < ApplicationController
  def index
    @predictions = Prediction.order(created_at: :desc)
                              .includes(:team1, :team2, :predicted_winner)
                              .limit(20)
  end

  def new
    @teams = Team.order(:name)
  end

  def create
    team1 = Team.find(params[:team1_id])
    team2 = Team.find(params[:team2_id])

    if team1 == team2
      redirect_to new_prediction_path, alert: "Please select two different teams." and return
    end

    toss_winner = params[:toss_winner_id].present? ? Team.find(params[:toss_winner_id]) : nil

    service = PredictionService.new(
      team1, team2,
      venue:       params[:venue].presence,
      toss_winner: toss_winner,
      xi_team1:    params[:xi_team1].to_s.split("\n"),
      xi_team2:    params[:xi_team2].to_s.split("\n")
    )

    @prediction = service.predict
    @prediction.xi_team1 = params[:xi_team1].presence
    @prediction.xi_team2 = params[:xi_team2].presence
    @prediction.save!

    redirect_to prediction_path(@prediction)
  rescue ActiveRecord::RecordNotFound
    redirect_to new_prediction_path, alert: "Invalid team selection."
  end

  def show
    @prediction = Prediction.includes(:team1, :team2, :predicted_winner).find(params[:id])
    service = PredictionService.new(
      @prediction.team1,
      @prediction.team2,
      venue:    @prediction.venue,
      xi_team1: @prediction.xi_team1_list,
      xi_team2: @prediction.xi_team2_list
    )
    @breakdown   = service.breakdown
    @xi_provided = service.xi_provided?
    @play        = @prediction.play?
  end
end
