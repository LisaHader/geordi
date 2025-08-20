require 'abbrev' # Dependency of Highline
require 'highline'
require 'net/http'
require 'json'

module Geordi
  class LinearClient
    # This require-style is to prevent Ruby from loading files of a different
    # version of Geordi.
    require File.expand_path('settings', __dir__)

    API_ENDPOINT = 'https://api.linear.app/graphql'.freeze

    def initialize
      self.highline = HighLine.new
      self.settings = Settings.new
    end

    def choose_issue
      if Util.testing?
        return dummy_issue_for_testing
      end

      issues = fetch_linear_issues
      if issues.empty?
        Geordi::Interaction.fail('No issues to offer.')
      end
      issues.sort_by! { |i| -i.dig('state', 'position') }

      highline.choose do |menu|
        max_label_length = 60
        menu.header = 'Choose a started issue (ordered by state)'

        issues.each do |issue|
          id = issue['identifier']
          title = issue['title']
          state = issue['state']['name']
          assignee = issue.dig('assignee', 'displayName') || 'unassigned'

          label = "[#{id}] #{title}"
          label = "#{label[0..(max_label_length - 5)]} ..." if label.length > max_label_length
          label = HighLine::BLUE + HighLine::BOLD + label + HighLine::RESET if issue.dig('assignee', 'isMe')
          label = "#{label} (#{assignee} / #{state})"

          menu.choice(label) { return issue }
        end

        menu.hidden('') { Interaction.fail('No issue selected.') }
      end

      # Selecting an issue will return that issue. If we ever get here, return
      # nothing
      nil
    end

    def issue_from_branch
      issue = if Util.testing?
        dummy_issue_for_testing if ENV['GEORDI_TESTING_ISSUE_MATCHES'] == 'true'
      else
        current_branch = Git.current_branch
        fetch_linear_issues.find { |issue| issue['branchName'] == current_branch }
      end

      return unless issue

      id = issue['identifier']
      title = issue['title']

      Interaction.note "Auto-detected issue #{HighLine::BOLD}[#{id}] #{title}#{HighLine::RESET} from branch name."
      Interaction.prompt("Use it?", "y", /y|yes/i) ? issue : nil
    end

    private

    attr_accessor :highline, :settings

    def dummy_issue_for_testing
      settings.linear_api_key
      ENV['GEORDI_TESTING_NO_LINEAR_ISSUES'] == 'true' ? Geordi::Interaction.fail('No issues to offer.') : {
        'identifier' => 'team-123',
        'title' => 'Test Issue',
        'url' => 'https://www.issue-url.com',
        'branchName' => 'testuser/team-123-test-issue',
        'assignee' => { 'name' => 'Test User', 'isMe' => true },
        'state' => { 'name' => 'In Progress' }
      }
    end

    def fetch_linear_issues
      @linear_issues ||= begin
        team_ids = settings.linear_team_ids
        filter = {
          "team": {
            "id": {
              "in": team_ids,
            }
          },
          "state": {
            "type": {
              "eq": "started"
            }
          }
        }
        response = query_api(<<~GRAPHQL, filter: filter)
          query Issues($filter: IssueFilter) {
            issues(filter: $filter) {
              nodes {
                title
                identifier
                url
                branchName
                assignee {
                  displayName
                  isMe
                }
                state {
                  name
                  position
               }
              }
            }
          }
        GRAPHQL

        response.dig(*%w[issues nodes])
      end
    end

    def query_api(attributes, variables)
      uri = URI(API_ENDPOINT)
      loading_message = "Connecting to #{uri.host} ... "
      clear_loading_message = "\r#{' ' * loading_message.length}\r"

      print(loading_message)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      query = { query: attributes.split.join(' '), variables: variables }.to_json

      request = Net::HTTP::Post.new(uri.path)
      request.body = query

      request['Content-Type'] = 'application/json'
      request['Authorization'] = settings.linear_api_key

      response = https.request(request)
      parsed_response = JSON.parse(response.body)

      if parsed_response.key?('errors')
        errors = parsed_response['errors'].map do |error|
          msg = error.delete('message')
          "#{msg} #{error.inspect}"
        end
        Interaction.fail <<~MSG.strip
          API request failed:
          #{errors.join("\n")}
        MSG
      else
        print clear_loading_message
        parsed_response.dig('data')
      end
    end

  end
end
