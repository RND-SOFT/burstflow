require 'rubygems'
require 'bundler'
require 'bundler/setup'
Bundler.require(:default)

require 'active_support/all'
require 'active_support/dependencies'
require 'active_record'
require 'active_job'

require 'pathname'
require 'securerandom'

require 'burst/configuration'
require 'burst/model'
require 'burst/builder'
require 'burst/manager'
require 'burst/job'
require 'burst/workflow_helper'
require 'burst/workflow'
require 'burst/worker'

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
