# frozen_string_literal: true

OmniAuth.config.full_host = "#{PROTOCOL}://#{DOMAIN}"

OmniAuth.config.before_request_phase = lambda { |env|
  session = env[Rack::RACK_SESSION]
  if session
    session.to_hash.each_key do |key|
      session.delete(key) if key.to_s.start_with?("invoice_file_url_")
    end
    session.delete("signup_referrer")
    session.delete("recommender_model_name")
  end
}
