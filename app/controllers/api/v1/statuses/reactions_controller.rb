# frozen_string_literal: true

class Api::V1::Statuses::ReactionsController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:favourites' }
  before_action :require_user!
  before_action :set_status

  def update
    ReactionService.new.call(current_account, @status, params[:id])
    render json: @status, serializer: REST::StatusSerializer
  end

  private

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end
end
