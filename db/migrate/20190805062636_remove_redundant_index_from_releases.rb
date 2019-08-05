# frozen_string_literal: true

# See http://doc.gitlab.com/ce/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class RemoveRedundantIndexFromReleases < ActiveRecord::Migration[5.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    remove_concurrent_index :releases, :project_id
  end

  def down
    add_concurrent_index :releases, :project_id, unique: true, using: :btree
  end

end
