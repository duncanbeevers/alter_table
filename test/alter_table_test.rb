require File.join(File.dirname(__FILE__), 'test_helper')

class AlterTableTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.connection.create_table('users') do |t|
    end
  end
  
  def teardown
    ActiveRecord::Base.connection.drop_table('users')
  end
  
  def alter_model_table
    ActiveRecord::Base.connection.alter_table(model.table_name) do |t|
      yield(t)
    end
  end
end

def model
  returning Class.new(ActiveRecord::Base) do |c|
    c.table_name = 'users'
  end
end
