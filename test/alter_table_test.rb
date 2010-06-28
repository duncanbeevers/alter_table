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
    assert_column 'name', :string
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
    
    def assert_column name, expected_type, options = {}
      column = model.columns.find { |c| name == c.name }
      flunk "Expected column %s not found" % name unless name
      assert_equal expected_type, column.type
      assert_equal options[:default],   column.default   if options.has_key?(:default)
      assert_equal options[:primary],   column.primary   if options.has_key?(:primary)
      assert_equal options[:sql_type],  column.sql_type  if options.has_key?(:sql_type)
      assert_equal options[:limit],     column.limit     if options.has_key?(:limit)
      assert_equal options[:scale],     column.scale     if options.has_key?(:scale)
      assert_equal options[:precision], column.precision if options.has_key?(:precision)
    end
    
end

def model
  returning Class.new(ActiveRecord::Base) do |c|
    c.table_name = 'users'
  end
end
