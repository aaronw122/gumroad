# frozen_string_literal: true

require "spec_helper"

describe ActiveStorage::AnalyzeJob do
  it "discards the job when ActiveStorage::FileNotFoundError is raised" do
    rescue_handlers = described_class.rescue_handlers.map(&:first)
    expect(rescue_handlers).to include("ActiveStorage::FileNotFoundError")
  end
end
