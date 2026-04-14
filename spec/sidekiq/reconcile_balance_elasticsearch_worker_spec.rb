# frozen_string_literal: true

require "spec_helper"

describe ReconcileBalanceElasticsearchWorker do
  describe "#perform" do
    let(:user) { create(:user) }

    it "does nothing when DB and ES are in sync" do
      allow(Balance).to receive(:amount_cents_sum_for).with(user).and_return(0)

      expect(ElasticsearchIndexerWorker).not_to receive(:perform_async)
      described_class.new.perform(user.id)
    end

    it "reindexes unpaid balances when drift is detected" do
      balance = create(:balance, user:, merchant_account: user.merchant_account, amount_cents: 1000, state: "unpaid")
      allow(Balance).to receive(:amount_cents_sum_for).with(user).and_return(500)

      expect(ElasticsearchIndexerWorker).to receive(:perform_async).with(
        "index",
        { "record_id" => balance.id, "class_name" => "Balance" }
      )

      described_class.new.perform(user.id)
    end
  end
end
