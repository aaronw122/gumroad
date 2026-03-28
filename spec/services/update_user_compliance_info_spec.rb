# frozen_string_literal: true

require "spec_helper"

describe UpdateUserComplianceInfo do
  describe "#process" do
    let(:seller) { create(:user) }

    before do
      create(:user_compliance_info, user: seller)
    end

    context "when submitting a US business with an invalid EIN" do
      let(:compliance_params) do
        {
          is_business: true,
          country: "US",
          business_tax_id: "12-345",
          first_name: "Jane",
          last_name: "Doe",
        }
      end

      it "returns an error before saving to the database" do
        expect(StripeMerchantAccountManager).not_to receive(:handle_new_user_compliance_info)

        result = described_class.new(compliance_params:, user: seller).process

        expect(result).to eq({ success: false, error_message: "US business tax IDs (EIN) must have 9 digits." })
        expect(seller.alive_user_compliance_info.business_tax_id).to be_blank
      end
    end

    context "when submitting a US business with a valid EIN" do
      let(:compliance_params) do
        {
          is_business: true,
          country: "US",
          business_tax_id: "12-3456789",
          first_name: "Jane",
          last_name: "Doe",
          business_name: "Test Corp",
          business_street_address: "123 Main St",
          business_city: "San Francisco",
          business_state: "CA",
          business_zip_code: "94107",
          business_type: UserComplianceInfo::BusinessTypes::LLC,
        }
      end

      it "does not return an EIN validation error" do
        allow(StripeMerchantAccountManager).to receive(:handle_new_user_compliance_info)

        result = described_class.new(compliance_params:, user: seller).process

        expect(result[:error_message]).not_to eq("US business tax IDs (EIN) must have 9 digits.")
      end
    end

    context "when submitting a non-US business with a tax ID of any length" do
      let(:compliance_params) do
        {
          is_business: true,
          country: "CA",
          business_tax_id: "12345",
          first_name: "Jane",
          last_name: "Doe",
        }
      end

      it "does not return a US EIN validation error" do
        allow(StripeMerchantAccountManager).to receive(:handle_new_user_compliance_info)

        result = described_class.new(compliance_params:, user: seller).process

        expect(result[:error_message]).not_to eq("US business tax IDs (EIN) must have 9 digits.")
      end
    end

    context "when submitting a US business with a too-long EIN" do
      let(:compliance_params) do
        {
          is_business: true,
          country: "US",
          business_tax_id: "1234567890",
          first_name: "Jane",
          last_name: "Doe",
        }
      end

      it "returns an error" do
        result = described_class.new(compliance_params:, user: seller).process

        expect(result).to eq({ success: false, error_message: "US business tax IDs (EIN) must have 9 digits." })
      end
    end
  end
end
