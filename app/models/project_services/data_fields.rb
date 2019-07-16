# frozen_string_literal: true

module DataFields
  extend ActiveSupport::Concern

  class_methods do
    # Provide convenient accessor methods for data fields.
    # TODO: Simplify as part of https://gitlab.com/gitlab-org/gitlab-ce/issues/63084
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

            # we still can use this even for data_fields because we check
            # only key presence in arg_touched? and use data_fields
            # method in arg_changed?
            updated_data_fields << '#{arg}' unless value == #{arg}_was
          end

          def #{arg}_changed?
            if data_fields.persisted?
              data_fields.send('#{arg}_changed?')
            else
              #{arg}_touched? && #{arg} != #{arg}_was
            end
          end

          def #{arg}_touched?
            updated_data_fields.include?('#{arg}')
          end

          def #{arg}_was
            return unless #{arg}_touched?
            return if data_fields.persisted? # arg_was does not work for attr_encrypted

            legacy_properties_data['#{arg}']
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

    def data_fields_present?
      data_fields.persisted?
    rescue NotImplementedError
      false
    end
  end
end
