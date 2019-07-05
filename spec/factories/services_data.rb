# frozen_string_literal: true

FactoryBot.define do
  factory :jira_tracker_data do
    service
    url 'http://jira.example.com'
    api_url 'http://jira.example.net'
    username 'jira_username'
    password 'jira_password'
  end

  factory :issue_tracker_data do
    service
    project_url 'http://issuetracker.example.com'
    issues_url 'http://issues.example.com/issues/:id'
    new_issue_url 'http://new-issue.example.com'
  end
end
