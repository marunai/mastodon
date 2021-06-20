# frozen_string_literal: true

class ActivityPub::Activity::Like < ActivityPub::Activity
  def perform
    @original_status = status_from_uri(object_uri)

    return if @original_status.nil? || delete_arrived_first?(@json['id'])

    lock_or_fail("like:#{object_uri}") do
      if shortcode.nil?
        process_favourite
      else
        process_reaction
      end
    end
  end

  private

  def process_favourite
    return if @account.favourited?(@original_status)

    favourite = @original_status.favourites.create!(account: @account)

    NotifyService.new.call(@original_status.account, :favourite, favourite) if @original_status.account.local?
  end

  def process_reaction
    if emoji_tag.present?
      return if emoji_tag['id'].blank? || emoji_tag['name'].blank? || emoji_tag['icon'].blank? || emoji_tag['icon']['url'].blank?

      image_url = emoji_tag['icon']['url']
      uri       = emoji_tag['id']
      domain    = URI.split(uri)[2]

      emoji = CustomEmoji.find_or_create_by!(shortcode: shortcode, domain: domain) do |emoji|
        emoji.uri              = uri
        emoji.image_remote_url = image_url
      end
    end

    return if @account.reacted?(@original_status, shortcode, emoji)

    reaction = @original_status.emoji_reactions.create!(account: @account, name: shortcode, custom_emoji: emoji, uri: @json['id'])

    NotifyService.new.call(@original_status.account, :emoji_reaction, reaction) if @original_status.account.local?
  rescue Seahorse::Client::NetworkingError
    nil
  end

  def shortcode
    return @shortcode if defined?(@shortcode)

    @shortcode = @json['_misskey_reaction']&.delete(':')
  end

  def emoji_tag
    return @emoji_tag if defined?(@emoji_tag)

    @emoji_tag = @json['tag'].is_a?(Array) ? @json['tag']&.first : @json['tag']
  end
end
