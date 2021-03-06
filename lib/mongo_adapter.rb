if defined?(gem)
  gem 'dm-core', '~> 0.10.2'
  gem 'mongo', '~> 0.18'
end

require 'dm-core'
require 'dm-aggregates'
require 'mongo'

dir = Pathname(__FILE__).dirname.expand_path / 'mongo_adapter'

require dir / 'query'
require dir / 'query' / 'java_script'
require dir / 'conditions'
require dir / 'modifier'
require dir / 'property'
require dir / 'types' / 'discriminator'
require dir / 'types' / 'object_id'
require dir / 'types' / 'db_ref'
require dir / 'types' / 'objects'

require dir / 'model' / 'embedment'
require dir / 'model'

require dir / 'resource'
require dir / 'migrations'

require dir / 'embedments' / 'relationship'
require dir / 'embedments' / 'one_to_one'
require dir / 'embedments' / 'one_to_many'

require dir / 'embedded_model'
require dir / 'embedded_resource'

require dir / 'aggregates'
require dir / 'adapter'
