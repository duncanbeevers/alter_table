TEST_ROOT = File.dirname(__FILE__)
$: << 'lib'

require 'test/unit'
require 'yaml'
require 'rubygems'
require 'active_record'

require 'ruby-debug'

ActiveRecord::Base.configurations = YAML::load(File.open(File.join(TEST_ROOT, 'database.yml')))
ActiveRecord::Base.establish_connection(:alter_table_test)

require File.join(TEST_ROOT, '../init')
