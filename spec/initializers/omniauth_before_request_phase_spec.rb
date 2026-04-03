# frozen_string_literal: true

require "spec_helper"

describe "OmniAuth before_request_phase" do
  it "prunes expendable session keys before OAuth request" do
    handler = OmniAuth.config.before_request_phase
    expect(handler).to be_a(Proc)

    session = {
      "invoice_file_url_abc123" => "https://s3.example.com/presigned-url",
      "invoice_file_url_def456" => "https://s3.example.com/another-url",
      "signup_referrer" => "partner.example.com",
      "recommender_model_name" => "model_v2",
      "warden.user.user.key" => [[1], "secret"],
      "verify_two_factor_auth_for" => 42,
    }
    env = { Rack::RACK_SESSION => session }

    handler.call(env)

    expect(session.key?("invoice_file_url_abc123")).to eq(false)
    expect(session.key?("invoice_file_url_def456")).to eq(false)
    expect(session.key?("signup_referrer")).to eq(false)
    expect(session.key?("recommender_model_name")).to eq(false)
    expect(session["warden.user.user.key"]).to eq([[1], "secret"])
    expect(session["verify_two_factor_auth_for"]).to eq(42)
  end
end
