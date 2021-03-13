# frozen_string_literal: true

class ReactionService < BaseService
  include Authorization
  include Payloadable

  def call(account, status, emoji)
    shortcode = emoji.split("@")[0]
    domain    = emoji.split("@")[1]
    domain    = nil if domain.eql?("undefined")

    custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)

    reaction = EmojiReaction.find_by(account_id: account.id, status_id: status.id)

    return reaction unless reaction.nil?

    # custom emoji
    unless custom_emoji.nil?
      reaction = EmojiReaction.create(account: account, status: status, name: shortcode, custom_emoji_id: custom_emoji.id)
      if status.account.activitypub?
        ActivityPub::DeliveryWorker.perform_async(build_reaction_custom_json(reaction), reaction.account_id, status.account.inbox_url)
      end
    # unicode emoji
    else
      reaction = EmojiReaction.create(account: account, status: status, name: shortcode)
      if status.account.activitypub?
        ActivityPub::DeliveryWorker.perform_async(build_reaction_unicode_json(reaction), reaction.account_id, status.account.inbox_url)
      end
    end
    reaction
  end

  private 

  # It is desirable to use Serializer...
  # Should be the same function "build_json"???
  def build_reaction_unicode_json(reaction)
    like = serialize_payload(reaction, ActivityPub::LikeSerializer)
    like["content"] = "#{reaction.name}"
    like["_misskey_reaction"] = "#{reaction.name}"
    Oj.dump(like)
  end

  # It is desirable to use Serializer...
  # Should be the same function "build_json"???
  def build_reaction_custom_json(reaction)
    like = serialize_payload(reaction, ActivityPub::LikeSerializer)
    like["content"] = ":#{reaction.name}:"
    like["_misskey_reaction"] = ":#{reaction.name}:"

    custom_emoji = CustomEmoji.find(reaction.custom_emoji_id)

    url = full_asset_url(custom_emoji.image.url(:original))
    unless custom_emoji.image_remote_url.nil?
      url = custom_emoji.image_remote_url
    end

    emoji = serialize_payload(custom_emoji, ActivityPub::EmojiSerializer)

    like["tag"] = [{
      "id" => ActivityPub::TagManager.instance.uri_for(custom_emoji),
      "type" => "Emoji",
      "name" => ":#{custom_emoji.shortcode}:",
      "updated" => custom_emoji.updated_at.iso8601,
      "icon" => {
        "type" => "Image",
        "mediaType" => custom_emoji.image.content_type,
        "url" => url,
      },
    }]
    Oj.dump(like)
  end
end
