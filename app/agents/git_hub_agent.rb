class GitHubAgent
  def initialize(app_id:, app_private_key:, app_installation_id:, org:)
    @app_id = app_id
    @app_private_key = OpenSSL::PKey::RSA.new(app_private_key.gsub('\n', "\n"))
    @app_installation_id = app_installation_id
    @org = org

    setup_client
  end

  def create_repository(name, team_id:, team_permission: 'admin', private: false, auto_init: false)
    client = app_installation_client

    resource = find_or_create_repo(
      client,
      name,
      private: private,
      auto_init: auto_init
    )

    client.add_team_repository team_id, resource.full_name, permission: team_permission

    resource
  end

  def import_from_template(repo, template_url, user_auth_token:)
    client = app_installation_client
    client.access_token = user_auth_token

    return unless client.repository? repo

    response = client.start_source_import repo, template_url

    {
      response: response,
      client: client
    }
  end

  def apply_best_practices(repo)
    client = app_installation_client

    # Only apply best practices if the `master` branch exists

    # Will raise a `Octokit::NotFound` error if branch doesn't exist
    client.branch repo, 'master'

    # https://github.community/t5/GitHub-API-Development-and/REST-API-v3-wildcard-branch-protection/td-p/14547
    client.protect_branch(
      repo,
      'master',
      enforce_admins: true,
      required_status_checks: {
        contexts: [],
        strict: true
      },
      required_pull_request_reviews: {
        dismiss_stale_reviews: true,
        require_code_owner_reviews: true
      }
    )
  rescue Octokit::NotFound
    Rails.logger.warn [
      '[GitHub Agent]',
      'cannot apply best practices to repo:',
      repo,
      'because \'master\' branch does not exist'
    ].join(' ')
    false
  end

  def delete_repository(repo)
    client = app_installation_client

    return unless client.repository? repo

    client.delete_repository(repo)
  end

  def add_user_to_team(team_id, username)
    app_installation_client.add_team_membership(
      team_id,
      username
    )
  end

  def remove_user_from_team(team_id, username)
    app_installation_client.remove_team_member(
      team_id,
      username
    )
  end

  private

  def setup_client
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60), # Max is 10 mins
      iss: @app_id.to_s
    }

    jwt = JWT.encode payload, @app_private_key, 'RS256'

    @client = Octokit::Client.new bearer_token: jwt
  end

  def app_installation_client
    token = @client.create_app_installation_access_token(@app_installation_id)[:token]
    Octokit::Client.new bearer_token: token
  end

  def find_or_create_repo(client, name, private:, auto_init:)
    full_name = "#{@org}/#{name}"
    client.repository full_name
  rescue Octokit::NotFound
    client.create_repository name,
      organization: @org,
      private: private,
      auto_init: auto_init
  end
end
