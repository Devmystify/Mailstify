require "rails_helper"

# Demonstrates the multi-tenancy leak in SubscribersController#index.
#
# Every other subscriber action scopes through the current user's lists, but
# #index uses `Subscriber.all`, so a signed-in user can see every other user's
# subscribers. This spec signs in as Alice and asserts she never sees Bob's.
RSpec.describe "Subscribers index tenant isolation", type: :request do
  it "does not expose another user's subscribers" do
    alice = User.create!(email_address: "alice@example.com", password: "password")
    bob   = User.create!(email_address: "bob@example.com", password: "password")

    alice.lists.create!(name: "Alice's list")
      .subscribers.create!(email: "alice-customer@example.com", name: "Alice Customer")

    bob.lists.create!(name: "Bob's list")
      .subscribers.create!(email: "bob-secret@example.com", name: "Bob Secret")

    sign_in_as alice

    get subscribers_url

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("alice-customer@example.com"),
      "Alice should see her own subscribers"
    expect(response.body).not_to include("bob-secret@example.com"),
      "Alice must not see Bob's subscribers, but #index leaks them via Subscriber.all"
    expect(response.body).not_to include("Bob Secret"),
      "Alice must not see Bob's subscriber names either"
  end

  def sign_in_as(user, password: "password")
    post session_url, params: { email_address: user.email_address, password: password }
  end
end
