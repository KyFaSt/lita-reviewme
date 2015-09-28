require 'octokit'

module Lita
  module Handlers
    class Reviewme < Handler
      REDIS_LIST = "reviewers"

      route(
        /add (.+) to (.+)/i,
        :add_reviewer,
        command: true,
      )

      route(
        /add reviewer (.+)/i,
        :add_reviewer,
        command: true,
        help: { "add reviewer iamvery" => "adds iamvery to the reviewer rotation" },
      )

      route(
        /create team (.+), reviewers: (.+)/i,
        :create_team,
        command: true,
        help: { "create team backend, reviewers: iamvery, kyfast" => "creates review group named backend containing GitHub users iamvery and kyfast" },
      )

      route(
        /remove (.+) from reviews/i,
        :remove_reviewer,
        command: true,
      )

      route(
        /remove reviewer (.+)/i,
        :remove_reviewer,
        command: true,
        help: { "remove reviewer iamvery" => "removes iamvery from the reviewer rotation" },
      )

      route(
        /reviewers (.+)/i,
        :display_reviewers,
        command: true,
        help: { "reviewers" => "display list of reviewers" },
      )

      route(
        /teams/i,
        :display_review_teams,
        command: true,
        help: { "teams" => "display list of review teams" },
      )

      route(
        /review me (.+)/i,
        :generate_assignment,
        command: true,
        help: { "review me" => "responds with the next reviewer" },
      )

      route(
        %r{review (?<group>.+) <?(?<url>(https://)?github.com/(?<repo>.+)/(pull|issues)/(?<id>\d+))>?}i,
        :comment_on_github,
        command: true,
        help: { "review https://github.com/user/repo/pull/123" => "adds comment to GH issue requesting review" },
      )

      route(
        %r{review (?<group>.+) <?(?<url>(https?://)(?!github.com).*)>?}i,
        :mention_reviewer,
        command: true,
        help: { "review http://some-non-github-url.com" => "requests review of the given URL in chat" }
      )

      def create_team(response)
        review_team = response.matches.flatten.first
        reviewers = response.matches.flatten.last.split(', ')

        redis.rpush(review_team, reviewers)
        response.reply("created team #{review_team} with reviewers #{reviewers}")
      end

      def add_reviewer(response)
        reviewer = response.matches.flatten.first
        review_group = response.matches.flatten.last

        if redis.rpushx(review_group, reviewer)
          response.reply("added #{reviewer} to #{review_group}")
        else
          response.reply("did not add #{reviewer} to #{review_group}, #{review_group} does not exist")
        end
      end

      def remove_reviewer(response)
        reviewer = response.matches.flatten.first
        redis.lrem(REDIS_LIST, 0, reviewer)
        response.reply("removed #{reviewer} from reviews")
      end

      def display_reviewers(response)
        review_group = response.matches.flatten.first
        reviewers = redis.lrange(review_group, 0, -1)
        response.reply(reviewers.join(', '))
      end

      def display_review_teams(response)
        teams = redis.keys
        response.reply(teams.join(', '))
      end

      def generate_assignment(response)
        review_group = response.matches.flatten.first
        reviewer = next_reviewer(review_group)
        response.reply(reviewer.to_s)
      end

      def comment_on_github(response)
        repo = response.match_data[:repo]
        id = response.match_data[:id]
        review_group = response.match_data[:group]

        reviewer = next_reviewer(review_group)
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
        review_group = response.match_data[:group]
        reviewer = next_reviewer(review_group)

        response.reply(chat_mention(reviewer, url))
      end

      private

      def next_reviewer(review_group)
        redis.rpoplpush(review_group, review_group)
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
