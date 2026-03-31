# frozen_string_literal: true

class StripeAccountSessionsController < Sellers::BaseController
  before_action :authorize

  def create
    component = params[:component]&.to_sym || :notification_banner

    connected_account_id = current_seller.stripe_account&.charge_processor_merchant_id

    if connected_account_id.blank? && component == :account_onboarding
      connected_account_id = ensure_stripe_account_for_embedded_onboarding
      return render json: { success: false, error_message: "Unable to create Stripe account" } if connected_account_id.blank?
    elsif connected_account_id.blank?
      return render json: { success: false, error_message: "User does not have a Stripe account" }
    end

    begin
      session = Stripe::AccountSession.create(
        {
          account: connected_account_id,
          components: components_for(component)
        }
      )

      render json: { success: true, client_secret: session.client_secret }
    rescue => e
      ErrorNotifier.notify("Failed to create stripe account session for user #{current_seller.id}: #{e.message}")
      render json: { success: false, error_message: "Failed to create stripe account session" }
    end
  end

  private
    def authorize
      super([:stripe_account_sessions, current_seller])
    end

    def components_for(component)
      case component
      when :account_onboarding
        {
          account_onboarding: {
            enabled: true,
            features: {
              external_account_collection: true,
              disable_stripe_user_authentication: true
            }
          }
        }
      else
        {
          notification_banner: {
            enabled: true,
            features: { external_account_collection: true }
          }
        }
      end
    end

    def ensure_stripe_account_for_embedded_onboarding
      return nil if !Feature.active?(:stripe_embedded_onboarding, current_seller)

      compliance_info = current_seller.alive_user_compliance_info
      return nil if compliance_info.blank?

      country_code = compliance_info.legal_entity_country_code
      return nil if country_code.blank?
      return nil if !current_seller.native_payouts_supported?

      country = Country.new(country_code)
      currency = country.payout_currency
      return nil if currency.blank?

      ActiveRecord::Base.connection.stick_to_primary!
      current_seller.with_lock do
        existing = current_seller.merchant_accounts.alive.stripe.find { |ma| !ma.is_a_stripe_connect_account? }
        return existing.charge_processor_merchant_id if existing.present?

        stripe_account = Stripe::Account.create(
          type: "custom",
          country: country_code,
          default_currency: currency,
          requested_capabilities: country.stripe_capabilities,
          business_type: "individual",
          business_profile: {
            url: current_seller.business_profile_url
          },
          settings: { payouts: { schedule: { interval: "manual" } } }
        )

        merchant_account = MerchantAccount.create!(
          user: current_seller,
          country: country_code,
          currency: currency,
          charge_processor_id: StripeChargeProcessor.charge_processor_id,
          charge_processor_merchant_id: stripe_account.id,
          charge_processor_alive_at: Time.current,
          stripe_embedded_onboarding: true
        )

        stripe_account.id
      end
    rescue Stripe::StripeError => e
      ErrorNotifier.notify("Failed to create minimal Stripe account for embedded onboarding, user #{current_seller.id}: #{e.message}")
      nil
    end
end
