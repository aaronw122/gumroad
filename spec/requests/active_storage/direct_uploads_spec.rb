# frozen_string_literal: true

require "spec_helper"

describe "ActiveStorage::DirectUploadsController" do
  describe "POST /rails/active_storage/direct_uploads" do
    it "returns 422 when checksum is blank" do
      post rails_direct_uploads_url, params: {
        blob: {
          filename: "test.png",
          byte_size: 1024,
          checksum: "",
          content_type: "image/png"
        }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("Checksum")
    end

    it "returns 422 when checksum is missing" do
      post rails_direct_uploads_url, params: {
        blob: {
          filename: "test.png",
          byte_size: 1024,
          content_type: "image/png"
        }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
