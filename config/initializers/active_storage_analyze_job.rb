# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActiveStorage::AnalyzeJob.discard_on(ActiveStorage::FileNotFoundError)
end
