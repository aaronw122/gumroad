# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorize_called"

RSpec.describe StripeAccountSessionsController do
  let(:seller) { create(:named_seller) }
  let(:connected_account_id) { "acct_123" }

  before do
    sign_in(seller)
  end

  describe "#create" do
    it_behaves_like "authorize called for action", :post, :create do
      let(:policy_klass) { StripeAccountSessions::UserPolicy }
      let(:record) { seller }
    end

    context "when seller has a stripe account" do
      before do
        allow_any_instance_of(User).to receive(:stripe_account).and_return(double(charge_processor_merchant_id: connected_account_id))
      end

      it "creates a stripe account session with notification_banner by default" do
        stripe_session = double(client_secret: "secret_123")
        expect(Stripe::AccountSession).to receive(:create).with(
          {
            account: connected_account_id,
            components: {
              notification_banner: {
                enabled: true,
                features: { external_account_collection: true }
              }
            }
          }
        ).and_return(stripe_session)

        post :create
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "success" => true,
          "client_secret" => "secret_123"
        )
      end

      it "creates a stripe account session with account_onboarding when requested" do
        stripe_session = double(client_secret: "secret_456")
        expect(Stripe::AccountSession).to receive(:create).with(
          {
            account: connected_account_id,
            components: {
              account_onboarding: {
                enabled: true,
                features: {
                  external_account_collection: true,
                  disable_stripe_user_authentication: true
                }
              }
            }
          }
        ).and_return(stripe_session)

        post :create, params: { component: "account_onboarding" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "success" => true,
          "client_secret" => "secret_456"
        )
      end

      it "handles stripe errors" do
        expect(Stripe::AccountSession).to receive(:create).and_raise(StandardError.new("Stripe error"))
        expect(ErrorNotifier).to receive(:notify).with("Failed to create stripe account session for user #{seller.id}: Stripe error")

        post :create
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "success" => false,
          "error_message" => "Failed to create stripe account session"
        )
      end
    end

    context "when seller does not have a stripe account" do
      before do
        allow_any_instance_of(User).to receive(:stripe_account).and_return(nil)
      end

      it "returns an error for notification_banner requests" do
        post :create
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "success" => false,
          "error_message" => "User does not have a Stripe account"
        )
      end

      context "when requesting account_onboarding with feature flag enabled" do
        before do
          Feature.activate(:stripe_embedded_onboarding)
          create(:user_compliance_info, user: seller, country: "United States")
        end

        after do
          Feature.deactivate(:stripe_embedded_onboarding)
        end

        it "creates a minimal Stripe account and returns an account session" do
          stripe_account = double(id: "acct_new_123")
          expect(Stripe::Account).to receive(:create).with(
            hash_including(
              type: "custom",
              country: "US",
              default_currency: "usd",
              requested_capabilities: %w(card_payments transfers),
              business_type: "individual",
              business_profile: { url: seller.business_profile_url }
            )
          ).and_return(stripe_account)

          stripe_session = double(client_secret: "secret_new_789")
          expect(Stripe::AccountSession).to receive(:create).with(
            {
              account: "acct_new_123",
              components: {
                account_onboarding: {
                  enabled: true,
                  features: {
                    external_account_collection: true,
                    disable_stripe_user_authentication: true
                  }
                }
              }
            }
          ).and_return(stripe_session)

          post :create, params: { component: "account_onboarding" }
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(
            "success" => true,
            "client_secret" => "secret_new_789"
          )

          merchant_account = seller.merchant_accounts.alive.stripe.last
          expect(merchant_account.charge_processor_merchant_id).to eq("acct_new_123")
          expect(merchant_account.country).to eq("US")
          expect(merchant_account.currency).to eq("usd")
          expect(merchant_account.charge_processor_alive_at).to be_present
          expect(merchant_account.is_stripe_embedded_onboarding_account?).to eq(true)
        end

        it "reuses existing Stripe account if one already exists" do
          create(:merchant_account, user: seller, charge_processor_merchant_id: "acct_existing")
          allow_any_instance_of(User).to receive(:stripe_account).and_return(nil)
          seller.reload

          stripe_session = double(client_secret: "secret_existing")
          expect(Stripe::Account).not_to receive(:create)
          expect(Stripe::AccountSession).to receive(:create).with(
            hash_including(account: "acct_existing")
          ).and_return(stripe_session)

          post :create, params: { component: "account_onboarding" }
          expect(response.parsed_body["success"]).to eq(true)
        end

        it "resumes onboarding for an unverified embedded onboarding account" do
          create(:merchant_account, user: seller,
                                    charge_processor_merchant_id: "acct_unverified",
                                    charge_processor_verified_at: nil,
                                    json_data: { "stripe_embedded_onboarding" => true })

          stripe_session = double(client_secret: "secret_resume")
          expect(Stripe::Account).not_to receive(:create)
          expect(Stripe::AccountSession).to receive(:create).with(
            hash_including(account: "acct_unverified")
          ).and_return(stripe_session)

          post :create, params: { component: "account_onboarding" }
          expect(response.parsed_body).to eq(
            "success" => true,
            "client_secret" => "secret_resume"
          )
        end

        it "returns an error when Stripe account creation fails" do
          expect(Stripe::Account).to receive(:create).and_raise(Stripe::InvalidRequestError.new("Invalid", "country"))
          expect(ErrorNotifier).to receive(:notify)

          post :create, params: { component: "account_onboarding" }
          expect(response.parsed_body).to eq(
            "success" => false,
            "error_message" => "Unable to create Stripe account"
          )
        end
      end

      context "when requesting account_onboarding without feature flag" do
        it "returns an error" do
          create(:user_compliance_info, user: seller, country: "United States")

          post :create, params: { component: "account_onboarding" }
          expect(response.parsed_body).to eq(
            "success" => false,
            "error_message" => "Unable to create Stripe account"
          )
        end
      end

      context "when requesting account_onboarding for non-US country" do
        before do
          Feature.activate(:stripe_embedded_onboarding)
          create(:user_compliance_info, user: seller, country: "Canada")
        end

        after do
          Feature.deactivate(:stripe_embedded_onboarding)
        end

        it "creates a minimal Stripe account for the supported country" do
          stripe_account = double(id: "acct_ca_123")
          expect(Stripe::Account).to receive(:create).with(
            hash_including(
              type: "custom",
              country: "CA"
            )
          ).and_return(stripe_account)

          stripe_session = double(client_secret: "secret_ca")
          expect(Stripe::AccountSession).to receive(:create).and_return(stripe_session)

          post :create, params: { component: "account_onboarding" }
          expect(response.parsed_body["success"]).to eq(true)
        end
      end
    end
  end
end
