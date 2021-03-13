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

  def destroy
    shortcode = params[:id].split("@")[0]
    domain    = params[:id].split("@")[1]
    domain    = nil if domain.eql?("undefined")
    custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
    # custom emoji
    unless custom_emoji.nil?
      if current_account.reacted_with_id?(@status, shortcode, custom_emoji.id)
        UnreactionWorker.perform_async(current_account.id, @status.id, params[:id])
      end
    # unicode emoji
    else
      if current_account.reacted?(@status, shortcode)
        UnreactionWorker.perform_async(current_account.id, @status.id, params[:id])
      end
    end
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
