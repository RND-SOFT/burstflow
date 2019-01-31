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

require 'burstflow/configuration'
require 'burstflow/model'
require 'burstflow/helpers'
require 'burstflow/helpers/builder'
require 'burstflow/manager'
require 'burstflow/job'
require 'burstflow/workflow_helper'
require 'burstflow/workflow'
require 'burstflow/worker'

module Burstflow

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
