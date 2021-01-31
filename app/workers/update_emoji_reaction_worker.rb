# frozen_string_literal: true

class UpdateEmojiReactionWorker
  include Sidekiq::Worker
  include Redisable

  def perform(status_id, name)
    status = Status.find(status_id)

    reaction,  = status.emoji_reactions.where(name: name).group(:status_id, :name, :custom_emoji_id).select('name, custom_emoji_id, count(*) as count, false as me')
    reaction ||= status.emoji_reactions.new(name: name)

    payload = InlineRenderer.render(reaction, nil, :reaction).tap { |h| h[:status_id] = status_id.to_s }
    payload = Oj.dump(event: :'status.reaction', payload: payload)

    Rails.logger.info "UpdateEmojiReactionWorker!!!"
    Rails.logger.info "#{payload}"

    FeedManager.instance.with_active_accounts do |account|
      redis.publish("timeline:#{account.id}", payload) if redis.exists?("subscribed:timeline:#{account.id}")
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
