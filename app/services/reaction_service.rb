# frozen_string_literal: true

class ReactionService < BaseService
  include Authorization
  include Payloadable

  def call(account, status, emoji)
    reaction     = EmojiReaction.find_by(account_id: account.id, status_id: status.id)

    return reaction unless reaction.nil?

    shortcode = emoji.split("@")[0]
    domain    = emoji.split("@")[1]
    domain    = nil if ['undefined', 'null'].include?(domain)

    custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)

    reaction = EmojiReaction.create(account: account, status: status, name: shortcode, custom_emoji: custom_emoji)

    create_notification(reaction)
    bump_potential_friendship(account, status)

    reaction
  end

  private 

  def create_notification(reaction)
    status = reaction.status

    if status.account.local?
      NotifyService.new.call(status.account, :reaction, reaction)
    elsif status.account.activitypub?
      ActivityPub::DeliveryWorker.perform_async(build_json(reaction), reaction.account_id, status.account.inbox_url)
    end
  end

  def bump_potential_friendship(account, status)
    ActivityTracker.increment('activity:interactions')
    return if account.following?(status.account_id)
    PotentialFriendshipTracker.record(account.id, status.account_id, :reaction)
  end

  def build_json(reaction)
    Oj.dump(serialize_payload(reaction, ActivityPub::EmojiReactionSerializer))
  end
end
