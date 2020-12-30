# frozen_string_literal: true

class RandomFeed < Feed
  # @param [Account] account
  # @param [Hash] options
  def initialize(account, options = {})
    @account = account
    @options = options
  end

  # @param [Integer] limit
  # @param [Integer] max_id
  # @param [Integer] since_id
  # @param [Integer] min_id
  # @return [Array<Status>]
  def get(limit, max_id = nil, since_id = nil, min_id = nil)
    scope = random_scope
  end

  private

  def random_scope
#    DEFAULT_STATUSES_LIMIT = 20
     Status.find_by_sql("SELECT * FROM statuses WHERE visibility=0 AND statuses.reply = FALSE OR statuses.in_reply_to_account_id = statuses.account_id AND statuses.reblog_of_id IS NULL OFFSET random() LIMIT 20")
  end
end

