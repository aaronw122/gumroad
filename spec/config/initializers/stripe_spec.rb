# frozen_string_literal: true

require "spec_helper"

describe "Stripe configuration" do
  it "sets network timeouts to prevent Rack::Timeout in payment flows" do
    expect(Stripe.open_timeout).to eq(5)
    expect(Stripe.read_timeout).to eq(25)
  end

  it "limits network retries" do
    expect(Stripe.max_network_retries).to eq(3)
  end
end
