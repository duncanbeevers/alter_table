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
    assert model.column_names.include?('name')
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
