# frozen_string_literal: true

class RedmineService < IssueTrackerService
  def default_title
    'Redmine'
  end

  def default_description
    s_('IssueTracker|Redmine issue tracker')
  end

  def self.to_param
    'redmine'
  end
end
