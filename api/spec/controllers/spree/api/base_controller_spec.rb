require 'spec_helper'

class FakesController < Spree::Api::BaseController
end

describe Spree::Api::BaseController do
  render_views
  controller(Spree::Api::BaseController) do
    def index
      render :text => { "products" => [] }.to_json
    end
  end

  context "signed in as a user using an authentication extension" do
    before do
      user = double(:email => "spree@example.com")
      user.stub_chain :spree_roles, pluck: []
      controller.stub :try_spree_current_user => user
    end

    it "can make a request" do
      api_get :index
      json_response.should == { "products" => [] }
      response.status.should == 200
    end
  end

  context "when validating based on an order token" do
    let!(:order) { create :order }

    context "with a correct order token" do
      it "succeeds" do
        api_get :index, order_token: order.guest_token, order_id: order.number
        response.status.should == 200
      end

      it "succeeds with an order_number parameter" do
        api_get :index, order_token: order.guest_token, order_number: order.number
        response.status.should == 200
      end
    end

    context "with an incorrect order token" do
      it "returns unauthorized" do
        api_get :index, order_token: "NOT_A_TOKEN", order_id: order.number
        response.status.should == 401
      end
    end
  end

  context "cannot make a request to the API" do
    it "without an API key" do
      api_get :index
      json_response.should == { "error" => "You must specify an API key." }
      response.status.should == 401
    end

    it "with an invalid API key" do
      request.headers["X-Spree-Token"] = "fake_key"
      get :index, {}
      json_response.should == { "error" => "Invalid API key (fake_key) specified." }
      response.status.should == 401
    end

    it "using an invalid token param" do
      get :index, :token => "fake_key"
      json_response.should == { "error" => "Invalid API key (fake_key) specified." }
    end
  end

  it 'handles exceptions' do
    subject.should_receive(:authenticate_user).and_return(true)
    subject.should_receive(:load_user_roles).and_return(true)
    subject.should_receive(:index).and_raise(Exception.new("no joy"))
    get :index, :token => "fake_key"
    json_response.should == { "exception" => "no joy" }
  end

  it "maps semantic keys to nested_attributes keys" do
    klass = double(:nested_attributes_options => { :line_items => {},
                                                  :bill_address => {} })
    attributes = { 'line_items' => { :id => 1 },
                   'bill_address' => { :id => 2 },
                   'name' => 'test order' }

    mapped = subject.map_nested_attributes_keys(klass, attributes)
    mapped.has_key?('line_items_attributes').should be true
    mapped.has_key?('name').should be true
  end

  it "lets a subclass override the product associations that are eager-loaded" do
    controller.respond_to?(:product_includes, true).should be
  end

  describe '#error_during_processing' do
    controller(FakesController) do
      # GET /foo
      # Simulates a failed API call.
      def foo
        raise StandardError
      end
    end

    # What would be placed in config/initializers/spree.rb
    Spree::Api::BaseController.error_notifier = Proc.new do |e, controller|
      MockHoneybadger.notify_or_ignore(e, rack_env: controller.request.env)
    end

    ##
    # Fake HB alert class
    class MockHoneybadger
      # https://github.com/honeybadger-io/honeybadger-ruby/blob/master/lib/honeybadger.rb#L136
      def self.notify_or_ignore(exception, opts = {})
      end
    end

    before do
      user = double(email: "spree@example.com")
      user.stub_chain :spree_roles, pluck: []
      controller.stub try_spree_current_user: user
      routes.draw { get 'foo' => 'fakes#foo' }
    end

    it 'should notify notify_error_during_processing' do
      expect(MockHoneybadger).to receive(:notify_or_ignore).once.with(kind_of(Exception), rack_env: kind_of(Hash))
      api_get :foo
      expect(response.status).to eq(422)
    end
  end
end
