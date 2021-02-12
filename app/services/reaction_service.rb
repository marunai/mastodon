# frozen_string_literal: true

class ReactionService < BaseService
  include Authorization
  include Payloadable
  
  def call(account, status, emoji)
    shortcode = emoji.split("@")[0]
    domain    = emoji.split("@")[1]
    domain    = nil if domain.eql?("undefined")

    #fix siro!
    reaction = nil

    custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)

    unless custom_emoji.nil?
      reaction = EmojiReaction.find_by(account: account, status: status, name: shortcode, custom_emoji_id: custom_emoji.id)
    else
      reaction = EmojiReaction.find_by(account: account, status: status, name: shortcode)
    end

    return reaction unless reaction.nil?
    Rails.logger.info "emoji_reaction create!!!"
    unless custom_emoji.nil?
      reaction = EmojiReaction.create(account: account, status: status, name: shortcode, custom_emoji_id: custom_emoji.id)
#      if status.account.activitypub?
#        ActivityPub::DeliveryWorker.perform_async(build_reaction_unicode_json(reaction), reaction.account_id, status.account.inbox_url)
#      end
    else
      reaction = EmojiReaction.create(account: account, status: status, name: shortcode)
      if status.account.activitypub?
        Rails.logger.info "#{build_reaction_unicode_json(reaction)}"
        ActivityPub::DeliveryWorker.perform_async(build_reaction_unicode_json(reaction), reaction.account_id, status.account.inbox_url)
      end
    end
    reaction
  end

  private 

  def build_reaction_unicode_json(reaction)
    like = serialize_payload(reaction, ActivityPub::LikeSerializer)
    like["content"] = "#{reaction.name}"
    like["_misskey_reaction"] = "#{reaction.name}"
    Oj.dump(like)
  end
end
