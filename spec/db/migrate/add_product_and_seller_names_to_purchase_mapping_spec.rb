# frozen_string_literal: true

require "spec_helper"

require_relative "../../../db/migrate/20210920213746_add_product_and_seller_names_to_purchase_mapping"

describe AddProductAndSellerNamesToPurchaseMapping do
  subject(:migration) { described_class.new }

  describe "#resolve_concrete_index" do
    context "when the index name is an alias" do
      it "resolves to the concrete index name" do
        allow(EsClient.indices).to receive(:get_alias)
          .with(name: "purchases")
          .and_return({ "purchases_v1" => { "aliases" => { "purchases" => {} } } })

        result = migration.send(:resolve_concrete_index, "purchases")

        expect(result).to eq("purchases_v1")
      end
    end

    context "when the index name is not an alias" do
      it "returns the original index name" do
        allow(EsClient.indices).to receive(:get_alias)
          .with(name: "purchases")
          .and_raise(Elasticsearch::Transport::Transport::Errors::NotFound)

        result = migration.send(:resolve_concrete_index, "purchases")

        expect(result).to eq("purchases")
      end
    end
  end

  describe "#up" do
    let(:concrete_index) { "purchases_v1" }

    before do
      allow(migration).to receive(:resolve_concrete_index)
        .with(Purchase.index_name)
        .and_return(concrete_index)
      allow(EsClient.indices).to receive(:close)
      allow(EsClient.indices).to receive(:put_settings)
      allow(EsClient.indices).to receive(:open)
      allow(EsClient.indices).to receive(:put_mapping)
    end

    it "uses the concrete index for close, put_settings, and open operations" do
      migration.up

      expect(EsClient.indices).to have_received(:close).with(index: concrete_index)
      expect(EsClient.indices).to have_received(:put_settings).with(hash_including(index: concrete_index))
      expect(EsClient.indices).to have_received(:open).with(index: concrete_index)
    end

    it "uses the alias for put_mapping" do
      migration.up

      expect(EsClient.indices).to have_received(:put_mapping).with(hash_including(index: Purchase.index_name))
    end
  end
end
