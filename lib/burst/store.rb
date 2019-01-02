class Burst::Store < ActiveRecord::Base
  self.table_name_prefix = 'burst_'

  class JSONBWithIndifferentAccess
    def self.dump(hash)
      hash.as_json
    end
  
    def self.load(hash)
      hash ||= {}
      hash = JSON.parse(hash) if hash.is_a? String
      hash.with_indifferent_access
    end
  end

  serialize :flow, JSONBWithIndifferentAccess

  after_initialize do
    self.id ||= SecureRandom.uuid
  end
end
