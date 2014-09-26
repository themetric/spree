require 'spec_helper'

module Spree
  describe Api::CreditCardsController do
    render_views

    let!(:admin_user) do
      user = Spree.user_class.new(:email => "spree@example.com", :id => 1)
      user.generate_spree_api_key!
      user.stub(:has_spree_role?).with('admin').and_return(true)
      user
    end

    let!(:normal_user) do
      user = Spree.user_class.new(:email => "spree2@example.com", :id => 2)
      user.generate_spree_api_key!
      user
    end

    let!(:card) { create(:credit_card, :user_id => admin_user.id, gateway_customer_profile_id: "random") }

    before do
      stub_authentication!
    end

    it "the user id doesn't exist" do
      api_get :index, user_id: 1000
      response.status.should == 404
    end

    context "calling user is in admin role" do
      let(:current_api_user) do
        user = admin_user
        user
      end

      it "no credit cards exist for user" do
        api_get :index, user_id: normal_user.id

        response.status.should == 200
        json_response["pages"].should == 0
      end

      it "can view all credit cards for user" do
        api_get :index, user_id: current_api_user.id

        response.status.should == 200
        json_response["pages"].should == 1
        json_response["current_page"].should == 1
        json_response["credit_cards"].length.should == 1
        json_response["credit_cards"].first["id"].should == card.id
      end
    end

    context "calling user is not in admin role" do
      let(:current_api_user) do
        user = normal_user
        user
      end

      let!(:card) { create(:credit_card, :user_id => normal_user.id, gateway_customer_profile_id: "random") }

      it "can not view user" do
        api_get :index, user_id: admin_user.id

        response.status.should == 404
      end

      it "can view own credit cards" do
        api_get :index, user_id: normal_user.id

        response.status.should == 200
        json_response["pages"].should == 1
        json_response["current_page"].should == 1
        json_response["credit_cards"].length.should == 1
        json_response["credit_cards"].first["id"].should == card.id
      end
    end
  end
end
