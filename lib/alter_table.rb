module AlterTable
  def self.included base
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def alter_table table_name
      acc = TableOperationAccumulator.new
      yield acc
      
      execute("ALTER TABLE #{quote_table_name(table_name)} #{sql_from_accumulator(acc)}")
      acc.rename_columns.each do |(old_name, new_name)|
        rename_column table_name, old_name, new_name
      end
    end
    
    def sql_from_accumulator acc
      [ sql_from_accumulator_for_add_columns(acc),
        sql_from_accumulator_for_remove_columns(acc),
      ].compact.join(',')
    end
    
    def sql_from_accumulator_for_add_columns acc
      return nil if acc.add_columns.blank?
      
      acc.add_columns.map { |args|
        column_name = args.shift
        type        = args.shift
        options     = args.extract_options!
        
        sql = "ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        
        add_column_options!(sql, options)
        sql
      }.join(',')
    end
    
    def sql_from_accumulator_for_remove_columns acc
      return nil if acc.remove_columns.blank?
      
      acc.remove_columns.map { |column_name|
        "DROP #{quote_column_name(column_name)}"
      }.join(',')
    end
  end
  
  class TableOperationAccumulator
    attr_reader :add_columns, :remove_columns, :rename_columns
    def initialize
      @add_columns    = []
      @remove_columns = []
      @rename_columns = []
    end
    
    def add_column *args
      @add_columns << args
    end
    
    def remove_column *column_names
      @remove_columns += column_names.flatten
    end
    alias :remove_columns :remove_column
    
    def rename_column old_name, new_name
      @rename_columns << [ old_name, new_name ]
    end
  end
  
end

ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, AlterTable)
