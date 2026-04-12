# frozen_string_literal: true

class UserPresenter
  include Rails.application.routes.url_helpers

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def audience_count = user.audience_members.count

  def audience_types
    result = []
    result << :customers if user.audience_members.where(customer: true).exists?
    result << :followers if user.audience_members.where(follower: true).exists?
    result << :affiliates if user.audience_members.where(affiliate: true).exists?
    result
  end

  def products_for_filter_box
    products = user.links.visible.includes(:alive_variants)
    reject_archived_without_sales(products)
  end

  def affiliate_products_for_filter_box
    products = user.links.visible.order("created_at DESC")
    reject_archived_without_sales(products)
  end

  def as_current_seller
    time_zone = ActiveSupport::TimeZone[user.timezone]
    {
      id: user.external_id,
      email: user.email,
      name: user.display_name(prefer_email_over_default_username: true),
      subdomain: user.subdomain,
      avatar_url: user.avatar_url,
      is_buyer: user.is_buyer?,
      time_zone: { name: time_zone.tzinfo.name, offset: time_zone.tzinfo.utc_offset },
      has_published_products: user.products.alive.exists?,
      is_name_invalid_for_email_delivery: user.is_name_invalid_for_email_delivery?,
      profile_background_color: user.seller_profile.background_color,
      profile_highlight_color: user.seller_profile.highlight_color,
      profile_font: user.seller_profile.font,
    }
  end

  def author_byline_props(custom_domain_url: nil, recommended_by: nil)
    return if user.username.blank?

    {
      id: user.external_id,
      name: user.name_or_username,
      avatar_url: user.avatar_url,
      profile_url: user.profile_url(custom_domain_url:, recommended_by:),
      is_verified: !!user.verified,
    }
  end

  private
    def reject_archived_without_sales(products)
      archived_products = products.select(&:archived?)
      return products.to_a if archived_products.empty?

      archived_with_sales = archived_product_ids_with_sales(archived_products)
      products.reject do |product|
        product.archived? && !archived_with_sales.include?(product.id)
      end
    end

    def archived_product_ids_with_sales(archived_products)
      return Set.new if archived_products.empty?

      search_options = Purchase::ACTIVE_SALES_SEARCH_OPTIONS.merge(
        product: archived_products,
        size: 0,
        aggs: { product_ids: { terms: { field: "product_id", size: archived_products.size } } },
      )
      result = PurchaseSearchService.search(search_options)
      Set.new(result.aggregations.product_ids.buckets.map { |b| b["key"] })
    end
end
