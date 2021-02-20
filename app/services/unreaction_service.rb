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

  def build_reaction_unicode_json(reaction)
    Rails.logger.info "serialise"
    undo_like = serialize_payload(reaction, ActivityPub::UndoLikeSerializer)
#    undo_like["object"]["content"] = "#{reaction.name}"
#    undo_like["object"]["_misskey_reaction"] = "#{reaction.name}"
    Oj.dump(undo_like)
  end

  def build_reaction_custom_json(reaction)
    undo_like = serialize_payload(reaction, ActivityPub::UndoLikeSerializer)
#    undo_like["object"]["content"] = ":#{reaction.name}:"
#    undo_like["object"]["_misskey_reaction"] = ":#{reaction.name}:"

    # fix siro
#    custom_emoji = CustomEmoji.find(reaction.custom_emoji_id)

#    url = full_asset_url(custom_emoji.image.url(:original))
#    unless custom_emoji.image_remote_url.nil?
#      url = custom_emoji.image_remote_url
#    end

#    emoji = serialize_payload(custom_emoji, ActivityPub::EmojiSerializer)

#    undo_like["object"]["tag"] = [{
#      "id" => ActivityPub::TagManager.instance.uri_for(custom_emoji),
#      "type" => "Emoji",
#      "name" => ":#{custom_emoji.shortcode}:",
#      "updated" => custom_emoji.updated_at.iso8601,
#      "icon" => {
#        "type" => "Image",
#        "mediaType" => custom_emoji.image.content_type,
#        "url" => url,
#      },
#    }]
    Oj.dump(undo_like)
  end
end
