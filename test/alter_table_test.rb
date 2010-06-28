require File.join(File.dirname(__FILE__), 'test_helper')

class AlterTableTest < ActiveRecord::TestCase
  def setup
    @retry = true
    ActiveRecord::Migration.verbose = false
    begin
      create_model_table
    rescue ActiveRecord::StatementInvalid
      drop_model_table
      if @retry
        @retry = false
        retry
      end
    end
  end
  
  def teardown
    drop_model_table
  end
  
  def test_add_column
    assert_queries(1) do
      alter_model_table do |t|
        t.add_column 'name', :string
      end
    end
    name_column = model.columns.find do |c|
      'name' == c.name
    end
    assert_equal :string, name_column.type
    assert_equal nil, name_column.default
    assert_equal false, name_column.primary
    assert_equal 'varchar(255)', name_column.sql_type
    assert_equal 255, name_column.limit
    assert_equal nil, name_column.scale
    assert_equal nil, name_column.precision
  end
  
  private
    def create_model_table
      ActiveRecord::Base.connection.create_table('users') do |t|
      end
    end
    
    def drop_model_table
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
