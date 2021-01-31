# frozen_string_literal: true

class ActivityPub::Activity::Like < ActivityPub::Activity
  def perform
    original_status = status_from_uri(object_uri)

    return if original_status.nil? || !original_status.account.local? || delete_arrived_first?(@json['id']) || @account.favourited?(original_status)

    if @json.has_key?('_misskey_reaction')
    # should be check _misskey_reaction...blank?... fix later
    # These processes should be the work of the validator... Don't write here...?
      if @json.has_key?('tag')
        return if @json['tag'][0]['id'].blank? || @json['tag'][0]['name'].blank? || @json['tag'][0]['icon'].blank? || @json['tag'][0]['icon']['url'].blank?
        shortcode = @json['tag'][0]['name'].delete(':')
        image_url = @json['tag'][0]['icon']['url']
        uri       = @json['tag'][0]['id']
        updated   = @json['tag'][0]['updated']
        emoji = CustomEmoji.find_by(shortcode: shortcode, domain: @account.domain)
        if emoji.nil? || image_url != emoji.image_remote_url || (updated && updated >= emoji.updated_at)
          emoji ||= CustomEmoji.new(domain: @account.domain, shortcode: shortcode, uri: uri)
          emoji.image_remote_url = image_url
          emoji.save
        end
        return if @account.reacted_with_id?(original_status, shortcode, emoji.id)
        reaction = original_status.emoji_reactions.create!(account: @account, name: shortcode, custom_emoji_id: emoji.id)
      else
        return if @account.reacted?(original_status, @json['_misskey_reaction'])
        reaction = original_status.emoji_reactions.create!(account: @account, name: @json['_misskey_reaction'])
      end
    end

    favourite = original_status.favourites.create!(account: @account)
    NotifyService.new.call(original_status.account, :favourite, favourite)
  end
end
