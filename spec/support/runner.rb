require 'otr-activerecord'
require 'yaml'
require 'erb'

RSpec.configure do |config|

  root_path = File.dirname(File.dirname(__dir__))
  ActiveSupport::Dependencies.autoload_paths += [ 'models', 'lib' ].map {|f| File.join(root_path, f)}

  config.before(:suite) do
    OTR::ActiveRecord.configure_from_file! "config/database.yml"
    ActiveRecord::Base.logger = nil
  end

end
