require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'

DataMapper::Model.raise_on_save_failure = true

require './lib/models/link'

DataMapper.finalize
DataMapper.auto_upgrade!
