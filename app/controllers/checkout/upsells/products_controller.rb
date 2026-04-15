# frozen_string_literal: true

class Checkout::Upsells::ProductsController < ApplicationController
  include CustomDomainConfig

  MAX_PRODUCTS = 25

  QUERY_TIMEOUT_MS = 10_000

  PRODUCT_INCLUDES = [
    :skus_alive_not_default,
    :variant_categories_alive,
    :product_review_stat,
    { alive_variants: { variant_category: :link },
      thumbnail_alive: { file_attachment: :blob },
      display_asset_previews: { file_attachment: :blob } },
  ].freeze

  def index
    seller = user_by_domain(request.host) || current_seller
    return render json: [] unless seller

    products = with_query_timeout do
      seller.products
        .eligible_for_content_upsells
        .includes(*PRODUCT_INCLUDES)
        .order(created_at: :desc, id: :desc)
        .limit(MAX_PRODUCTS)
        .to_a
    end
    render json: products.map { |product| Checkout::Upsells::ProductPresenter.new(product).product_props }
  end

  def show
    product = with_query_timeout do
      Link.eligible_for_content_upsells
          .includes(*PRODUCT_INCLUDES)
          .find_by_external_id!(params[:id])
    end

    render json: Checkout::Upsells::ProductPresenter.new(product).product_props
  end

  private

  def with_query_timeout
    previous_timeout = ActiveRecord::Base.connection.execute("SELECT @@SESSION.max_execution_time AS t").first.first
    ActiveRecord::Base.connection.execute("SET SESSION max_execution_time = #{QUERY_TIMEOUT_MS}")
    yield
  ensure
    ActiveRecord::Base.connection.execute("SET SESSION max_execution_time = #{previous_timeout || 0}")
  end
end
