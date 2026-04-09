# frozen_string_literal: true

require "spec_helper"

describe ScheduledPayout do
  describe "validations" do
    it "is valid with valid attributes" do
      scheduled_payout = build(:scheduled_payout)
      expect(scheduled_payout).to be_valid
    end

    it "requires an action" do
      scheduled_payout = build(:scheduled_payout, action: nil)
      expect(scheduled_payout).not_to be_valid
    end

    it "requires action to be one of refund, payout, hold" do
      %w[refund payout hold].each do |action|
        scheduled_payout = build(:scheduled_payout, action: action)
        expect(scheduled_payout).to be_valid
      end

      scheduled_payout = build(:scheduled_payout, action: "invalid")
      expect(scheduled_payout).not_to be_valid
    end

    it "requires a status" do
      scheduled_payout = build(:scheduled_payout, status: nil)
      expect(scheduled_payout).not_to be_valid
    end

    it "requires status to be one of pending, executed, cancelled, flagged" do
      %w[pending executed cancelled flagged].each do |status|
        scheduled_payout = build(:scheduled_payout, status: status)
        expect(scheduled_payout).to be_valid
      end

      scheduled_payout = build(:scheduled_payout, status: "invalid")
      expect(scheduled_payout).not_to be_valid
    end

    it "requires delay_days to be a non-negative integer" do
      scheduled_payout = build(:scheduled_payout, delay_days: -1)
      expect(scheduled_payout).not_to be_valid

      scheduled_payout = build(:scheduled_payout, delay_days: 0)
      expect(scheduled_payout).to be_valid
    end

    it "requires scheduled_at" do
      scheduled_payout = build(:scheduled_payout, scheduled_at: nil, delay_days: nil)
      expect(scheduled_payout).not_to be_valid
    end
  end

  describe "#set_scheduled_at" do
    it "sets scheduled_at from delay_days on create when not provided" do
      freeze_time do
        scheduled_payout = create(:scheduled_payout, scheduled_at: nil, delay_days: 21)
        expect(scheduled_payout.scheduled_at).to eq(21.days.from_now)
      end
    end

    it "does not override scheduled_at if already set" do
      specific_time = 30.days.from_now
      scheduled_payout = create(:scheduled_payout, scheduled_at: specific_time, delay_days: 21)
      expect(scheduled_payout.scheduled_at).to eq(specific_time)
    end
  end

  describe "scopes" do
    let!(:pending_payout) { create(:scheduled_payout, status: "pending", scheduled_at: 1.day.ago) }
    let!(:future_payout) { create(:scheduled_payout, status: "pending", scheduled_at: 1.day.from_now) }
    let!(:executed_payout) { create(:scheduled_payout, status: "executed") }
    let!(:cancelled_payout) { create(:scheduled_payout, status: "cancelled") }
    let!(:flagged_payout) { create(:scheduled_payout, status: "flagged") }

    it "returns pending payouts" do
      expect(described_class.pending).to contain_exactly(pending_payout, future_payout)
    end

    it "returns due payouts" do
      expect(described_class.due).to contain_exactly(pending_payout)
    end

    it "returns executed payouts" do
      expect(described_class.executed).to contain_exactly(executed_payout)
    end

    it "returns cancelled payouts" do
      expect(described_class.cancelled).to contain_exactly(cancelled_payout)
    end

    it "returns flagged payouts" do
      expect(described_class.flagged).to contain_exactly(flagged_payout)
    end
  end

  describe "#execute!" do
    let(:user) { create(:user) }

    context "when action is refund" do
      let(:scheduled_payout) { create(:scheduled_payout, user: user, action: "refund", scheduled_at: 1.day.ago, created_by: create(:user)) }

      it "enqueues RefundUnpaidPurchasesWorker and marks as executed" do
        scheduled_payout.execute!

        expect(RefundUnpaidPurchasesWorker.jobs.size).to eq(1)
        expect(scheduled_payout.reload.status).to eq("executed")
        expect(scheduled_payout.executed_at).to be_present
      end
    end

    context "when action is payout" do
      let(:scheduled_payout) { create(:scheduled_payout, user: user, action: "payout", scheduled_at: 1.day.ago) }

      it "calls Payouts to create instant payout and marks as executed" do
        expect(Payouts).to receive(:create_instant_payouts_for_balances_up_to_date_for_users)
          .with(Date.yesterday, [user], from_admin: true)

        scheduled_payout.execute!

        expect(scheduled_payout.reload.status).to eq("executed")
        expect(scheduled_payout.executed_at).to be_present
      end
    end

    context "when action is payout above threshold" do
      let(:scheduled_payout) { create(:scheduled_payout, user: user, action: "payout", scheduled_at: 1.day.ago, payout_amount_cents: 150_000) }

      it "flags for review instead of executing" do
        expect(Payouts).not_to receive(:create_instant_payouts_for_balances_up_to_date_for_users)

        scheduled_payout.execute!

        expect(scheduled_payout.reload.status).to eq("flagged")
      end
    end

    context "when action is hold" do
      let(:scheduled_payout) { create(:scheduled_payout, user: user, action: "hold", scheduled_at: 1.day.ago) }

      it "does nothing" do
        scheduled_payout.execute!

        expect(scheduled_payout.reload.status).to eq("pending")
      end
    end

    it "raises if already executed" do
      scheduled_payout = create(:scheduled_payout, user: user, status: "executed")
      expect { scheduled_payout.execute! }.to raise_error(RuntimeError, /Cannot execute/)
    end
  end

  describe "#cancel!" do
    it "cancels a pending payout" do
      scheduled_payout = create(:scheduled_payout, status: "pending")
      scheduled_payout.cancel!
      expect(scheduled_payout.reload.status).to eq("cancelled")
    end

    it "cancels a flagged payout" do
      scheduled_payout = create(:scheduled_payout, status: "flagged")
      scheduled_payout.cancel!
      expect(scheduled_payout.reload.status).to eq("cancelled")
    end

    it "raises if already executed" do
      scheduled_payout = create(:scheduled_payout, status: "executed")
      expect { scheduled_payout.cancel! }.to raise_error(RuntimeError, /Cannot cancel/)
    end
  end

  describe "#flag_for_review!" do
    it "flags a pending payout" do
      scheduled_payout = create(:scheduled_payout, status: "pending")
      scheduled_payout.flag_for_review!
      expect(scheduled_payout.reload.status).to eq("flagged")
    end

    it "raises if not pending" do
      scheduled_payout = create(:scheduled_payout, status: "executed")
      expect { scheduled_payout.flag_for_review! }.to raise_error(RuntimeError, /Cannot flag/)
    end
  end

  describe "#user_has_active_chargebacks?" do
    let(:user) { create(:user) }
    let(:product) { create(:product, user: user) }
    let(:scheduled_payout) { create(:scheduled_payout, user: user) }

    it "returns false when user has no chargebacks" do
      expect(scheduled_payout.user_has_active_chargebacks?).to be false
    end

    it "returns true when user has unreversed chargebacks" do
      create(:free_purchase, link: product, chargeback_date: 2.days.ago)
      expect(scheduled_payout.user_has_active_chargebacks?).to be true
    end

    it "returns false when chargebacks are reversed" do
      create(:free_purchase, link: product, chargeback_date: 2.days.ago, chargeback_reversed: true)
      expect(scheduled_payout.user_has_active_chargebacks?).to be false
    end

    it "returns true when user has active disputes" do
      purchase = create(:free_purchase, link: product)
      create(:dispute, purchase: purchase, seller: user)
      expect(scheduled_payout.user_has_active_chargebacks?).to be true
    end

    it "returns false when disputes are won" do
      purchase = create(:free_purchase, link: product)
      dispute = create(:dispute, purchase: purchase, seller: user)
      dispute.mark_formalized!
      dispute.mark_won!
      expect(scheduled_payout.user_has_active_chargebacks?).to be false
    end
  end

  describe "#execute! with chargebacks" do
    let(:user) { create(:user) }
    let(:product) { create(:product, user: user) }

    it "flags for review and sends email when user has active chargebacks" do
      scheduled_payout = create(:scheduled_payout, user: user, action: "payout", scheduled_at: 1.day.ago)
      create(:free_purchase, link: product, chargeback_date: 2.days.ago)

      expect { scheduled_payout.execute! }
        .to have_enqueued_mail(CreatorMailer, :scheduled_payout_chargeback_hold)
        .with(scheduled_payout_id: scheduled_payout.id)

      expect(scheduled_payout.reload.status).to eq("flagged")
    end
  end
end
