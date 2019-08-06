# frozen_string_literal: true

module Gitlab
  module Artifacts
    class MigrationHelper
      def migrate_to_remote_storage(&block)
        artifacts = ::Ci::Build.with_project.with_artifacts_stored_locally
        migrate(artifacts, ObjectStorage::Store::REMOTE, &block)
      end

      def migrate_to_local_storage(&block)
        artifacts = ::Ci::Build.with_project.with_artifacts_stored_remotely
        migrate(artifacts, ObjectStorage::Store::LOCAL, &block)
      end

      private

      def migrate(artifacts, store, &block)
        artifacts.find_each(batch_size: 10) do |build| # rubocop:disable CodeReuse/ActiveRecord
          build.artifacts_file.migrate!(store)
          build.artifacts_metadata.migrate!(store)

          yield build if block
        rescue => e
          raise StandardError.new("Failed to transfer artifacts of #{build.id} with error: #{e.message}")
        end
      end
    end
  end
end
