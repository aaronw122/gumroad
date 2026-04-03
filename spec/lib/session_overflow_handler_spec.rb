# frozen_string_literal: true

require "spec_helper"

describe SessionOverflowHandler do
  let(:overflow_raised) { Concurrent::AtomicBoolean.new(false) }
  let(:inner_app) do
    raised = overflow_raised
    lambda do |env|
      if !raised.true?
        raised.make_true
        raise ActionDispatch::Cookies::CookieOverflow
      end
      [200, { "Content-Type" => "text/plain" }, ["OK"]]
    end
  end
  let(:middleware) { described_class.new(inner_app) }

  def build_env(session_data = {})
    env = Rack::MockRequest.env_for("/")
    env[Rack::RACK_SESSION] = session_data.with_indifferent_access
    env
  end

  describe "#call" do
    context "when no CookieOverflow occurs" do
      let(:inner_app) { ->(_env) { [200, {}, ["OK"]] } }

      it "passes through normally" do
        env = build_env
        status, _headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body).to eq(["OK"])
      end
    end

    context "when CookieOverflow occurs" do
      it "prunes expendable session keys and retries" do
        env = build_env(
          "invoice_file_url_abc123" => "https://s3.example.com/long-presigned-url",
          "invoice_file_url_def456" => "https://s3.example.com/another-presigned-url",
          "signup_referrer" => "partner.example.com",
          "recommender_model_name" => "model_v2",
          "warden.user.user.key" => [[1], "secret"]
        )

        status, _headers, body = middleware.call(env)
        session = env[Rack::RACK_SESSION]

        expect(status).to eq(200)
        expect(body).to eq(["OK"])
        expect(session.key?("invoice_file_url_abc123")).to eq(false)
        expect(session.key?("invoice_file_url_def456")).to eq(false)
        expect(session.key?("signup_referrer")).to eq(false)
        expect(session.key?("recommender_model_name")).to eq(false)
        expect(session["warden.user.user.key"]).to eq([[1], "secret"])
      end
    end

    context "when CookieOverflow persists after pruning" do
      let(:inner_app) { ->(_env) { raise ActionDispatch::Cookies::CookieOverflow } }

      it "raises the error" do
        env = build_env("signup_referrer" => "test")

        expect { middleware.call(env) }.to raise_error(ActionDispatch::Cookies::CookieOverflow)
      end
    end
  end
end
