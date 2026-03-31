# frozen_string_literal: true

class AddProductAndSellerNamesToPurchaseMapping < ActiveRecord::Migration[6.1]
  def up
    concrete_index = resolve_concrete_index(Purchase.index_name)

    EsClient.indices.close(index: concrete_index)
    EsClient.indices.put_settings(
      index: concrete_index,
      body: {
        settings: {
          index: {
            analysis: {
              filter: {
                full_autocomplete_filter: {
                  type: "edge_ngram",
                  min_gram: 1,
                  max_gram: 20
                }
              },
              analyzer: {
                product_name: {
                  tokenizer: "whitespace",
                  filter: ["lowercase", "full_autocomplete_filter"]
                },
                search_product_name: {
                  tokenizer: "whitespace",
                  filter: "lowercase"
                }
              }
            }
          }
        }
      }
    )
    EsClient.indices.open(index: concrete_index)

    EsClient.indices.put_mapping(
      index: Purchase.index_name,
      body: {
        properties: {
          seller: {
            type: :nested,
            properties: {
              name: { type: :text, analyzer: :full_name, search_analyzer: :search_full_name }
            }
          },
          product: {
            type: :nested,
            properties: {
              name: { type: :text, analyzer: :product_name, search_analyzer: :search_product_name },
              description: { type: :text }
            }
          }
        }
      }
    )
  end

  private
    def resolve_concrete_index(name)
      aliases = EsClient.indices.get_alias(name: name)
      aliases.keys.first
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      name
    end
end
