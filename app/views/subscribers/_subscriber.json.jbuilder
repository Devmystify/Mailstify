json.extract! subscriber, :id, :email, :name, :list_id, :created_at, :updated_at
json.url subscriber_url(subscriber, format: :json)
