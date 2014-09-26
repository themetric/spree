require 'spec_helper'

describe Spree::Order do
  let(:order) { Spree::Order.new }
  before do
    # Ensure state machine has been re-defined correctly
    Spree::Order.define_state_machine!
    # We don't care about this validation here
    order.stub(:require_email)
  end

  context "#next!" do
    context "when current state is confirm" do
      before do
        order.state = "confirm"
        order.run_callbacks(:create)
        order.stub :payment_required? => true
        order.stub :process_payments! => true
        order.stub :has_available_shipment
      end

      context "when payment processing succeeds" do
        before do
          order.payments << FactoryGirl.create(:payment, state: 'checkout', order: order)
          order.stub process_payments: true
        end

        it "should finalize order when transitioning to complete state" do
          order.should_receive(:finalize!)
          order.next!
        end

        context "when credit card processing fails" do
          before { order.stub :process_payments! => false }

          it "should not complete the order" do
             order.next
             order.state.should == "confirm"
           end
        end
      end

      context "when payment processing fails" do
        before { order.stub :process_payments! => false }

        it "cannot transition to complete" do
         order.next
         order.state.should == "confirm"
        end
      end
    end

    context "when current state is delivery" do
      before do
        order.stub :payment_required? => true
        order.stub :apply_free_shipping_promotions
        order.state = "delivery"
      end

      it "adjusts tax rates when transitioning to delivery" do
        # Once for the line items
        Spree::TaxRate.should_receive(:adjust).once
        order.stub :set_shipments_cost
        order.next!
      end

      it "adjusts tax rates twice if there are any shipments" do
        # Once for the line items, once for the shipments
        order.shipments.build
        Spree::TaxRate.should_receive(:adjust).twice
        order.stub :set_shipments_cost
        order.next!
      end
    end
  end

  context "#can_cancel?" do

    %w(pending backorder ready).each do |shipment_state|
      it "should be true if shipment_state is #{shipment_state}" do
        order.stub :completed? => true
        order.shipment_state = shipment_state
        order.can_cancel?.should be true
      end
    end

    (Spree::Shipment.state_machine.states.keys - %w(pending backorder ready)).each do |shipment_state|
      it "should be false if shipment_state is #{shipment_state}" do
        order.stub :completed? => true
        order.shipment_state = shipment_state
        order.can_cancel?.should be false
      end
    end

  end

  context "#cancel" do
    let!(:variant) { stub_model(Spree::Variant) }
    let!(:inventory_units) { [stub_model(Spree::InventoryUnit, :variant => variant),
                              stub_model(Spree::InventoryUnit, :variant => variant) ]}
    let!(:shipment) do
      shipment = stub_model(Spree::Shipment)
      shipment.stub :inventory_units => inventory_units, :order => order
      order.stub :shipments => [shipment]
      shipment
    end

    before do

      2.times do
        create(:line_item, :order => order, price: 10)
      end

      order.line_items.stub :find_by_variant_id => order.line_items.first

      order.stub :completed? => true
      order.stub :allow_cancel? => true

      shipments = [shipment]
      order.stub :shipments => shipments
      shipments.stub :states => []
      shipments.stub :ready => []
      shipments.stub :pending => []
      shipments.stub :shipped => []

      Spree::OrderUpdater.any_instance.stub(:update_adjustment_total) { 10 }
    end

    it "should send a cancel email" do

      # Stub methods that cause side-effects in this test
      shipment.stub(:cancel!)
      order.stub :has_available_shipment
      order.stub :restock_items!
      mail_message = double "Mail::Message"
      order_id = nil
      Spree::OrderMailer.should_receive(:cancel_email) { |*args|
        order_id = args[0]
        mail_message
      }
      mail_message.should_receive :deliver
      order.cancel!
      order_id.should == order.id
    end

    context "restocking inventory" do
      before do
        shipment.stub(:ensure_correct_adjustment)
        shipment.stub(:update_order)
        Spree::OrderMailer.stub(:cancel_email).and_return(mail_message = double)
        mail_message.stub :deliver

        order.stub :has_available_shipment
      end
    end

    context "resets payment state" do

      let(:payment) { create(:payment) }

      before do
        # TODO: This is ugly :(
        # Stubs methods that cause unwanted side effects in this test
        Spree::OrderMailer.stub(:cancel_email).and_return(mail_message = double)
        mail_message.stub :deliver
        order.stub :has_available_shipment
        order.stub :restock_items!
        shipment.stub(:cancel!)
        payment.stub(:cancel!)
        order.stub_chain(:payments, :valid, :size).and_return(1)
        order.stub_chain(:payments, :completed).and_return([payment])
        order.stub_chain(:payments, :last).and_return(payment)
      end

      context "without shipped items" do
        it "should set payment state to 'void'" do
          expect { order.cancel! }.to change{ order.reload.payment_state }.to("void")
        end
      end

      context "with shipped items" do
        before do
          order.stub :shipment_state => 'partial'
          order.stub :outstanding_balance? => false
          order.stub :payment_state => "paid"
        end

        it "should not alter the payment state" do
          order.cancel!
          expect(order.payment_state).to eql "paid"
        end
      end

      context "with payments" do
        let(:payment) { create(:payment) }

        it "should automatically refund all payments" do
          order.stub_chain(:payments, :valid, :size).and_return(1)
          order.stub_chain(:payments, :completed).and_return([payment])
          order.stub_chain(:payments, :last).and_return(payment)
          payment.should_receive(:cancel!)
          order.cancel!
        end
      end
    end
  end


  # Another regression test for #729
  context "#resume" do
    before do
      order.stub :email => "user@spreecommerce.com"
      order.stub :state => "canceled"
      order.stub :allow_resume? => true

      # Stubs method that cause unwanted side effects in this test
      order.stub :has_available_shipment
    end
  end
end
