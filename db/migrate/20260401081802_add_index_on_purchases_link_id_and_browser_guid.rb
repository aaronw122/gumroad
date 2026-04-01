# frozen_string_literal: true

class AddIndexOnPurchasesLinkIdAndBrowserGuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :purchases, [:link_id, :browser_guid],
              name: "index_purchases_on_link_id_and_browser_guid"
  end
end
