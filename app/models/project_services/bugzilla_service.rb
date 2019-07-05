# frozen_string_literal: true

class BugzillaService < IssueTrackerService
  def default_title
    'Bugzilla'
  end

  def default_description
    s_('IssueTracker|Bugzilla issue tracker')
  end

  def self.to_param
    'bugzilla'
  end
end
