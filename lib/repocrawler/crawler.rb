require 'rubygems'
require 'gems'
require 'github_api'
require 'httparty'
require 'nokogiri'
require 'open-uri'

module Repos

  class GithubData
    def initialize(repo_user, repo_name, github_token, github_password, github_account, user_agent)
      @GITHUB_README_URL = "https://raw.githubusercontent.com/#{repo_user}/#{repo_name}/master"
      @GITHUB_API_BASE_URL = "https://api.github.com/repos/#{repo_user}/#{repo_name}"
      @access_token = github_token
      @github_password = github_password
      @github_account = github_account
      @user_agent = user_agent
      @repo_user = repo_user
      @repo_name = repo_name
    end
    
    # get the commit activity in last year
    def get_last_year_commit_activity
      last_year_commit_activity = HTTParty.get(@GITHUB_API_BASE_URL + "/stats/commit_activity?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if last_year_commit_activity.is_a?(Hash) && last_year_commit_activity['message'] === 'Not Found'
        last_year_commit_activity = nil
      else
        last_year_commit_activity.delete_if {|record| record['total'] == 0}
      end

      last_year_commit_activity

    end

    # Get the contributors
    def get_contributors
      contributors = HTTParty.get(@GITHUB_API_BASE_URL + "/contributors?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })
      if contributors.is_a?(Hash) && contributors['message'] === 'Not Found'
        contributors = nil
      else
        contributors.map! do |contributor|
          {
            'name' => contributor['login'],
            'contributions' => contributor['contributions']
          }
        end
      end

      contributors
    end

    # get the total commits
    def get_total_commits
      contributors = get_contributors

      if contributors.nil?
        commits = nil
      else
        commits = contributors.reduce(0) do |sum, num|
          sum + num['contributions']
        end
      end

      commits
    end

    # get numbers of forks, stars and issues
    def get_forks
      repos_meta = HTTParty.get(@GITHUB_API_BASE_URL + "?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if repos_meta.is_a?(Hash) && repos_meta['message'] === 'Not Found'
        forks = nil
      else
        forks = repos_meta['forks_count']
      end

      forks
    end

    def get_stars
      repos_meta = HTTParty.get(@GITHUB_API_BASE_URL + "?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if repos_meta.is_a?(Hash) && repos_meta['message'] === 'Not Found'
        stars = nil
      else
        stars = repos_meta['stargazers_count']
      end

      stars
    end

    def get_issues
      repos_meta = HTTParty.get(@GITHUB_API_BASE_URL + "?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if repos_meta.is_a?(Hash) && repos_meta['message'] === 'Not Found'
        issues = nil
      else
        issues = repos_meta['open_issues_count']
      end

      issues
    end 

    # get commits history
    def get_commits_history
      commits_info = []
      stop = false
      page = 1

      until stop
        commits_fetch = HTTParty.get(@GITHUB_API_BASE_URL + "/commits?page=#{page}&access_token=#{@access_token}", headers: {
          "User-Agent" => @user_agent
        })

        if commits_fetch.is_a?(Hash) && commits_fetch['message'] === 'Not Found'
          break
        end

        if commits_fetch.count === 0
          stop = true
        end

        commits_fetch.each do |commit|
          commits_info << {
            "committer"     => commit['commit']['committer']['name'],
            "created_at"    => commit['commit']['committer']['date']
          }
        end

        page += 1
      end

      commits_info.reverse!
    end

    # get information of the closed issues
    def get_issues_info
      closed_issues = []
      stop = false
      page = 1

      until stop
        issue_fetch = HTTParty.get(@GITHUB_API_BASE_URL + "/issues?state=closed&page=#{page}&access_token=#{@access_token}", headers: {
          "User-Agent" => @user_agent
        })

        if issue_fetch.is_a?(Hash) && issue_fetch['message'] === 'Not Found'
          break
        end

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
      commits_fetch = HTTParty.get(@GITHUB_API_BASE_URL + "/commits?access_token=#{@access_token}", headers: {
          "User-Agent" => @user_agent
      })

      if commits_fetch.is_a?(Hash) && commits_fetch['message'] === 'Not Found'
        last_commit = nil
      else
        last_commit_date = commits_fetch.first['commit']['author']['date']
        last_commit = (Date.today - Date.parse(last_commit_date)).to_i
      end

      last_commit
    end

    # get the readme file
    def get_readme_word_count
      github_contents = HTTParty.get(@GITHUB_API_BASE_URL + "/contents?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if github_contents.is_a?(Hash) && github_contents['message'] === 'Not Found'
        return nil
      else
        readme_file = ''
        github_contents.each do |content|
          readme_file = content['name'] if content['name'] =~ /^README/
        end

        stop_words = []
        File.open(File.expand_path("../../public/stop_words.txt",  File.dirname(__FILE__)), "r") do |f|
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

        return freqs
      end
    end

    # get readme raw text
    def get_readme_raw_text
      readme = HTTParty.get(@GITHUB_API_BASE_URL + "/readme?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if readme.is_a?(Hash) && readme['message'] === 'Not Found'
        return nil
      else
        readme_content = {
          'content'   => readme['content'],
          'encoding'  => readme['encoding']
        }
      end

      readme_content
    end

    # check if the project has test
    # TODO: recursively search
    def get_test
      has_test = 0;

      contents = HTTParty.get(@GITHUB_API_BASE_URL + "/contents?access_token=#{@access_token}", headers: {
        "User-Agent" => @user_agent
      })

      if contents.is_a?(Hash) && contents['message'] === 'Not Found'
        return has_test
      else
        test_folder = contents.select do |content|
          match = content['name'] =~ /(spec)|(test)/

          !match.nil? && content['type'] === 'dir'
        end

         test_folder.empty? ? has_test = 0 : has_test = 1
        return has_test
      end
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
            'downloads_date' => version_downloads_days,
            'created_at'  => version['created_at']
          }
        end
      end.reverse!

      version_downloads_trend.compact! if version_downloads_trend.include? nil

      version_downloads_trend.each do |version|
        version['downloads_date'].delete_if {|_key, value| value == 0}
      end
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
    def initialize(gem_name, user_agent)
      @user_agent = user_agent
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
    def initialize(gem_name, stackoverflow_token)
      @STACKOVERFLOW_API = "https://api.stackexchange.com/2.2/search/advanced?order=desc&sort=creation&q=#{gem_name}&site=stackoverflow&key=#{stackoverflow_token}"
    end

    #get questions from stackexchange
    def get_questions

      stop_words = []
      File.open(File.expand_path("../../public/stop_words.txt",  File.dirname(__FILE__)), "r") do |f|
        f.each_line do |line|
          stop_words << line.gsub(/\n/,"")
        end
      end

      questions = []
      fetch_questions = HTTParty.get(@STACKOVERFLOW_API)
      fetch_questions['items'].each do |q|
        #don't store stop words
        good_words = []
        q['title'].split(' ').map do |word|
          if !stop_words.include?(word.downcase)
            good_words << word
          end
        end

        questions << {
          'creation_date' => q['creation_date'],
          'title' => good_words,
          'views' => q['view_count']
        }
      end

      questions_word_count = Hash.new(0)
      questions.each do |question|
        question['title'].each do |word|
          questions_word_count[word] += 1
        end
      end

      questions_word_count = questions_word_count.sort_by { |word, freq| freq }.reverse!
      [questions, questions_word_count]
    end
  end

end 