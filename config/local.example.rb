require 'configuration'

Configuration.for('rubygems') do
  github_token TOKEN
  github_account GITHUB_ACCOUNT
  github_password GITHUB_PASSWORD
  user_agent USER_AGENT
end
