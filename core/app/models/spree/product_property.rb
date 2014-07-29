module Spree
  class ProductProperty < Spree::Base
    belongs_to :product, touch: true, class_name: 'Spree::Product', inverse_of: :product_properties
    belongs_to :property, class_name: 'Spree::Property', inverse_of: :product_properties

    validates :property, presence: true
    validates :value, length: { maximum: 255 }
    validate :unique_product_property

    default_scope -> { order("#{self.table_name}.position") }

    def unique_product_property
      pp = ProductProperty.where(value: value).first
      if  pp && pp.property_name == property_name
        errors.add(:value, Spree.t(:duplicate_property_value))
      end
    end

    # virtual attributes for use with AJAX completion stuff
    def property_name
      property.name if property
    end

    def property_name=(name)
      unless name.blank?
        unless property = Property.find_by(name: name)
          property = Property.create(name: name, presentation: name)
        end
        self.property = property
      end
    end
  end
end
