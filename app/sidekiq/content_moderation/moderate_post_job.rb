# frozen_string_literal: true

class ContentModeration::ModeratePostJob
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 3

  def perform(post_id)
    post = Installment.find(post_id)
    ContentModeration::ModerateRecordService.new(post, :post).perform
  end
end
