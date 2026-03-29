json.extract! account, :id, :name, :description, :email, :user_id, :active, :created_at, :updated_at
json.url account_url(account, format: :json)
