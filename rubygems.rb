require 'rubygems'
require 'gems'
require 'mongo'
require 'github_api'
require 'httparty'
require 'configuration'
Kernel.load 'config/local.rb'

rubygems = Configuration.for 'rubygems'
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')

## done list
#
#  total downloads: total_downloads
#  downloads by version: version_downloads
#  downloads by days: version_downloads_trend
#  dependencies(both development and runtime): dependencies
#  last commit time: last_commit
#  number of forks: forks
#  number of stars: stars
#  contributors: contributors
#  open issues(issues + PRs): issues
#  number of commits: commits
#  the issues/PRs created time, closed, time and duration: closed_issues
#  the commit activity in last year: last_year_commit_activity
#
##

GEM_NAME = 'oga'
REPO_NAME = 'oga'
REPO_USER = 'YorickPeterse'

GITHUB_API_BASE_URL = "https://api.github.com/repos/#{REPO_USER}/#{REPO_NAME}"
ACCESS_TOKEN = rubygems.github_token
github = Github.new basic_auth: "#{rubygems.github_account}:#{rubygems.github_password}"

versions = Gems.versions GEM_NAME
oga_info = Gems.info GEM_NAME

# get the downloads of each versions
version_downloads = versions.map do |version|
  if version['platform'] === 'ruby'
    {
      'number' => version['number'],
      'downloads' =>version['downloads_count']
    }
  end
end.compact!.reverse!

# get the downloads with each versions and days
version_downloads_trend = versions.map do |version|
  if version['platform'] === 'ruby'
    version_downloads_days = Gems.downloads GEM_NAME, version['number'], Date.today - 30, Date.today
    {
      'number' => version['number'],
      'downloads_date' => version_downloads_days
    }
  end
end.compact!.reverse!

# get the commit activity in last year
last_year_commit_activity = HTTParty.get(GITHUB_API_BASE_URL + "/stats/commit_activity?access_token=#{ACCESS_TOKEN}")

# get the dependencies
dependencies = oga_info['dependencies']

# total number of downloads
total_downloads = oga_info['downloads']

# Get the contributors
contributors = HTTParty.get(GITHUB_API_BASE_URL + "/contributors?access_token=#{ACCESS_TOKEN}").map do |contributor|
  {
    'name' => contributor['login'],
    'contributions' => contributor['contributions']
  }
end

# get the total commits
commits = contributors.reduce(0) do |sum, num|
  sum + num['contributions']
end

# get numbers of forks, stars and issues
repos_meta = HTTParty.get(GITHUB_API_BASE_URL)
forks = repos_meta['forks_count']
stars = repos_meta['stargazers_count']
issues = repos_meta['open_issues_count']

# get information of the closed issues
closed_issues = []
stop = false
page = 1

until stop
  issue_fetch = HTTParty.get(GITHUB_API_BASE_URL + "/issues?state=closed&page=#{page}&access_token=#{ACCESS_TOKEN}")
  if issue_fetch.count === 0
    stop = true
  end

  issue_fetch.each do |issue|
    closed_issues << {
      'number'    => issue['number'],
      'created_at'  => issue['created_at'],
      'closed_at'   => issue['closed_at'],
      'duration'    => (Date.parse(issue['closed_at']) - Date.parse(issue['created_at'])).to_i
    }
  end

  page += 1
end

closed_issues.reverse!

# get the date of the last commit
commit = github.repos.commits.list(REPO_USER, REPO_NAME).to_ary[0].to_hash['commit']['author']['date']
last_commit = (Date.today - Date.parse(commit)).to_i


# aggregate the data
gem_info = {
  'name'  => GEM_NAME,
  'total_downloads' => total_downloads,
  'version_downloads' => version_downloads,
  'version_downloads_days' => version_downloads_trend,
  'dependencies' => dependencies,
  'last_commit' => last_commit,
  'forks' => forks,
  'stars' => stars,
  'issues' => issues,
  'commits' => commits,
  'commit_activity_last_year' => last_year_commit_activity,
  'contributors' => contributors,
  'closed_issues' => closed_issues
}

puts gem_info

result = client[:gems].insert_one(gem_info)
