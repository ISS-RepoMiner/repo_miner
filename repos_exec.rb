require_relative './lib/repos.rb'

`stty -echo`
print 'Github Password (not stored): '
github_password = gets.chomp
puts "\n"
print 'Name of the gem: '
gem_name = gets.chomp
puts "\n"
print 'Name of the repo: '
repo_name = gets.chomp
puts "\n"
print 'Username of the repo: '
repo_username = gets.chomp
puts "\n"
`stty echo`
puts ""

client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')

github = Repos::GithubData.new(github_password, repo_username, repo_name)
rubygems = Repos::RubyGemsData.new(gem_name)
ruby_toolbox = Repos::RubyToolBoxData.new(gem_name)

last_year_commit_activity = github.get_last_year_commit_activity
contributors = github.get_contributors
total_commits = github.get_total_commits
forks = github.get_forks
stars = github.get_stars
issues = github.get_issues
issues_info = github.get_issues_info
last_commits_days = github.get_last_commits_days
readme_word_count = github.get_readme_word_count

version_downloads = rubygems.get_version_downloads
version_downloads_trend = rubygems.get_version_downloads_trend
dependencies = rubygems.get_dependencies
total_downloads = rubygems.get_total_downloads

raking = ruby_toolbox.get_raking

# aggregate the data
gem_info = {
  'name'  => gem_name,
  'total_downloads' => total_downloads,
  'version_downloads' => version_downloads,
  'version_downloads_days' => version_downloads_trend,
  'dependencies' => dependencies,
  'last_commit' => last_commits_days,
  'forks' => forks,
  'stars' => stars,
  'issues' => issues,
  'raking' => raking,
  'commits' => total_commits,
  'commit_activity_last_year' => last_year_commit_activity,
  'contributors' => contributors,
  'issues_info' => issues_info,
  'readme_word_count' => readme_word_count
}

puts gem_info

result = client[:gems].insert_one(gem_info)