# frozen_string_literal: true

class ContentModeration::ModerateProfileJob
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 3

  def perform(user_id)
    user = User.find(user_id)
    ContentModeration::ModerateRecordService.new(user, :profile).perform
  end
end
