# frozen_string_literal: true

module DataFields
  extend ActiveSupport::Concern

  class_methods do
    # Provide convenient accessor methods
    # for each serialized property.
    # Also keep track of updated properties in a similar way as ActiveModel::Dirty
    def data_field(*args)
      args.each do |arg|
        self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          unless method_defined?(arg)
            def #{arg}
              data_fields.send('#{arg}') || (properties && properties['#{arg}'])
            end
          end

          def #{arg}=(value)
            data_fields.send('#{arg}=', value)
            updated_properties['#{arg}'] = value unless updated_properties['#{arg}']
          end

          def #{arg}_changed?
            #{arg}_touched? && #{arg} != #{arg}_was
          end

          def #{arg}_touched?
            updated_properties.include?('#{arg}')
          end

          def #{arg}_is
            data_fields.#{arg}
          end

          def #{arg}_was
            data_fields.#{arg}_was || updated_properties['#{arg}']
          end
        RUBY
      end
    end
  end

  included do
    has_one :issue_tracker_data, autosave: true
    has_one :jira_tracker_data, autosave: true

    def data_fields
      raise NotImplementedError
    end

    def updated_data_fields
      @updated_data_fields ||= ActiveSupport::HashWithIndifferentAccess.new
    end
  end
end
