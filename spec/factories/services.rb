FactoryBot.define do
  factory :service do
    project
    type 'Service'
  end

  factory :custom_issue_tracker_service, class: CustomIssueTrackerService do
    project
    active true
    properties(
      project_url: 'https://project.url.com',
      issues_url: 'https://issues.url.com',
      new_issue_url: 'https://newissue.url.com'
    )
  end

  factory :kubernetes_service do
    project
    type 'KubernetesService'
    active true
    properties({
      api_url: 'https://kubernetes.example.com',
      token: 'a' * 40
    })

    skip_deprecation_validation true
  end

  factory :mock_deployment_service do
    project
    type 'MockDeploymentService'
    active true
  end

  factory :prometheus_service do
    project
    active true
    properties({
      api_url: 'https://prometheus.example.com/',
      manual_configuration: true
    })
  end

  factory :jira_service do
    project
    active true

    transient do
      create_data true
      url 'https://jira.example.com'
      api_url 'https://jira-api.example.com'
      username 'jira_username'
      password 'jira_password'
      jira_issue_transition_id '56-1'
    end

    after(:build) do |service, evaluator|
      if evaluator.create_data
        create(:jira_tracker_data, service: service,
          url: evaluator.url, api_url: evaluator.api_url, jira_issue_transition_id: evaluator.jira_issue_transition_id,
          username: evaluator.username, password: evaluator.password, )
      end
    end
  end

  factory :bugzilla_service do
    project
    active true
    issue_tracker
  end

  factory :redmine_service do
    project
    active true
    issue_tracker
  end

  factory :youtrack_service do
    project
    active true
    issue_tracker
  end

  factory :gitlab_issue_tracker_service do
    project
    active true
    issue_tracker
  end

  trait :issue_tracker do
    transient do
      create_data true
      project_url 'http://issuetracker.example.com'
      issues_url 'http://issues.example.com/issues/:id'
      new_issue_url 'http://new-issue.example.com'
    end

    after(:build) do |service, evaluator|
      if evaluator.create_data
        create(:issue_tracker_data, service: service,
          project_url: evaluator.project_url, issues_url: evaluator.issues_url, new_issue_url: evaluator.new_issue_url
        )
      end
    end
  end

  trait :jira_cloud_service do
    after(:build) do |service|
      create(:jira_tracker_data,
             service: service,
             url: 'https://mysite.atlassian.net',
             username: 'jira_user',
             password: 'my-secret-password'
            )
    end
  end

  factory :hipchat_service do
    project
    type 'HipchatService'
    token 'test_token'
  end

  # this is for testing storing values inside properties, which is deprecated and will be removed in
  # https://gitlab.com/gitlab-org/gitlab-ce/issues/63084
  trait :without_properties_callback do
    jira_tracker_data nil
    issue_tracker_data nil

    after(:build) do
      IssueTrackerService.skip_callback(:validation, :before, :handle_properties)
    end

    to_create { |instance| instance.save(validate: false)}

    after(:create) do
      IssueTrackerService.set_callback(:validation, :before, :handle_properties)
    end
  end
end
