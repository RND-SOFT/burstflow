require 'otr-activerecord'
require 'yaml'
require 'erb'

RSpec.configure do |config|
  #ActiveSupport::Dependencies.autoload_paths += [ 'lib' ].map {|f| File.join($root, '..', f)}

  config.before(:suite) do
    OTR::ActiveRecord.configure_from_file! 'config/database.yml'
    ActiveRecord::Base.logger = nil
  end

end
