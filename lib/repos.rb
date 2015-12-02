require 'rubygems'
require 'gems'
require 'mongo'
require 'github_api'
require 'httparty'
require 'configuration'
require 'nokogiri'
require 'open-uri'

module Repos
  Kernel.load 'config/local.rb'

  class GithubData
    def initialize(repo_user, repo_name, github_password='')
      @GITHUB_README_URL = "https://raw.githubusercontent.com/#{repo_user}/#{repo_name}/master"
      @GITHUB_API_BASE_URL = "https://api.github.com/repos/#{repo_user}/#{repo_name}"
      @rubygems = Configuration.for 'rubygems'
      @access_token = @rubygems.github_token
      @github_password = github_password === '' ? @rubygems.github_password : github_password
      @repo_user = repo_user
      @repo_name = repo_name
    end
    
    # get the commit activity in last year
    def get_last_year_commit_activity
      last_year_commit_activity = HTTParty.get(@GITHUB_API_BASE_URL + "/stats/commit_activity?access_token=#{@access_token}")
    end

    # Get the contributors
    def get_contributors
      contributors = HTTParty.get(@GITHUB_API_BASE_URL + "/contributors?access_token=#{@access_token}").map do |contributor|
        {
          'name' => contributor['login'],
          'contributions' => contributor['contributions']
        }
      end

      contributors
    end

    # get the total commits
    def get_total_commits
      contributors = get_contributors
      commits = contributors.reduce(0) do |sum, num|
        sum + num['contributions']
      end

      commits
    end

    # get numbers of forks, stars and issues
    def get_forks
      repos_meta = HTTParty.get(@GITHUB_API_BASE_URL)
      forks = repos_meta['forks_count']

      forks
    end

    def get_stars
      repos_meta = HTTParty.get(@GITHUB_API_BASE_URL)
      stars = repos_meta['stargazers_count']

      stars
    end

    def get_issues
      repos_meta = HTTParty.get(@GITHUB_API_BASE_URL)
      issues = repos_meta['open_issues_count']

      issues
    end 

    # get information of the closed issues
    def get_issues_info
      closed_issues = []
      stop = false
      page = 1

      until stop
        issue_fetch = HTTParty.get(@GITHUB_API_BASE_URL + "/issues?state=closed&page=#{page}&access_token=#{@access_token}")
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
    end

    # get the date of the last commit
    def get_last_commits_days
      github = Github.new basic_auth: "#{@rubygems.github_account}:#{@github_password}"

      commit = github.repos.commits.list(@repo_user, @repo_name).to_ary[0].to_hash['commit']['author']['date']
      last_commit = (Date.today - Date.parse(commit)).to_i

      last_commit
    end

    # get the readme file
    def get_readme_word_count
      github_contents = HTTParty.get(@GITHUB_API_BASE_URL + '/contents')
      readme_file = ''
      github_contents.each do |content|
        readme_file = content['name'] if content['name'] =~ /^README/
      end

      stop_words = []
      File.open(File.expand_path("../public/stop_words.txt",  File.dirname(__FILE__)), "r") do |f|
        f.each_line do |line|
          stop_words << line.gsub(/\n/,"")
        end
      end

      readme = HTTParty.get(@GITHUB_README_URL + "/#{readme_file}")
      words = readme.split(' ')
      freqs = Hash.new(0)
      words.each do |word|
        if word =~ /^\w+$/ && !stop_words.include?(word.downcase)
          freqs[word] += 1 
        end
      end
      freqs = freqs.sort_by { |word, freq| freq }.reverse!

      freqs
    end
  end
  
  class RubyGemsData
    def initialize(gem_name)
      @gem_name = gem_name
    end

    # get the downloads of each versions
    def get_version_downloads
      versions = Gems.versions @gem_name

      version_downloads = versions.map do |version|
        if version['platform'] === 'ruby'
          {
            'number' => version['number'],
            'downloads' =>version['downloads_count']
          }
        end
      end.reverse!

      version_downloads.compact! if version_downloads.include? nil
      version_downloads
    end 

    def get_version_downloads_trend(start_date='', end_date='')
      versions = Gems.versions @gem_name

      end_date = Date.today if end_date.to_s == ''
      version_downloads_trend = versions.map do |version|
        start = version['created_at'] if start_date.to_s == ''

        if version['platform'] === 'ruby'
          version_downloads_days = Gems.downloads @gem_name, version['number'], start, end_date
          {
            'number' => version['number'],
            'downloads_date' => version_downloads_days
          }
        end
      end.reverse!

      version_downloads_trend.compact! if version_downloads_trend.include? nil
      version_downloads_trend
    end

    # get the dependencies
    def get_dependencies
      oga_info = Gems.info @gem_name
      dependencies = oga_info['dependencies']

      dependencies
    end

    # total number of downloads
    def get_total_downloads
      oga_info = Gems.info @gem_name
      total_downloads = oga_info['downloads']

      total_downloads
    end
  end

  class RubyToolBoxData
    def initialize(gem_name)
      rubygems = Configuration.for 'rubygems'
      @user_agent = rubygems.user_agent
      @RUBY_TOOLBOX_BASE_URL = "https://www.ruby-toolbox.com/projects/"
      @RANKING_PATH = "//div[@class='teaser-bar']//li[last()-1]//a"
      @gem_name = gem_name
    end

    # get the ranking on Ruby ToolBox
    def get_ranking
      begin
        document = open(@RUBY_TOOLBOX_BASE_URL + @gem_name,
            'User-Agent' => @user_agent
          )
        noko_document = Nokogiri::HTML(document)
        ranking = noko_document.xpath(@RANKING_PATH).text
      rescue
        ranking = 0
      end
      ranking
    end 
  end

  class StackOverflow
    def initialize(gem_name)
      stackoverflow = Configuration.for 'stackoverflow'
      @STACKOVERFLOW_API = "https://api.stackexchange.com/2.2/search/advanced?order=desc&sort=creation&q=#{gem_name}&site=stackoverflow&key=#{stackoverflow.stackoverflow_token}"
    end

    #get questions from stackexchange
    def get_questions
      questions = []
      fetch_questions = HTTParty.get(@STACKOVERFLOW_API)
      fetch_questions['items'].each do |q|
        questions << {
          'creation_date' => q['creation_date'],
          'title' => q ['title'].split(' '),
          'views' => q['view_count']
        }
      end

      questions
    end
  end

end 