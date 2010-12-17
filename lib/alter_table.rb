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
      puts acc.report if ActiveRecord::Migration.verbose
      
      execute("ALTER TABLE %s %s" % [
        quote_table_name(table_name),
        acc.sql
      ])
    end
  end
  
  class TableOperationAccumulator
    CHANGE_COLUMN_SQL = "CHANGE COLUMN %s %s %s"
    
    attr_reader :ar_class, :column_defs
    delegate :quote_column_name, :quote_table_name, :index_name,
             :type_to_sql, :add_column_options!, :select,
             :to => :ar_class
    
    def initialize(table_name, ar_class)
      @table_name = table_name
      @ar_class   = ar_class
      @operations = []
      load_column_defs
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
    
    def add_index column_name_or_names, options = {}
      column_names = Array(column_name_or_names)
      index_name = options[:name] || index_name(@table_name, :column => column_names)
      @operations << [ :add_index, [ index_name, column_names, options ] ]
    end
    
    def remove_index index_name
      @operations << [ :remove_index, [ index_name ] ]
    end

    def change_column *args
      column_name = args.shift
      type        = args.shift
      options     = args.extract_options!
      @operations << [ :change_column, [ column_name, type, options ] ]
    end
    
    def sql
      @operations.map { |(m, payload)| method('sql_for_%s' % m).call(*payload) }.
        select { |s| !s.blank? }.join(',')
    end
    
    def report
      @operations.map { |(m, payload)| method('report_for_%s' % m).call(*payload) }.
        select { |s| !s.blank? }
    end
    
    private
    def sql_for_add_column(column_name, type, options)
      sql = "ADD %s %s" % [
        quote_column_name(column_name),
        type_to_sql(type, options[:limit], options[:precision], options[:scale])
      ]
      
      # define nullability and defaults
      add_column_options!(sql, options)
      sql
    end
    
    def sql_for_remove_column(column_name)
      "DROP %s" % quote_column_name(column_name)
    end

    def sql_for_rename_column(old_name, new_name)
      CHANGE_COLUMN_SQL % [
        quote_column_name(old_name),
        quote_column_name(new_name),
        column_defs[old_name.to_s]
      ]
    end
    
    def sql_for_add_index(index_name, column_names, options)
      index_type = options[:unique] ? 'UNIQUE' : ''
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

    def sql_for_change_column(column_name, type, options)
      sql = CHANGE_COLUMN_SQL % [
        quote_column_name(column_name),
        quote_column_name(column_name),
        type_to_sql(type, options[:limit], options[:precision], options[:scale])
      ]

      # define nullability and defaults
      add_column_options!(sql, options)
      sql
    end
    
    def report_for_add_column(column_name, type, options)
      "  A %-24s :%s %s" % [
        column_name,
        type,
        options.blank? ? nil : options.inspect
      ]
    end
    
    def report_for_remove_column(column_name)
      "  D %s" % [ column_name ]
    end
    
    def report_for_rename_column(old_name, new_name)
      "  M %s\t->\t%s" % [
        old_name,
        new_name
      ]
    end

    def report_for_change_column(column_name, type, options)
      old_type = column_defs[column_name.to_s]
      " M %s %s\t->\t%s %s" % [
        column_name,
        old_type,
        column_name,
        type_to_sql(type, options[:limit], options[:precision], options[:scale])
      ]
    end
    
    def report_for_add_index(index_name, column_names, options)
      "  Add index: %s\t[ %s ]\t%s" % [
        index_name,
        column_names.join(' '),
        options.blank? ? nil : options.inspect
      ]
    end
    
    def report_for_remove_index(index_name)
      "  Remove index: %s" % index_name
    end

    def load_column_defs
      @column_defs = select("SHOW COLUMNS FROM %s" % quote_table_name(@table_name)).inject({}) do |a, c|
        a[c['Field']] = c['Type']
        a
      end
    end
  end
  
end

ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, AlterTable)
