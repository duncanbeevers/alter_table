module AlterTable
  def self.included base
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def alter_table table_name
      acc = TableOperationAccumulator.new(table_name)
      yield acc
      
      report_operations(acc) if ActiveRecord::Migration.verbose
      execute("ALTER TABLE #{quote_table_name(table_name)} #{sql_from_accumulator(acc)}")
    end
    
    def report_operations(acc)
      if !acc.add_columns.blank?
        puts "* Adding columns:\n%s" %
          acc.add_columns.map { |ac| "\t%s" % ac.map { |c| c.inspect } }.join("\n")
      end
      if !acc.remove_columns.blank?
        puts "* Removing columns: %s" %
          acc.remove_columns.map { |rc| "\t%s" % rc.inspect }.join("\n")
      end
    end
    
    def sql_from_accumulator acc
      [ sql_from_accumulator_for_add_columns(acc),
        sql_from_accumulator_for_remove_columns(acc),
        sql_from_accumulator_for_add_indexes(acc),
        sql_from_accumulator_for_remove_indexes(acc),
        sql_from_accumulator_for_rename_columns(acc)
      ].select { |s| !s.blank? }.join(',')
    end
    
    def sql_from_accumulator_for_add_columns acc
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
      acc.remove_columns.map { |column_name|
        "DROP #{quote_column_name(column_name)}"
      }.join(',')
    end
    
    def sql_from_accumulator_for_add_indexes acc
      acc.add_indexes.map { |column_names, options|
        index_type = options[:unique] ? 'UNIQUE' : ''
        index_name = options[:name] || index_name(acc.table_name, :column => column_names)
        quoted_column_names = column_names.map { |c| quote_column_name(c) }.join(',')
        "ADD %s INDEX %s (%s)" % [
          index_type,
          quote_column_name(index_name),
          quoted_column_names
        ]
      }.join(',')
    end
    
    def sql_from_accumulator_for_remove_indexes acc
      acc.remove_indexes.map { |index_name|
        "DROP INDEX %s" % [ quote_column_name(index_name) ]
      }
    end
    
    def sql_from_accumulator_for_rename_columns acc
      return nil if acc.rename_columns.blank?
      
      col_defs = select("SHOW COLUMNS FROM #{quote_table_name(acc.table_name)}").inject({}) do |a, c|
        a[c['Field']] = c['Type']
        a
      end
      
      acc.rename_columns.map { |old_name, new_name|
        current_type = 
        "CHANGE %s %s %s" % [
          quote_column_name(old_name),
          quote_column_name(new_name),
          col_defs[old_name]
        ]
      }
    end
  end
  
  class TableOperationAccumulator
    attr_reader :table_name,
                :add_columns, :remove_columns, :rename_columns,
                :add_indexes, :remove_indexes
    
    def initialize(table_name)
      @table_name     = table_name
      @add_columns    = []
      @remove_columns = []
      @rename_columns = []
      @add_indexes    = []
      @remove_indexes = []
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
    
    def add_index column_names, options = {}
      @add_indexes << [ Array(column_names), options ]
    end
    
    def remove_index index_name
      @remove_indexes << index_name
    end
  end
  
end

ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, AlterTable)
