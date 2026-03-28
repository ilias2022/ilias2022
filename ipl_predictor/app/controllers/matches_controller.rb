class MatchesController < ApplicationController
  def index
    @matches = Match.order(match_date: :desc).includes(:team1, :team2, :winner)
    @matches = @matches.for_season(params[:season]) if params[:season].present?
  end

  def new
    @match = Match.new
    @teams = Team.order(:name)
  end

  def create
    @match = Match.new(match_params)
    if @match.save
      redirect_to matches_path, notice: "Match recorded."
    else
      @teams = Team.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def match_params
    params.require(:match).permit(:team1_id, :team2_id, :venue, :match_date, :winner_id, :season, :toss_winner_id, :toss_decision)
  end
end
