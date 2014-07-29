require 'spec_helper'

describe Spree::ProductProperty do

  context "validations" do
    it "should validate length of value" do
      pp = create(:product_property)
      pp.value = "x" * 256
      pp.should_not be_valid
    end

    context "with an invalid duplicate property" do
      let!(:prop) { create(:product_property, property_name: "Brand", value: "Rolex") }
      let(:prop2) { build(:product_property, property_name: "Brand", value: "Rolex") }

      it "should not be valid" do
        prop2.should_not be_valid
      end

      it "should have an error on property value" do
        prop2.should have(1).error_on(:value)
      end

      it "should display an error message" do
        prop2.errors.messages[:value].should == 'has already been used for this product'
      end
    end
  end

  context "touching" do
    it "should update product" do
      pp = create(:product_property)
      pp.product.should_receive(:touch)
      pp.touch
    end
  end
end
