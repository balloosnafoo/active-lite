require 'byebug'

require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    DBConnection.execute2(<<-SQL).first.map(&:to_sym)
      SELECT * FROM #{table_name}
    SQL
  end

  def self.finalize!
    columns.each do |column|
      define_method("#{column}") { attributes[column] }
      define_method("#{column}=") do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    instance_variable_set(:@table_name, table_name)
  end

  def self.table_name
    @table_name || instance_variable_set(:@table_name, self.to_s.tableize)
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT * FROM #{table_name}
    SQL

    parse_all(results)
  end

  def self.parse_all(results)
    results.each_with_object([]) do |vals_hash, objects|
      objects << new(vals_hash)
    end
  end

  def self.find(id)
    found = DBConnection.execute(<<-SQL, id).first
      SELECT * FROM #{table_name} WHERE id = ?
    SQL
    new(found) unless found.nil?
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      unless self.class.columns.include?(attr_name.to_sym)
        raise "unknown attribute '#{attr_name}'"
      end
      self.send("#{attr_name}=".to_sym, value)
    end
  end

  def attributes
    @attributes ||= Hash.new
  end

  def attribute_values
    self.class.columns.each_with_object([]) do |col, vals|
      vals << attributes[col]
    end
  end

  def insert
    col_names = self.class.columns.join(", ")
    question_marks = (["?"] * col_names.split(", ").length).join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL
    attributes[:id] = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map { |attr_name| "#{attr_name} = ?"}.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end

end
