Rails.application.routes.draw do
  root "predictions#new"

  resources :teams, only: [:index, :show]
  resources :matches, only: [:index, :new, :create]
  resources :predictions, only: [:index, :new, :create, :show]

  get "up" => "rails/health#show", as: :rails_health_check
end
