ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do |_worker|
      Rails.application.reload_routes!
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

class FakeStructuredLlmClient
  Response = Data.define(:content)

  attr_reader :prompts, :schemas

  def initialize(payload)
    @payload = payload
    @prompts = []
    @schemas = []
  end

  def available?
    true
  end

  def with_chat(schema: nil)
    @schemas << schema
    yield Chat.new(self)
  end

  def record_prompt(prompt)
    @prompts << prompt
    Response.new(content: @payload)
  end

  class Chat
    def initialize(client)
      @client = client
    end

    def ask(prompt)
      @client.record_prompt(prompt)
    end
  end
end
