# frozen_string_literal: true

require "spec_helper"

describe Balance::Searchable do
  it "includes ElasticsearchModelAsyncCallbacks" do
    expect(Balance).to include(ElasticsearchModelAsyncCallbacks)
  end

  describe "extra ES callbacks for balance records" do
    it "schedules a 30-minute ES re-index and a 10-minute reconciliation on update" do
      user = create(:user)
      balance = create(:balance, user:, merchant_account: user.merchant_account, amount_cents: 100, state: "unpaid")
      ElasticsearchIndexerWorker.jobs.clear
      ReconcileBalanceElasticsearchWorker.jobs.clear

      balance.update!(amount_cents: 200)

      es_jobs = ElasticsearchIndexerWorker.jobs
      # Standard: 4s delay + 3min delay + 30min delay = 3 update jobs
      update_jobs = es_jobs.select { |j| j["args"].first == "update" }
      expect(update_jobs.size).to eq(3)

      reconcile_jobs = ReconcileBalanceElasticsearchWorker.jobs
      expect(reconcile_jobs.size).to eq(1)
      expect(reconcile_jobs.first["args"]).to eq([user.id])
    end
  end
end
