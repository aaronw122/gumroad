# frozen_string_literal: true

class ReconcileBalanceElasticsearchWorker
  include Sidekiq::Job
  sidekiq_options retry: 3, queue: :low

  # Checks for drift between DB and ES balance sums for a given user.
  # If drift is found, reindexes the stale balance records.
  def perform(user_id)
    user = User.find(user_id)

    sql_sum = user.balances.unpaid.sum(:amount_cents)
    es_sum = Balance.amount_cents_sum_for(user)

    return if sql_sum == es_sum

    Rails.logger.warn(
      "[BalanceReconciliation] Drift detected for user #{user_id}: " \
      "DB=#{sql_sum}, ES=#{es_sum}, delta=#{es_sum - sql_sum}"
    )

    user.balances.unpaid.find_each do |balance|
      ElasticsearchIndexerWorker.perform_async(
        "index",
        { "record_id" => balance.id, "class_name" => "Balance" }
      )
    end
  end
end
