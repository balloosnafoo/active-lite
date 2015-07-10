require_relative '03_associatable'

# Phase IV
module Associatable
  # Remember to go back to 04_associatable to write ::assoc_options

  def has_one_through(name, through_name, source_name)
    through_options = assoc_options[through_name]
    source_options = through_options.model_class.assoc_options[source_name]

    source_table = source_options.model_class.table_name
    through_table = through_options.model_class.table_name

    define_method(name) do
      result = DBConnection.execute(<<-SQL, send(through_options.foreign_key))
        SELECT
          #{source_table}.*
        FROM
          #{source_table}
        JOIN
          #{through_table} ON
            #{through_table}.#{through_options.primary_key} =
            #{source_table}.#{source_options.primary_key}
        WHERE
          #{through_table}.#{through_options.primary_key} = ?
      SQL
      source_options.model_class.new(result.first)
    end
  end
end


# SELECT
#   houses.*
# FROM
#   humans
# JOIN
#   houses ON humans.house_id = houses.id
# WHERE
#   humans.id = ?
