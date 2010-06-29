require File.join(File.dirname(__FILE__), 'test_helper')

class AlterTableTest < ActiveRecord::TestCase
  def setup
    create_model_table!
  end
  
  def teardown
    drop_model_table
  end
  
  def test_add_column
    alter_model_table do |t|
      t.add_column 'name', :string
    end
    assert_column 'name', :string
  end
  
  def test_remove_column
    add_age_column
    alter_model_table do |t|
      t.remove_column 'age'
    end
    assert_no_column 'age'
  end
  
  def test_rename_column
    add_age_column
    alter_model_table do |t|
      t.rename_column 'age', 'years_old'
    end
    assert_column 'years_old', :integer
    assert_no_column 'age'
  end
  
  def test_rename_column_symbol
    add_age_column
    alter_model_table do |t|
      t.rename_column :age, :years_old
    end
    assert_column 'years_old', :integer
    assert_no_column 'age'
  end
  
  def test_add_multiple_columns
    assert_queries(1) do
      alter_model_table do |t|
        t.add_column 'name', :string
        t.add_column 'age',  :integer
      end
    end
  end
  
  def test_add_index
    add_age_column
    alter_model_table do |t|
      t.add_index [ 'age' ], :unique => true
    end
    assert_index 'index_users_on_age',
      :unique  => true,
      :columns => [ 'age' ]
  end
  
  def test_remove_index
    add_indexed_age_column
    alter_model_table do |t|
      t.remove_index 'index_users_on_age'
    end
    assert_no_index 'index_users_on_age'
  end
  
  private
    def create_model_table
      ActiveRecord::Base.connection.create_table('users') do |t|
      end
    end
    
    def create_model_table!
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
    
    def drop_model_table
      ActiveRecord::Base.connection.drop_table('users')
    end
    
    def alter_model_table
      ActiveRecord::Base.connection.alter_table(model.table_name) do |t|
        yield(t)
      end
    end
    
    def add_age_column
      alter_model_table do |t|
        t.add_column 'age', :integer
      end
      assert_column 'age', :integer
    end
    
    def add_indexed_age_column
      add_age_column
      alter_model_table do |t|
        t.add_index [ 'age' ], :unique => true
      end
      assert_index 'index_users_on_age',
        :unique  => true,
        :columns => [ 'age' ]
    end
    
    def assert_column name, expected_type, options = {}
      column = model.columns.find { |c| name == c.name }
      flunk "Expected column %s was not found" % name unless column
      assert_equal expected_type, column.type
      assert_equal options[:default],   column.default   if options.has_key?(:default)
      assert_equal options[:primary],   column.primary   if options.has_key?(:primary)
      assert_equal options[:sql_type],  column.sql_type  if options.has_key?(:sql_type)
      assert_equal options[:limit],     column.limit     if options.has_key?(:limit)
      assert_equal options[:scale],     column.scale     if options.has_key?(:scale)
      assert_equal options[:precision], column.precision if options.has_key?(:precision)
    end
    
    def assert_no_column name
      column = model.columns.find { |c| name == c.name }
      assert_nil column, "Expected not to have found a column %s" % name
    end
    
    def assert_index name, options = {}
      index = ActiveRecord::Base.connection.indexes(model.table_name).find { |c| name == c.name }
      flunk "Expected index %s was not found" % name unless index
      assert_equal options[:unique],  index.unique  if options.has_key?(:unique)
      assert_equal options[:columns], index.columns if options.has_key?(:columns)
    end
    
    def assert_no_index name
      index = ActiveRecord::Base.connection.indexes(model.table_name).find { |c| name == c.name }
      assert_nil index, "Expected not to have found an index %s" % name
    end
end

def model
  returning Class.new(ActiveRecord::Base) do |c|
    c.table_name = 'users'
  end
end
