# frozen_string_literal: true

class UnreactionService < BaseService
  include Payloadable

  def call(account, status, emoji)
    shortcode = emoji.split("@")[0]
    domain    = emoji.split("@")[1]
    domain    = nil if domain.eql?("undefined")

    custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)

    reaction = nil
    reaction = EmojiReaction.find_by(account: account, status: status, name: shortcode)
    return reaction if reaction.nil?
    build_reaction_unicode_json(reaction)
    unless custom_emoji.nil?
      if status.account.activitypub?
        ActivityPub::DeliveryWorker.perform_async(build_reaction_custom_json(reaction), reaction.account_id, status.account.inbox_url)
      end
    else
      if status.account.activitypub?
        ActivityPub::DeliveryWorker.perform_async(build_reaction_unicode_json(reaction), reaction.account_id, status.account.inbox_url)
      end
    end
    reaction.destroy!      
    reaction

  end

  private

  #FIX SIRO
  def build_reaction_unicode_json(reaction)
    undo_like = serialize_payload(reaction, ActivityPub::UndoLikeSerializer)
    Oj.dump(undo_like)
  end

  def build_reaction_custom_json(reaction)
    undo_like = serialize_payload(reaction, ActivityPub::UndoLikeSerializer)
    Oj.dump(undo_like)
  end
end
