# frozen_string_literal: true

class AddMaxIssueCountToList < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers
  disable_ddl_transaction!

  # Set this constant to true if this migration requires downtime.
  DOWNTIME = false

  def up
    add_column_with_default :lists, :max_issue_count, :integer, default: 0, allow_null: false
  end

  def down
    remove_column :lists, :max_issue_count
  end
end
