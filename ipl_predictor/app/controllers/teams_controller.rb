class TeamsController < ApplicationController
  def index
    @teams = Team.order(:name)
  end

  def show
    @team = Team.find(params[:id])
    @recent_matches = @team.matches.order(match_date: :desc).limit(10).includes(:team1, :team2, :winner)
  end
end
