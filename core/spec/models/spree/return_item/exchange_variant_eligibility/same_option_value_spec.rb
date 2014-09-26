require 'spec_helper'

module Spree
  module ReturnItem::ExchangeVariantEligibility
    describe SameOptionValue do
      describe ".eligible_variants" do
        let(:color_option_type) { create(:option_type, name: "color") }
        let(:waist_option_type) { create(:option_type, name: "waist") }
        let(:inseam_option_type) { create(:option_type, name: "inseam") }

        let(:blue_option_value) { create(:option_value, name: "blue", option_type: color_option_type) }
        let(:red_option_value) { create(:option_value, name: "red", option_type: color_option_type) }

        let(:three_two_waist_option_value) { create(:option_value, name: 32, option_type: waist_option_type) }
        let(:three_four_waist_option_value) { create(:option_value, name: 34, option_type: waist_option_type) }

        let(:three_zero_inseam_option_value) { create(:option_value, name: 30, option_type: inseam_option_type) }
        let(:three_one_inseam_option_value) { create(:option_value, name: 31, option_type: inseam_option_type) }

        let(:product) { create(:product, option_types: [color_option_type, waist_option_type, inseam_option_type]) }

        let(:variant) { create(:variant, product: product, option_values: [blue_option_value, three_two_waist_option_value, three_zero_inseam_option_value]) }

        before do
          @original_option_type_restrictions = SameOptionValue.option_type_restrictions
          SameOptionValue.option_type_restrictions = ["color", "waist"]
        end

        after { SameOptionValue.option_type_restrictions = @original_option_type_restrictions }

        subject { SameOptionValue.eligible_variants(variant) }

        it "returns all other variants for the same product with the same option value for the specified option type" do
          same_option_values_variant = create(:variant, product: product, option_values: [blue_option_value, three_two_waist_option_value, three_one_inseam_option_value])
          different_color_option_value_variant = create(:variant, product: product, option_values: [red_option_value, three_two_waist_option_value, three_one_inseam_option_value])
          different_waist_option_value_variant = create(:variant, product: product, option_values: [blue_option_value, three_four_waist_option_value, three_one_inseam_option_value])

          expect(subject).to eq [same_option_values_variant]
        end

        it "does not return variants for another product" do
          other_product_variant = create(:variant)
          expect(subject).not_to include other_product_variant
        end

        context "no option value restrictions are specified" do
          before do
            @original_option_type_restrictions = SameOptionValue.option_type_restrictions
            SameOptionValue.option_type_restrictions = []
          end

          after { SameOptionValue.option_type_restrictions = @original_option_type_restrictions }

          it "returns all variants for the product" do
            same_option_values_variant = create(:variant, product: product, option_values: [blue_option_value, three_two_waist_option_value, three_one_inseam_option_value])
            different_color_option_value_variant = create(:variant, product: product, option_values: [red_option_value, three_two_waist_option_value, three_one_inseam_option_value])
            different_waist_option_value_variant = create(:variant, product: product, option_values: [blue_option_value, three_four_waist_option_value, three_one_inseam_option_value])

            expect(subject.sort).to eq [same_option_values_variant, different_waist_option_value_variant, different_color_option_value_variant].sort
          end
        end
      end
    end
  end
end

