# frozen_string_literal: true

return if LIVE_STRIPE

module StripeTestStubs
  POSTAL_CODE_PATTERNS = {
    "AT" => /\A\d{4}\z/,
    "AU" => /\A\d{4}\z/,
    "BE" => /\A\d{4}\z/,
    "BG" => /\A\d{4}\z/,
    "BR" => /\A\d{5}-?\d{3}\z/,
    "CA" => /\A[A-Z]\d[A-Z]\s?\d[A-Z]\d\z/i,
    "CH" => /\A\d{4}\z/,
    "CY" => /\A\d{4}\z/,
    "CZ" => /\A\d{3}\s?\d{2}\z/,
    "DE" => /\A\d{5}\z/,
    "DK" => /\A\d{4}\z/,
    "EE" => /\A\d{5}\z/,
    "ES" => /\A\d{5}\z/,
    "FI" => /\A\d{5}\z/,
    "FR" => /\A\d{5}\z/,
    "GB" => /\A[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}\z/i,
    "GR" => /\A\d{3}\s?\d{2}\z/,
    "HK" => /\A.+\z/,
    "HR" => /\A\d{5}\z/,
    "HU" => /\A\d{4}\z/,
    "IE" => /\A[A-Z\d]{3}\s?[A-Z\d]{4}\z/i,
    "IT" => /\A\d{5}\z/,
    "JP" => /\A\d{3}-?\d{4}\z/,
    "LT" => /\A(LT-)?\d{5}\z/i,
    "LU" => /\A\d{4}\z/,
    "LV" => /\A(LV-)?\d{4}\z/i,
    "MT" => /\A[A-Z]{3}\s?\d{4}\z/i,
    "NL" => /\A\d{4}\s?[A-Z]{2}\z/i,
    "NO" => /\A\d{4}\z/,
    "NZ" => /\A\d{4}\z/,
    "PL" => /\A\d{2}-?\d{3}\z/,
    "PT" => /\A\d{4}(-?\d{3})?\z/,
    "RO" => /\A\d{6}\z/,
    "SE" => /\A\d{3}\s?\d{2}\z/,
    "SG" => /\A\d{6}\z/,
    "SI" => /\A\d{4}\z/,
    "SK" => /\A\d{3}\s?\d{2}\z/,
    "US" => /\A\d{5}(-\d{4})?\z/,
  }.freeze

  class Store
    attr_reader :accounts, :charges, :payment_intents, :setup_intents,
                :customers, :payment_methods, :refunds, :transfers,
                :payouts, :disputes, :tokens, :persons, :balance_transactions

    def initialize
      reset!
    end

    def reset!
      @accounts = {}
      @charges = {}
      @payment_intents = {}
      @setup_intents = {}
      @customers = {}
      @payment_methods = {}
      @refunds = {}
      @transfers = {}
      @payouts = {}
      @disputes = {}
      @tokens = {}
      @persons = {}
      @balance_transactions = {}
    end
  end

  module_function

  def mock_id(prefix)
    "#{prefix}_mock_#{SecureRandom.hex(8)}"
  end

  def now_ts
    Time.now.to_i
  end

  def construct(hash)
    Stripe::StripeObject.construct_from(hash.deep_stringify_keys)
  end

  def validate_postal_code!(params)
    postal_code = params.dig(:individual, :address, :postal_code) || params.dig(:company, :address, :postal_code)
    country_code = params[:country]

    return unless postal_code.present? && country_code.present?

    pattern = POSTAL_CODE_PATTERNS[country_code]
    return unless pattern && !postal_code.match?(pattern)

    raise Stripe::InvalidRequestError.new(
      "The postal code you entered is not valid.",
      "postal_code",
      code: "postal_code_invalid"
    )
  end

  def install!(store)
    install_account_stubs!(store)
    install_charge_stubs!(store)
    install_payment_intent_stubs!(store)
    install_setup_intent_stubs!(store)
    install_customer_stubs!(store)
    install_payment_method_stubs!(store)
    install_refund_stubs!(store)
    install_transfer_stubs!(store)
    install_payout_stubs!(store)
    install_balance_stubs!(store)
    install_balance_transaction_stubs!(store)
    install_dispute_stubs!(store)
    install_token_stubs!(store)
    install_account_link_stubs!(store)
    install_account_session_stubs!(store)
    install_person_stubs!(store)
    install_apple_pay_domain_stubs!(store)
    install_mandate_stubs!(store)
    install_early_fraud_warning_stubs!(store)
    install_application_fee_stubs!(store)
    install_file_stubs!(store)
  end

  def install_account_stubs!(store)
    allow(Stripe::Account).to receive(:create) do |params = {}, opts = {}|
      StripeTestStubs.validate_postal_code!(params)
      id = StripeTestStubs.mock_id("acct")
      country = params[:country] || "US"
      account = {
        id: id,
        object: "account",
        type: params[:type] || "custom",
        country: country,
        default_currency: params[:default_currency] || (country == "US" ? "usd" : "eur"),
        charges_enabled: true,
        payouts_enabled: true,
        capabilities: { "card_payments" => "active", "transfers" => "active" },
        external_accounts: {
          object: "list",
          data: [{
            id: StripeTestStubs.mock_id("ba"),
            object: "bank_account",
            fingerprint: StripeTestStubs.mock_id("fp")
          }],
          has_more: false,
          total_count: 1,
          url: "/v1/accounts/#{id}/external_accounts"
        },
        metadata: params[:metadata] || {},
        requirements: { "currently_due" => [], "past_due" => [], "eventually_due" => [] },
        business_profile: params[:business_profile] || {},
        individual: params[:individual] || {},
        created: StripeTestStubs.now_ts
      }
      store.accounts[id] = account

      person_id = StripeTestStubs.mock_id("person")
      store.persons[id] ||= {}
      store.persons[id][person_id] = {
        id: person_id,
        object: "person",
        account: id,
        first_name: params.dig(:individual, :first_name) || "Test",
        last_name: params.dig(:individual, :last_name) || "Person",
        relationship: {},
        verification: { status: "verified", document: { front: nil, back: nil, details: nil, details_code: nil } },
        metadata: {}
      }

      StripeTestStubs.construct(account)
    end

    allow(Stripe::Account).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      id ||= "acct_default"
      account = store.accounts[id] || {
        id: id,
        object: "account",
        country: "US",
        default_currency: "usd",
        charges_enabled: true,
        payouts_enabled: true,
        capabilities: { "card_payments" => "active", "transfers" => "active" },
        external_accounts: {
          object: "list",
          data: [{
            id: StripeTestStubs.mock_id("ba"),
            object: "bank_account",
            fingerprint: StripeTestStubs.mock_id("fp")
          }],
          has_more: false,
          total_count: 1,
          url: "/v1/accounts/#{id}/external_accounts"
        },
        metadata: {},
        requirements: { "currently_due" => [], "past_due" => [], "eventually_due" => [] },
        created: StripeTestStubs.now_ts
      }
      store.accounts[id] = account
      StripeTestStubs.construct(account)
    end

    allow(Stripe::Account).to receive(:update) do |id, params = {}, opts = {}|
      account = store.accounts[id] || { id: id, object: "account", country: "US", default_currency: "usd" }
      if params[:metadata]
        account[:metadata] = (account[:metadata] || {}).merge(params[:metadata])
      end
      account = account.merge(params.except(:metadata)).merge(metadata: account[:metadata] || {})
      account[:charges_enabled] = true
      account[:payouts_enabled] = true
      store.accounts[id] = account
      StripeTestStubs.construct(account)
    end

    allow(Stripe::Account).to receive(:delete) do |id, opts = {}|
      store.accounts.delete(id)
      StripeTestStubs.construct(deleted: true, id: id, object: "account")
    end

    allow(Stripe::Account).to receive(:retrieve_external_account) do |account_id, ea_id, opts = {}|
      StripeTestStubs.construct(
        id: ea_id,
        object: "bank_account",
        account: account_id,
        fingerprint: StripeTestStubs.mock_id("fp"),
        bank_name: "STRIPE TEST BANK",
        country: "US",
        currency: "usd",
        last4: "6789"
      )
    end

    allow(Stripe::Account).to receive(:update_capability) do |account_id, capability_id, params = {}, opts = {}|
      StripeTestStubs.construct(
        id: capability_id,
        object: "capability",
        account: account_id,
        requested: true,
        status: "active"
      )
    end
  end

  def install_charge_stubs!(store)
    allow(Stripe::Charge).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? (id_or_opts[:id] || id_or_opts["id"]) : id_or_opts
      id = id.to_s
      charge = store.charges[id] || {
        id: id,
        object: "charge",
        amount: 1000,
        amount_captured: 1000,
        currency: "usd",
        status: "succeeded",
        paid: true,
        captured: true,
        refunded: false,
        balance_transaction: StripeTestStubs.mock_id("txn"),
        payment_intent: nil,
        payment_method: StripeTestStubs.mock_id("pm"),
        outcome: {
          network_status: "approved_by_network",
          reason: nil,
          risk_level: "normal",
          risk_score: 10,
          seller_message: "Payment complete.",
          type: "authorized"
        },
        billing_details: {
          address: { city: nil, country: nil, line1: nil, line2: nil, postal_code: nil, state: nil },
          email: nil, name: nil, phone: nil
        },
        metadata: {},
        created: StripeTestStubs.now_ts,
        transfer: nil,
        transfer_data: nil,
        destination: nil,
        application_fee_amount: nil
      }
      store.charges[id] = charge
      StripeTestStubs.construct(charge)
    end

    allow(Stripe::Charge).to receive(:list) do |params = {}, opts = {}|
      charges = store.charges.values
      if params[:payment_intent]
        charges = charges.select { |c| c[:payment_intent] == params[:payment_intent] }
      end
      StripeTestStubs.construct(
        object: "list",
        data: charges.map { |c| StripeTestStubs.construct(c) },
        has_more: false,
        url: "/v1/charges"
      )
    end

    allow(Stripe::Charge).to receive(:update) do |id, params = {}, opts = {}|
      charge = store.charges[id] || { id: id, object: "charge" }
      charge = charge.merge(params)
      store.charges[id] = charge
      StripeTestStubs.construct(charge)
    end

    allow(Stripe::Charge).to receive(:capture) do |id, params = {}, opts = {}|
      charge = store.charges[id] || { id: id, object: "charge" }
      charge[:captured] = true
      charge[:status] = "succeeded"
      store.charges[id] = charge
      StripeTestStubs.construct(charge)
    end
  end

  def install_payment_intent_stubs!(store)
    allow(Stripe::PaymentIntent).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("pi")
      charge_id = StripeTestStubs.mock_id("ch")
      bt_id = StripeTestStubs.mock_id("txn")

      charge_data = {
        id: charge_id,
        object: "charge",
        amount: params[:amount] || 1000,
        amount_captured: params[:amount] || 1000,
        currency: params[:currency] || "usd",
        status: "succeeded",
        paid: true,
        captured: true,
        refunded: false,
        balance_transaction: bt_id,
        payment_intent: id,
        payment_method: params[:payment_method],
        outcome: {
          network_status: "approved_by_network",
          reason: nil,
          risk_level: "normal",
          risk_score: 10,
          seller_message: "Payment complete.",
          type: "authorized"
        },
        billing_details: {
          address: { city: nil, country: nil, line1: nil, line2: nil, postal_code: nil, state: nil },
          email: nil, name: nil, phone: nil
        },
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts,
        transfer: params[:transfer_data] ? StripeTestStubs.mock_id("tr") : nil,
        transfer_data: params[:transfer_data],
        destination: params.dig(:transfer_data, :destination),
        application_fee_amount: params[:application_fee_amount]
      }
      store.charges[charge_id] = charge_data

      store.balance_transactions[bt_id] = {
        id: bt_id,
        object: "balance_transaction",
        amount: params[:amount] || 1000,
        currency: params[:currency] || "usd",
        fee: 59,
        net: (params[:amount] || 1000) - 59,
        type: "charge",
        source: charge_id,
        created: StripeTestStubs.now_ts
      }

      pi = {
        id: id,
        object: "payment_intent",
        amount: params[:amount] || 1000,
        currency: params[:currency] || "usd",
        status: params[:confirm] == true ? "succeeded" : "requires_confirmation",
        client_secret: "#{id}_secret_#{SecureRandom.hex(12)}",
        payment_method: params[:payment_method],
        customer: params[:customer],
        latest_charge: charge_id,
        charges: { object: "list", data: [charge_data], has_more: false },
        metadata: params[:metadata] || {},
        transfer_data: params[:transfer_data],
        application_fee_amount: params[:application_fee_amount],
        created: StripeTestStubs.now_ts
      }
      store.payment_intents[id] = pi
      StripeTestStubs.construct(pi)
    end

    allow(Stripe::PaymentIntent).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? (id_or_opts[:id] || id_or_opts["id"]) : id_or_opts
      pi = store.payment_intents[id] || {
        id: id,
        object: "payment_intent",
        amount: 1000,
        currency: "usd",
        status: "succeeded",
        client_secret: "#{id}_secret_#{SecureRandom.hex(12)}",
        payment_method: StripeTestStubs.mock_id("pm"),
        latest_charge: StripeTestStubs.mock_id("ch"),
        charges: { object: "list", data: [], has_more: false },
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.payment_intents[id] = pi
      StripeTestStubs.construct(pi)
    end

    allow(Stripe::PaymentIntent).to receive(:update) do |id, params = {}, opts = {}|
      pi = store.payment_intents[id] || { id: id, object: "payment_intent" }
      pi = pi.merge(params)
      store.payment_intents[id] = pi
      StripeTestStubs.construct(pi)
    end

    allow(Stripe::PaymentIntent).to receive(:confirm) do |id, params = {}, opts = {}|
      pi = store.payment_intents[id] || { id: id, object: "payment_intent" }
      pi[:status] = "succeeded"
      store.payment_intents[id] = pi
      StripeTestStubs.construct(pi)
    end

    allow(Stripe::PaymentIntent).to receive(:cancel) do |id, params = {}, opts = {}|
      pi = store.payment_intents[id] || { id: id, object: "payment_intent" }
      pi[:status] = "canceled"
      store.payment_intents[id] = pi
      StripeTestStubs.construct(pi)
    end

    allow(Stripe::PaymentIntent).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.payment_intents.values.map { |pi| StripeTestStubs.construct(pi) },
        has_more: false,
        url: "/v1/payment_intents"
      )
    end
  end

  def install_setup_intent_stubs!(store)
    allow(Stripe::SetupIntent).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("seti")
      si = {
        id: id,
        object: "setup_intent",
        status: params[:confirm] == true ? "succeeded" : "requires_confirmation",
        client_secret: "#{id}_secret_#{SecureRandom.hex(12)}",
        payment_method: params[:payment_method],
        customer: params[:customer],
        usage: params[:usage] || "off_session",
        mandate: params[:mandate],
        payment_method_types: params[:payment_method_types] || ["card"],
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts
      }
      store.setup_intents[id] = si
      StripeTestStubs.construct(si)
    end

    allow(Stripe::SetupIntent).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? (id_or_opts[:id] || id_or_opts["id"]) : id_or_opts
      si = store.setup_intents[id] || {
        id: id,
        object: "setup_intent",
        status: "succeeded",
        payment_method: StripeTestStubs.mock_id("pm"),
        customer: StripeTestStubs.mock_id("cus"),
        usage: "off_session",
        mandate: nil,
        payment_method_types: ["card"],
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.setup_intents[id] = si
      StripeTestStubs.construct(si)
    end

    allow(Stripe::SetupIntent).to receive(:update) do |id, params = {}, opts = {}|
      si = store.setup_intents[id] || { id: id, object: "setup_intent" }
      si = si.merge(params)
      store.setup_intents[id] = si
      StripeTestStubs.construct(si)
    end

    allow(Stripe::SetupIntent).to receive(:confirm) do |id, params = {}, opts = {}|
      si = store.setup_intents[id] || { id: id, object: "setup_intent" }
      si[:status] = "succeeded"
      store.setup_intents[id] = si
      StripeTestStubs.construct(si)
    end

    allow(Stripe::SetupIntent).to receive(:cancel) do |id, params = {}, opts = {}|
      si = store.setup_intents[id] || { id: id, object: "setup_intent" }
      si[:status] = "canceled"
      store.setup_intents[id] = si
      StripeTestStubs.construct(si)
    end
  end

  def install_customer_stubs!(store)
    allow(Stripe::Customer).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("cus")
      customer = {
        id: id,
        object: "customer",
        email: params[:email],
        payment_method: params[:payment_method],
        default_source: nil,
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts
      }
      store.customers[id] = customer
      StripeTestStubs.construct(customer)
    end

    allow(Stripe::Customer).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      customer = store.customers[id] || {
        id: id,
        object: "customer",
        email: nil,
        default_source: nil,
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.customers[id] = customer
      StripeTestStubs.construct(customer)
    end

    allow(Stripe::Customer).to receive(:update) do |id, params = {}, opts = {}|
      customer = store.customers[id] || { id: id, object: "customer" }
      customer = customer.merge(params)
      store.customers[id] = customer
      StripeTestStubs.construct(customer)
    end

    allow(Stripe::Customer).to receive(:delete) do |id, opts = {}|
      store.customers.delete(id)
      StripeTestStubs.construct(deleted: true, id: id, object: "customer")
    end

    allow(Stripe::Customer).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.customers.values.map { |c| StripeTestStubs.construct(c) },
        has_more: false,
        url: "/v1/customers"
      )
    end
  end

  def install_payment_method_stubs!(store)
    allow(Stripe::PaymentMethod).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("pm")
      pm = {
        id: id,
        object: "payment_method",
        type: params[:type] || "card",
        card: {
          brand: "visa",
          last4: "4242",
          exp_month: 12,
          exp_year: Time.now.year + 2,
          fingerprint: StripeTestStubs.mock_id("fp"),
          country: "US",
          funding: "credit",
          wallet: nil
        },
        billing_details: params[:billing_details] || {
          address: { city: nil, country: nil, line1: nil, line2: nil, postal_code: nil, state: nil },
          email: nil, name: nil, phone: nil
        },
        customer: nil,
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts
      }
      store.payment_methods[id] = pm
      StripeTestStubs.construct(pm)
    end

    allow(Stripe::PaymentMethod).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      pm = store.payment_methods[id] || {
        id: id,
        object: "payment_method",
        type: "card",
        card: {
          brand: "visa",
          last4: "4242",
          exp_month: 12,
          exp_year: Time.now.year + 2,
          fingerprint: StripeTestStubs.mock_id("fp"),
          country: "US",
          funding: "credit",
          wallet: nil
        },
        billing_details: {
          address: { city: nil, country: nil, line1: nil, line2: nil, postal_code: nil, state: nil },
          email: nil, name: nil, phone: nil
        },
        customer: nil,
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.payment_methods[id] = pm
      StripeTestStubs.construct(pm)
    end

    allow(Stripe::PaymentMethod).to receive(:attach) do |id, params = {}, opts = {}|
      pm = store.payment_methods[id] || { id: id, object: "payment_method", type: "card" }
      pm[:customer] = params[:customer]
      store.payment_methods[id] = pm
      StripeTestStubs.construct(pm)
    end

    allow(Stripe::PaymentMethod).to receive(:detach) do |id, params = {}, opts = {}|
      pm = store.payment_methods[id] || { id: id, object: "payment_method", type: "card" }
      pm[:customer] = nil
      store.payment_methods[id] = pm
      StripeTestStubs.construct(pm)
    end

    allow(Stripe::PaymentMethod).to receive(:list) do |params = {}, opts = {}|
      methods = store.payment_methods.values
      if params[:customer]
        methods = methods.select { |pm| pm[:customer] == params[:customer] }
      end
      StripeTestStubs.construct(
        object: "list",
        data: methods.map { |pm| StripeTestStubs.construct(pm) },
        has_more: false,
        url: "/v1/payment_methods"
      )
    end
  end

  def install_refund_stubs!(store)
    allow(Stripe::Refund).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("re")
      refund = {
        id: id,
        object: "refund",
        amount: params[:amount] || 1000,
        charge: params[:charge],
        payment_intent: params[:payment_intent],
        currency: "usd",
        status: "succeeded",
        reason: params[:reason],
        balance_transaction: StripeTestStubs.mock_id("txn"),
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts
      }
      store.refunds[id] = refund
      StripeTestStubs.construct(refund)
    end

    allow(Stripe::Refund).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      refund = store.refunds[id] || {
        id: id,
        object: "refund",
        amount: 1000,
        currency: "usd",
        status: "succeeded",
        balance_transaction: StripeTestStubs.mock_id("txn"),
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.refunds[id] = refund
      StripeTestStubs.construct(refund)
    end

    allow(Stripe::Refund).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.refunds.values.map { |r| StripeTestStubs.construct(r) },
        has_more: false,
        url: "/v1/refunds"
      )
    end
  end

  def install_transfer_stubs!(store)
    allow(Stripe::Transfer).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("tr")
      transfer = {
        id: id,
        object: "transfer",
        amount: params[:amount] || 1000,
        currency: params[:currency] || "usd",
        destination: params[:destination],
        destination_payment: StripeTestStubs.mock_id("py"),
        balance_transaction: StripeTestStubs.mock_id("txn"),
        source_transaction: params[:source_transaction],
        metadata: params[:metadata] || {},
        reversals: { object: "list", data: [], has_more: false, total_count: 0 },
        reversed: false,
        created: StripeTestStubs.now_ts
      }
      store.transfers[id] = transfer
      StripeTestStubs.construct(transfer)
    end

    allow(Stripe::Transfer).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? (id_or_opts[:id] || id_or_opts["id"]) : id_or_opts
      id = id.to_s
      transfer = store.transfers[id] || {
        id: id,
        object: "transfer",
        amount: 1000,
        currency: "usd",
        destination: StripeTestStubs.mock_id("acct"),
        destination_payment: StripeTestStubs.mock_id("py"),
        balance_transaction: StripeTestStubs.mock_id("txn"),
        metadata: {},
        reversals: { object: "list", data: [], has_more: false, total_count: 0 },
        reversed: false,
        created: StripeTestStubs.now_ts
      }
      store.transfers[id] = transfer
      StripeTestStubs.construct(transfer)
    end

    allow(Stripe::Transfer).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.transfers.values.map { |t| StripeTestStubs.construct(t) },
        has_more: false,
        url: "/v1/transfers"
      )
    end

    allow(Stripe::Transfer).to receive(:create_reversal) do |transfer_id, params = {}, opts = {}|
      id = StripeTestStubs.mock_id("trr")
      transfer = store.transfers[transfer_id]
      if transfer
        transfer[:reversed] = true
      end
      StripeTestStubs.construct(
        id: id,
        object: "transfer_reversal",
        amount: params[:amount] || transfer&.dig(:amount) || 1000,
        transfer: transfer_id,
        currency: "usd",
        balance_transaction: StripeTestStubs.mock_id("txn"),
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts
      )
    end
  end

  def install_payout_stubs!(store)
    allow(Stripe::Payout).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("po")
      payout = {
        id: id,
        object: "payout",
        amount: params[:amount] || 1000,
        currency: params[:currency] || "usd",
        status: "paid",
        arrival_date: (Time.now + 2.days).to_i,
        method: params[:method] || "standard",
        type: "bank_account",
        balance_transaction: StripeTestStubs.mock_id("txn"),
        destination: StripeTestStubs.mock_id("ba"),
        metadata: params[:metadata] || {},
        created: StripeTestStubs.now_ts
      }
      store.payouts[id] = payout
      StripeTestStubs.construct(payout)
    end

    allow(Stripe::Payout).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      id = id.to_s
      payout = store.payouts[id] || {
        id: id,
        object: "payout",
        amount: 1000,
        currency: "usd",
        status: "paid",
        arrival_date: (Time.now + 2.days).to_i,
        method: "standard",
        type: "bank_account",
        balance_transaction: StripeTestStubs.mock_id("txn"),
        destination: StripeTestStubs.mock_id("ba"),
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.payouts[id] = payout
      StripeTestStubs.construct(payout)
    end

    allow(Stripe::Payout).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.payouts.values.map { |p| StripeTestStubs.construct(p) },
        has_more: false,
        url: "/v1/payouts"
      )
    end
  end

  def install_balance_stubs!(store)
    allow(Stripe::Balance).to receive(:retrieve) do |opts = {}|
      StripeTestStubs.construct(
        object: "balance",
        available: [{ amount: 1_000_000_00, currency: "usd", source_types: { card: 1_000_000_00 } }],
        pending: [{ amount: 0, currency: "usd", source_types: { card: 0 } }],
        livemode: false
      )
    end
  end

  def install_balance_transaction_stubs!(store)
    allow(Stripe::BalanceTransaction).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      bt = store.balance_transactions[id] || {
        id: id,
        object: "balance_transaction",
        amount: 1000,
        currency: "usd",
        fee: 59,
        fee_details: [
          { amount: 29, currency: "usd", description: "Stripe processing fees", type: "stripe_fee" },
          { amount: 30, currency: "usd", description: "application fee", type: "application_fee" }
        ],
        net: 941,
        type: "charge",
        source: StripeTestStubs.mock_id("ch"),
        created: StripeTestStubs.now_ts
      }
      store.balance_transactions[id] = bt
      StripeTestStubs.construct(bt)
    end

    allow(Stripe::BalanceTransaction).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.balance_transactions.values.map { |bt| StripeTestStubs.construct(bt) },
        has_more: false,
        url: "/v1/balance_transactions"
      )
    end
  end

  def install_dispute_stubs!(store)
    allow(Stripe::Dispute).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      dispute = store.disputes[id] || {
        id: id,
        object: "dispute",
        amount: 1000,
        currency: "usd",
        charge: StripeTestStubs.mock_id("ch"),
        payment_intent: nil,
        status: "needs_response",
        reason: "fraudulent",
        evidence: {},
        evidence_details: { due_by: (Time.now + 7.days).to_i, has_evidence: false, past_due: false, submission_count: 0 },
        metadata: {},
        created: StripeTestStubs.now_ts
      }
      store.disputes[id] = dispute
      StripeTestStubs.construct(dispute)
    end

    allow(Stripe::Dispute).to receive(:update) do |id, params = {}, opts = {}|
      dispute = store.disputes[id] || { id: id, object: "dispute", status: "needs_response" }
      dispute = dispute.merge(params)
      store.disputes[id] = dispute
      StripeTestStubs.construct(dispute)
    end

    allow(Stripe::Dispute).to receive(:list) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "list",
        data: store.disputes.values.map { |d| StripeTestStubs.construct(d) },
        has_more: false,
        url: "/v1/disputes"
      )
    end

    allow(Stripe::Dispute).to receive(:close) do |id, params = {}, opts = {}|
      dispute = store.disputes[id] || { id: id, object: "dispute" }
      dispute[:status] = "lost"
      store.disputes[id] = dispute
      StripeTestStubs.construct(dispute)
    end
  end

  def install_token_stubs!(store)
    allow(Stripe::Token).to receive(:create) do |params = {}, opts = {}|
      id = StripeTestStubs.mock_id("tok")
      token = {
        id: id,
        object: "token",
        type: "card",
        card: {
          id: StripeTestStubs.mock_id("card"),
          brand: "visa",
          last4: "4242",
          exp_month: 12,
          exp_year: Time.now.year + 2,
          fingerprint: StripeTestStubs.mock_id("fp")
        },
        used: false,
        created: StripeTestStubs.now_ts
      }
      store.tokens[id] = token
      StripeTestStubs.construct(token)
    end

    allow(Stripe::Token).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      token = store.tokens[id] || {
        id: id,
        object: "token",
        type: "card",
        card: {
          id: StripeTestStubs.mock_id("card"),
          brand: "visa",
          last4: "4242",
          exp_month: 12,
          exp_year: Time.now.year + 2,
          fingerprint: StripeTestStubs.mock_id("fp")
        },
        used: false,
        created: StripeTestStubs.now_ts
      }
      store.tokens[id] = token
      StripeTestStubs.construct(token)
    end
  end

  def install_account_link_stubs!(store)
    allow(Stripe::AccountLink).to receive(:create) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "account_link",
        url: params[:return_url] || "https://example.com/mock-onboarding",
        expires_at: StripeTestStubs.now_ts + 300,
        created: StripeTestStubs.now_ts
      )
    end
  end

  def install_account_session_stubs!(store)
    allow(Stripe::AccountSession).to receive(:create) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        object: "account_session",
        account: params[:account] || StripeTestStubs.mock_id("acct"),
        client_secret: "acss_secret_#{SecureRandom.hex(16)}",
        expires_at: StripeTestStubs.now_ts + 3600,
        livemode: false
      )
    end
  end

  def install_person_stubs!(store)
    allow(Stripe::Account).to receive(:create_person) do |account_id, params = {}, opts = {}|
      id = StripeTestStubs.mock_id("person")
      store.persons[account_id] ||= {}
      person = {
        id: id,
        object: "person",
        account: account_id,
        first_name: params[:first_name] || "Test",
        last_name: params[:last_name] || "Person",
        relationship: params[:relationship] || {},
        verification: { status: "verified", document: { front: nil, back: nil, details: nil, details_code: nil } },
        metadata: params[:metadata] || {}
      }
      store.persons[account_id][id] = person
      StripeTestStubs.construct(person)
    end

    allow(Stripe::Account).to receive(:list_persons) do |account_id, params = {}, opts = {}|
      persons = (store.persons[account_id] || {}).values
      {
        "data" => persons.map { |p| StripeTestStubs.construct(p) },
        "object" => "list",
        "has_more" => false,
        "url" => "/v1/accounts/#{account_id}/persons"
      }
    end

    allow(Stripe::Account).to receive(:update_person) do |account_id, person_id, params = {}, opts = {}|
      store.persons[account_id] ||= {}
      existing = store.persons[account_id][person_id] || { id: person_id, object: "person", account: account_id }
      updated = existing.merge(params)
      store.persons[account_id][person_id] = updated
      StripeTestStubs.construct(updated)
    end
  end

  def install_apple_pay_domain_stubs!(store)
    allow(Stripe::ApplePayDomain).to receive(:create) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        id: StripeTestStubs.mock_id("apd"),
        object: "apple_pay_domain",
        domain_name: params[:domain_name] || "example.com",
        livemode: false,
        created: StripeTestStubs.now_ts
      )
    end

    allow(Stripe::ApplePayDomain).to receive(:delete) do |id, opts = {}|
      StripeTestStubs.construct(deleted: true, id: id, object: "apple_pay_domain")
    end
  end

  def install_mandate_stubs!(store)
    allow(Stripe::Mandate).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      StripeTestStubs.construct(
        id: id,
        object: "mandate",
        status: "active",
        type: "multi_use",
        payment_method: StripeTestStubs.mock_id("pm"),
        customer_acceptance: {
          type: "online",
          accepted_at: StripeTestStubs.now_ts,
          online: { ip_address: "127.0.0.1", user_agent: "Test" }
        }
      )
    end
  end

  def install_early_fraud_warning_stubs!(store)
    allow(Stripe::Radar::EarlyFraudWarning).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      StripeTestStubs.construct(
        id: id,
        object: "radar.early_fraud_warning",
        charge: StripeTestStubs.mock_id("ch"),
        fraud_type: "unauthorized_use_of_card",
        actionable: true,
        livemode: false,
        created: StripeTestStubs.now_ts
      )
    end
  end

  def install_application_fee_stubs!(store)
    allow(Stripe::ApplicationFee).to receive(:retrieve) do |id_or_opts = nil, opts = {}|
      id = id_or_opts.is_a?(Hash) ? id_or_opts[:id] : id_or_opts
      StripeTestStubs.construct(
        id: id,
        object: "application_fee",
        amount: 100,
        currency: "usd",
        charge: StripeTestStubs.mock_id("ch"),
        balance_transaction: StripeTestStubs.mock_id("txn"),
        refunded: false,
        refunds: { object: "list", data: [], has_more: false, total_count: 0 },
        created: StripeTestStubs.now_ts
      )
    end
  end

  def install_file_stubs!(store)
    allow(Stripe::File).to receive(:create) do |params = {}, opts = {}|
      StripeTestStubs.construct(
        id: StripeTestStubs.mock_id("file"),
        object: "file",
        purpose: params[:purpose] || "dispute_evidence",
        size: 1024,
        type: "png",
        created: StripeTestStubs.now_ts
      )
    end
  end
end

RSpec.configure do |config|
  config.before(:each) do
    @_stripe_test_store = StripeTestStubs::Store.new
    StripeTestStubs.install!(@_stripe_test_store)
  end
end
