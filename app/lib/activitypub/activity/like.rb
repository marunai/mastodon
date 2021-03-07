# frozen_string_literal: true
require 'uri'

class ActivityPub::Activity::Like < ActivityPub::Activity
  def perform
    original_status = status_from_uri(object_uri)

    return if original_status.nil? || delete_arrived_first?(@json['id']) || @account.favourited?(original_status)

    #FIX SIRO
    if @json.has_key?('_misskey_reaction')
      if @json.has_key?('tag')
        return if @json['tag'][0]['id'].blank? || @json['tag'][0]['name'].blank? || @json['tag'][0]['icon'].blank? || @json['tag'][0]['icon']['url'].blank?
        shortcode = @json['tag'][0]['name'].delete(':')
        image_url = @json['tag'][0]['icon']['url']
        uri       = @json['tag'][0]['id']
        domain    = URI.split(uri)[2]
        emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
        if emoji.nil?
          emoji ||= CustomEmoji.new(domain: domain, shortcode: shortcode, uri: uri, image_remote_url: image_url)
          emoji.save
        end
        if image_url != emoji.image_remote_url
          emoji.image_remote_url = image_url
          emoji.save
        end

        return if @account.reacted_with_id?(original_status, shortcode, emoji.id)
        @reaction = original_status.emoji_reactions.create!(account: @account, name: shortcode, custom_emoji_id: emoji.id)

      else
        return if @account.reacted?(original_status, @json['_misskey_reaction'])
        @reaction = original_status.emoji_reactions.create!(account: @account, name: @json['_misskey_reaction'])
      end
    end

    return if !original_status.account.local?

    favourite = original_status.favourites.create!(account: @account)
    NotifyService.new.call(original_status.account, :favourite, favourite)
  end
end
