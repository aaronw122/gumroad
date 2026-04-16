# frozen_string_literal: true

class ContentModeration::ModerateProductJob
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 3

  def perform(product_id)
    product = Link.find(product_id)
    ContentModeration::ModerateRecordService.new(product, :product).perform
  end
end
