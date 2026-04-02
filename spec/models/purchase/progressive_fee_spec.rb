# frozen_string_literal: true

require "spec_helper"

describe Purchase, "progressive fee tiers", :vcr do
  let(:seller) { create(:named_seller) }
  let(:product) { create(:product, user: seller, price_cents: 10_00) }

  before do
    Feature.activate_user(:progressive_fee_tiers, seller)
    MerchantAccount.find_or_create_by!(user_id: nil, charge_processor_id: StripeChargeProcessor.charge_processor_id) do |ma|
      ma.charge_processor_merchant_id = "gumroad_test"
    end
  end

  def expected_fee(price_cents, progressive_per_thousand)
    variable = (price_cents * (progressive_per_thousand + Purchase::PROCESSOR_FEE_PER_THOUSAND) / 1000.0).round
    fixed = Purchase::GUMROAD_FIXED_FEE_CENTS + Purchase::PROCESSOR_FIXED_FEE_CENTS
    variable + fixed
  end

  describe "#progressive_fee_per_thousand" do
    it "returns 300 per thousand for a seller with no MTD sales" do
      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 300))
    end

    it "applies the first tier rate for purchases within the $100 bracket" do
      purchase = create(:purchase, link: product, price_cents: 50_00)

      expect(purchase.fee_cents).to eq(expected_fee(50_00, 300))
    end

    it "splits fee across tiers when a purchase spans the $100 boundary" do
      purchase = create(:purchase, link: product, price_cents: 200_00)

      # First $100 at 300, next $100 at 125 => blended = (100*300 + 100*125) / 200 = 212.5 => 213
      blended = (42_500_00.0 / 200_00).round
      expect(purchase.fee_cents).to eq(expected_fee(200_00, blended))
    end

    it "applies all four tiers for a large purchase with no MTD sales" do
      purchase = create(:purchase, link: product, price_cents: 6_000_00)

      # $100 at 300, $900 at 125, $4000 at 85, $1000 at 49
      # weighted = 100*300 + 900*125 + 4000*85 + 1000*49 = 30000+112500+340000+49000 = 531500
      blended = (53_150_000.0 / 6_000_00).round # 88.58 => 89
      expect(purchase.fee_cents).to eq(expected_fee(6_000_00, blended))
    end

    it "uses second tier rate when seller already has $500 MTD sales" do
      create(:purchase, link: product, price_cents: 500_00, created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 125))
    end

    it "uses lowest tier rate when seller has over $5000 MTD sales" do
      create(:purchase, link: product, price_cents: 6_000_00, created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 49))
    end

    it "spans tiers when purchase crosses the $1000 boundary" do
      create(:purchase, link: product, price_cents: 900_00, created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 200_00)

      # MTD = $900. $100 in $100-$1000 tier at 125, $100 in $1000-$5000 tier at 85
      blended = (21_000_00.0 / 200_00).round # 105
      expect(purchase.fee_cents).to eq(expected_fee(200_00, blended))
    end

    it "handles exact tier boundary at $100" do
      create(:purchase, link: product, price_cents: 100_00, created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 125))
    end

    it "handles exact tier boundary at $1000" do
      create(:purchase, link: product, price_cents: 1_000_00, created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 85))
    end

    it "handles exact tier boundary at $5000" do
      create(:purchase, link: product, price_cents: 5_000_00, created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 49))
    end
  end

  describe "custom_fee_per_thousand overrides progressive pricing" do
    it "uses the seller custom fee instead of progressive tiers" do
      seller.update!(custom_fee_per_thousand: 50)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 50))
    end

    it "uses the purchase custom fee instead of progressive tiers" do
      purchase = create(:purchase, link: product, price_cents: 10_00, custom_fee_per_thousand: 75)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 75))
    end
  end

  describe "Discover fees are unaffected" do
    it "charges the flat 30% Discover fee regardless of progressive tiers" do
      allow_any_instance_of(Link).to receive(:recommendable?).and_return(true)
      purchase = create(:purchase, link: product, price_cents: 10_00,
                                   was_product_recommended: true,
                                   recommended_by: RecommendationType::GUMROAD_SEARCH_RECOMMENDATION)

      expect(purchase.was_discover_fee_charged?).to be(true)
      expect(purchase.fee_cents).to be > 0
    end
  end

  describe "waive_gumroad_fee_on_new_sales still works" do
    it "waives the progressive fee for new sales" do
      Feature.activate_user(:waive_gumroad_fee_on_new_sales, seller)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      # Gumroad percentage waived, but fixed Gumroad fee + processor fees still apply
      variable_processor = (10_00 * Purchase::PROCESSOR_FEE_PER_THOUSAND / 1000.0).round
      fixed = Purchase::GUMROAD_FIXED_FEE_CENTS + Purchase::PROCESSOR_FIXED_FEE_CENTS
      expect(purchase.fee_cents).to eq(variable_processor + fixed)
    end
  end

  describe "MTD calculation" do
    it "does not count failed purchases" do
      create(:purchase, link: product, price_cents: 500_00, purchase_state: "failed", created_at: 1.day.ago)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 300))
    end

    it "does not count purchases from previous months" do
      create(:purchase, link: product, price_cents: 6_000_00,
                        created_at: 1.month.ago.beginning_of_month)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, 300))
    end
  end

  describe "feature flag disabled" do
    it "uses the flat fee when progressive_fee_tiers is not active" do
      Feature.deactivate_user(:progressive_fee_tiers, seller)

      purchase = create(:purchase, link: product, price_cents: 10_00)

      expect(purchase.fee_cents).to eq(expected_fee(10_00, Purchase::GUMROAD_FLAT_FEE_PER_THOUSAND))
    end
  end
end
