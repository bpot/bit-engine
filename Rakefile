require 'rubygems'
require 'rake'
require 'metric_fu'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "bit-engine"
    gem.summary = %Q{A BitTorrent client built with Ruby and EventMachine}
    gem.description = %Q{A BitTorrent client build with Ruby and Eventmachine}
    gem.email = "bobby.potter@gmail.com"
    gem.homepage = "http://github.com/bpot/bit-engine"
    gem.authors = ["Bob Potter"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_dependency  "eventmachine" 
    gem.add_dependency  "thin" 
    gem.add_dependency  "sinatra" 
    gem.add_dependency  "mmap" 
    gem.add_dependency  "bencode" 
    gem.add_dependency  "json" 
    gem.add_dependency  "rest-client" 
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "bit-engine #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :daemon do
  task :start do

  end
end
