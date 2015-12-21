$:.push File.expand_path("../lib", __FILE__)
require 'repocrawler/version'

Gem::Specification.new do |s|
  s.name        =  'repocrawler'
  s.version     =  Repos::VERSION
  s.executables << 'repocrawler'
  s.date        =  '2015-12-22'
  s.summary     =  'Grab the information of repository from the GitHub, RubyGems, The Ruby Toolbox and Stackoverflow'
  s.description =  'Grab the information of repository from the GitHub, RubyGems, The Ruby Toolbox and Stackoverflow'
  s.authors     =  ['Lee Chen', 'Soumya Ray', 'omarsar']
  s.email       =  'chung1350@hotmail.com'
  s.files       =  `git ls-files`.split("\n")
  s.homepage    =  'https://github.com/ISS-RepoMiner/repo_miner'
  s.license     =  'MIT'

  s.add_runtime_dependency 'gems'
  s.add_runtime_dependency 'github_api'
  s.add_runtime_dependency 'httparty'
  s.add_runtime_dependency 'mongo'
  s.add_runtime_dependency 'nokogiri'

end
