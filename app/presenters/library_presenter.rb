# frozen_string_literal: true

class LibraryPresenter
  include Rails.application.routes.url_helpers

  PER_PAGE = 100

  attr_reader :logged_in_user

  def initialize(logged_in_user)
    @logged_in_user = logged_in_user
  end

  def library_cards(cursor: nil)
    scope = base_scope
    scope = scope.where("purchases.id < ?", cursor) if cursor.present?

    raw_purchases = scope
      .order(id: :desc)
      .limit(PER_PAGE + 1)
      .to_a

    has_more = raw_purchases.size > PER_PAGE
    raw_purchases = raw_purchases.first(PER_PAGE) if has_more
    next_cursor = raw_purchases.last&.id if has_more

    creators_infos = raw_purchases.flat_map { |purchase| purchase.link.user }.uniq.group_by(&:id).transform_values(&:first)
    creators = creators_infos.values.map do |creator|
      { id: creator.external_id, name: creator.name || creator.username || creator.external_id }
    end
    bundles = raw_purchases.filter_map do |purchase|
      { id: purchase.link.external_id, label: purchase.link.name } if purchase.is_bundle_purchase?
    end.uniq { _1[:id] }
    product_seller_data = {}

    purchases = raw_purchases.map do |purchase|
      next if purchase.link.is_recurring_billing && !purchase.subscription.grant_access_to_product?

      product = purchase.link
      product_seller_data[product.user.id] ||= product.user.username && {
        name: product.user.name || product.user.username,
        profile_url: product.user.profile_url(recommended_by: "library"),
        avatar_url: product.user.avatar_url
      }
      {
        product: {
          name: product.name,
          creator_id: product.user.external_id,
          creator: product_seller_data[product.user.id],
          thumbnail_url: product.thumbnail_or_cover_url(style: :original),
          native_type: product.native_type,
          updated_at: product.content_updated_at || product.created_at,
          permalink: product.unique_permalink,
          has_third_party_analytics: product.has_third_party_analytics?("receipt"),
        },
        purchase: {
          id: purchase.external_id,
          email: purchase.email,
          is_archived: purchase.is_archived,
          download_url: purchase.url_redirect&.download_page_url,
          variants: purchase.variant_attributes&.map(&:name)&.join(", "),
          bundle_id: purchase.bundle_purchase&.link&.external_id,
          is_bundle_purchase: purchase.is_bundle_purchase?,
        }
      }
    end.compact
    return purchases, creators, bundles, next_cursor
  end

  private

  def base_scope
    logged_in_user.purchases
      .for_library
      .not_rental_expired
      .not_is_deleted_by_buyer
      .includes(
        :subscription,
        :url_redirect,
        :variant_attributes,
        :bundle_purchase,
        link: {
          display_asset_previews: { file_attachment: :blob },
          thumbnail_alive: { file_attachment: :blob },
          user: { avatar_attachment: :blob }
        }
      )
  end
end
