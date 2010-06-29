module AlterTable
  def self.included base
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def alter_table table_name
      acc = TableOperationAccumulator.new(table_name, self)
      yield acc
      
      report_operations(acc) if ActiveRecord::Migration.verbose
      execute("ALTER TABLE %s %s" % [
        quote_table_name(table_name),
        acc.sql
      ])
    end
    
    def report_operations(acc)
      # if !acc.add_columns.blank?
      #   puts "* Adding columns:\n%s" %
      #     acc.add_columns.map { |ac| "\t%s" % ac.map { |c| c.inspect } }.join("\n")
      # end
      # if !acc.remove_columns.blank?
      #   puts "* Removing columns: %s" %
      #     acc.remove_columns.map { |rc| "\t%s" % rc.inspect }.join("\n")
      # end
    end
  end
  
  class TableOperationAccumulator
    attr_reader :ar_class
    delegate :quote_column_name, :quote_table_name, :index_name,
             :type_to_sql, :add_column_options!, :select,
             :to => :ar_class
    
    def initialize(table_name, ar_class)
      @table_name = table_name
      @ar_class   = ar_class
      @operations = []
    end
    
    def add_column *args
      column_name = args.shift
      type        = args.shift
      options     = args.extract_options!
      
      @operations << [ :add_column, [ column_name, type, options ] ]
    end
    
    def remove_column *column_names
      @operations << [ :remove_column, column_names.flatten ]
    end
    alias :remove_columns :remove_column
    
    def rename_column old_name, new_name
      @operations << [ :rename_column, [ old_name, new_name ] ]
    end
    
    def add_index column_names, options = {}
      @operations << [ :add_index, [ Array(column_names), options ] ]
    end
    
    def remove_index index_name
      @operations << [ :remove_index, [ index_name ] ]
    end
    
    def sql
      @operations.map { |(m, payload)| method('sql_for_%s' % m).call(*payload) }.
        select { |s| !s.blank? }.join(',')
    end
    
    private
    def sql_for_add_column(column_name, type, options)
      sql = "ADD %s %s" % [
        quote_column_name(column_name),
        type_to_sql(type, options[:limit], options[:precision], options[:scale])
      ]
      
      add_column_options!(sql, options)
      sql
    end
    
    def sql_for_remove_column(column_name)
      "DROP %s" % quote_column_name(column_name)
    end
    
    def sql_for_rename_column(old_name, new_name)
      @col_defs ||= select("SHOW COLUMNS FROM %s" % quote_table_name(@table_name)).inject({}) do |a, c|
        a[c['Field']] = c['Type']
        a
      end
      
      "CHANGE %s %s %s" % [
        quote_column_name(old_name),
        quote_column_name(new_name),
        @col_defs[old_name.to_s]
      ]
    end
    
    def sql_for_add_index(column_names, options)
      index_type = options[:unique] ? 'UNIQUE' : ''
      index_name = options[:name] || index_name(@table_name, :column => column_names)
      quoted_column_names = column_names.map { |c| quote_column_name(c) }.join(',')
      "ADD %s INDEX %s (%s)" % [
        index_type,
        quote_column_name(index_name),
        quoted_column_names
      ]
    end
    
    def sql_for_remove_index(index_name)
      "DROP INDEX %s" % [ quote_column_name(index_name) ]
    end
  end
  
end

ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, AlterTable)
