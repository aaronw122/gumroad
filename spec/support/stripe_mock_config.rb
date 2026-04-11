# frozen_string_literal: true

return if LIVE_STRIPE

module StripeMockAccountDefaults
  def mock_account(params = {})
    super(params).merge(
      charges_enabled: true,
      payouts_enabled: true,
      external_accounts: {
        object: "list",
        data: [
          {
            id: "ba_mock_#{SecureRandom.hex(8)}",
            object: "bank_account",
            fingerprint: "fp_mock_#{SecureRandom.hex(8)}"
          }
        ],
        has_more: false,
        total_count: 1,
        url: "/v1/accounts/#{params[:id] || 'acct_default'}/external_accounts"
      }
    )
  end
end

StripeMock::Data.singleton_class.prepend(StripeMockAccountDefaults)

module StripeMockPersonsHandler
  def create_person(route, method_url, params, headers)
    route =~ method_url
    account_id = $1
    person_id = params[:id] || new_id("person")
    persons_store[account_id] ||= {}
    persons_store[account_id][person_id] = mock_person(person_id, account_id, params)
  end

  def retrieve_person(route, method_url, params, headers)
    route =~ method_url
    account_id = $1
    person_id = $2
    persons_store.dig(account_id, person_id) || mock_person(person_id, account_id)
  end

  def update_person(route, method_url, params, headers)
    route =~ method_url
    account_id = $1
    person_id = $2
    persons_store[account_id] ||= {}
    existing = persons_store[account_id][person_id] || mock_person(person_id, account_id)
    persons_store[account_id][person_id] = existing.merge(params)
  end

  def list_persons(route, method_url, params, headers)
    route =~ method_url
    account_id = $1
    persons = (persons_store[account_id] || {}).values
    {
      object: "list",
      data: persons,
      has_more: false,
      url: "/v1/accounts/#{account_id}/persons"
    }
  end

  def delete_person(route, method_url, params, headers)
    route =~ method_url
    account_id = $1
    person_id = $2
    persons_store[account_id]&.delete(person_id)
    { id: person_id, object: "person", deleted: true }
  end

  private

  def persons_store
    @persons_store ||= {}
  end

  def mock_person(person_id, account_id, params = {})
    {
      id: person_id,
      object: "person",
      account: account_id,
      first_name: params[:first_name] || "Test",
      last_name: params[:last_name] || "Person",
      relationship: params[:relationship] || {},
      verification: {
        status: "verified",
        document: { front: nil, back: nil, details: nil, details_code: nil }
      },
      metadata: params[:metadata] || {}
    }
  end
end

StripeMock::Instance.include(StripeMockPersonsHandler)

persons_routes = [
  { route: %r{^post /v1/accounts/(.*)/persons$}, name: :create_person },
  { route: %r{^get /v1/accounts/(.*)/persons/(.*)$}, name: :retrieve_person },
  { route: %r{^post /v1/accounts/(.*)/persons/(.*)$}, name: :update_person },
  { route: %r{^get /v1/accounts/(.*)/persons$}, name: :list_persons },
  { route: %r{^delete /v1/accounts/(.*)/persons/(.*)$}, name: :delete_person }
]

StripeMock::Instance.class_variable_get(:@@handlers).unshift(*persons_routes)
