require 'octokit'

module Lita
  module Handlers
    class Reviewme < Handler

      route(
        /add (?<reviewer>.+) to (?<team>.+)/i,
        :add_reviewer,
        command: true,
        help: { "add reviewer iamvery to backend" => "adds iamvery to the backend reviewer rotation" },
      )

      route(
        /create team (?<team>.+), reviewers: (?<reviewers>.+)/i,
        :create_team,
        command: true,
        help: { "create team backend, reviewers: iamvery, kyfast" => "creates review team named backend containing GitHub users iamvery and kyfast" },
      )

      route(
        /remove (?<reviewer>.+) from (?<team>.+)/i,
        :remove_reviewer,
        command: true,
        help: { "remove reviewer iamvery from backend" => "removes iamvery from the backend reviewer rotation" },
      )

      route(
        /reviewers (?<team>.+)/i,
        :display_reviewers,
        command: true,
        help: { "reviewers backend" => "display list of reviewers in backend group" },
      )

      route(
        /teams/i,
        :display_review_teams,
        command: true,
        help: { "teams" => "display list of review teams" },
      )

      route(
        /review me (?<team>.+)/i,
        :generate_assignment,
        command: true,
        help: { "review me backend" => "responds with the next reviewer in the backend rotation" },
      )

      route(
        %r{review (?<team>.+) <?(?<url>(https://)?github.com/(?<repo>.+)/(pull|issues)/(?<id>\d+))>?}i,
        :comment_on_github,
        command: true,
        help: { "review backend https://github.com/user/repo/pull/123" => "adds comment to GH issue requesting review from the next reviewer in the backend rotation" },
      )

      route(
        %r{review (?<team>.+) <?(?<url>(https?://)(?!github.com).*)>?}i,
        :mention_reviewer,
        command: true,
        help: { "review backend http://some-non-github-url.com" => "requests review by next reviewer in backend rotation of the given URL in chat" }
      )

      def create_team(response)
        review_team = response.match_data[:team]
        reviewers = response.match_data[:reviewers].split(', ')

        redis.rpush(review_team, reviewers)
        response.reply("created team #{review_team} with reviewers #{reviewers.join(', ')}")
      end

      def add_reviewer(response)
        reviewer = response.match_data[:reviewer]
        review_team = response.match_data[:team]

        if redis.rpushx(review_team, reviewer)
          response.reply("added #{reviewer} to #{review_team}")
        else
          response.reply("did not add #{reviewer} to #{review_team}, #{review_team} does not exist")
        end
      end

      def remove_reviewer(response)
        reviewer = response.match_data[:reviewer]
        review_team = response.match_data[:team]

        redis.lrem(review_team, 0, reviewer)
        response.reply("removed #{reviewer} from #{review_team}")
      end

      def display_reviewers(response)
        review_team = response.match_data[:team]
        reviewers = redis.lrange(review_team, 0, -1)
        response.reply(reviewers.join(', '))
      end

      def display_review_teams(response)
        teams = redis.keys
        response.reply(teams.join(', '))
      end

      def generate_assignment(response)
        review_team = response.match_data[:team]
        reviewer = next_reviewer(review_team)
        response.reply(reviewer.to_s)
      end

      def comment_on_github(response)
        repo = response.match_data[:repo]
        id = response.match_data[:id]
        review_team = response.match_data[:team]

        reviewer = next_reviewer(review_team)
        comment = github_comment(reviewer)

        begin
          github_client.add_comment(repo, id, comment)
          response.reply("#{reviewer} should be on it...")
        rescue Octokit::Error
          url = response.match_data[:url]
          response.reply("I couldn't post a comment. (Are the permissions right?) #{chat_mention(reviewer, url)}")
        end
      end

      def mention_reviewer(response)
        url = response.match_data[:url]
        review_team = response.match_data[:team]
        reviewer = next_reviewer(review_team)

        response.reply(chat_mention(reviewer, url))
      end

      private

      def next_reviewer(review_team)
        redis.rpoplpush(review_team, review_team)
      end

      def github_comment(reviewer)
        ":eyes: @#{reviewer}"
      end

      def github_client
        @github_client ||= Octokit::Client.new(access_token: github_access_token)
      end

      def github_access_token
        ENV['GITHUB_WOLFBRAIN_ACCESS_TOKEN']
      end

      def chat_mention(reviewer, url)
        "#{reviewer}: :eyes: #{url}"
      end
    end

    Lita.register_handler(Reviewme)
  end
end
