# frozen_string_literal: true

class SessionOverflowHandler
  EXPENDABLE_SESSION_KEY_PATTERNS = [
    /\Ainvoice_file_url_/,
  ].freeze

  EXPENDABLE_SESSION_KEYS = %w[
    signup_referrer
    recommender_model_name
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue ActionDispatch::Cookies::CookieOverflow
    prune_session(env)
    @app.call(env)
  end

  private
    def prune_session(env)
      session = env[Rack::RACK_SESSION]
      return unless session

      session.to_hash.each_key do |key|
        key_s = key.to_s
        if EXPENDABLE_SESSION_KEYS.include?(key_s) || EXPENDABLE_SESSION_KEY_PATTERNS.any? { |p| p.match?(key_s) }
          session.delete(key)
        end
      end
    end
end
