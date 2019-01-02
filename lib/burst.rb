require 'rubygems'
require 'bundler'
require "bundler/setup"
Bundler.require(:default)

require "active_support/all"
require "active_support/dependencies"
require "active_record"
require "active_job"

require "pathname"
require "securerandom"
require "multi_json"

#require "gush/json"
#require "gush/cli"
#require "gush/cli/overview"
#require "gush/graph"
#require "gush/client"
require "burst/configuration"
#require "gush/errors"
#require "gush/job"

require "burst/store"
require "burst/model"
require "burst/builder"
require "burst/job"
require "burst/workflow"
require "burst/worker"

module Burst

  def self.root
    Pathname.new(__FILE__).parent.parent
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end
end
