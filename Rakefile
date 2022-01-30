# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task :update_arm2sim do
  source_url = 'https://raw.githubusercontent.com/bogo/arm64-to-sim/main/Sources/arm64-to-sim/main.swift'
  destination_path = 'lib/arm2sim.swift'
  sh "curl \"#{source_url}\" -o \"#{destination_path}\""
end

task default: %i[spec rubocop]
