TEST_ROOT = File.dirname(__FILE__)
$: << 'lib'

require 'test/unit'
require 'yaml'
require 'rubygems'
require 'active_record'

require 'ruby-debug'

ActiveRecord::Base.configurations = YAML::load(File.open(File.join(TEST_ROOT, 'database.yml')))
ActiveRecord::Base.establish_connection(:alter_table_test)

# Cribbed from Rails tests
ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /SHOW FIELDS/]
  
  def execute_with_query_record(sql, name = nil, &block)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SQL.any? { |r| sql =~ r }
    execute_without_query_record(sql, name, &block)
  end
  
  alias_method_chain :execute, :query_record
end

require File.join(TEST_ROOT, '../init')
