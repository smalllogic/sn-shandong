# Run with: bin/rails runner script/import_sqlite_to_postgresql.rb PATH_TO_SNAPSHOT
# Copies application data without callbacks, email, jobs, or attachment uploads.
require "sqlite3"
require "digest"

abort "Only development imports are allowed" unless Rails.env.development?
abort "Expected a PostgreSQL destination" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
snapshot = ARGV.fetch(0) { abort "Supply a SQLite snapshot path" }
abort "Snapshot does not exist" unless File.file?(snapshot)

class LegacySnapshot < ActiveRecord::Base
  self.abstract_class = true
end
LegacySnapshot.establish_connection(adapter: "sqlite3", database: File.expand_path(snapshot), readonly: true)
source = LegacySnapshot.connection
target = ActiveRecord::Base.connection
tables = source.tables - %w[schema_migrations ar_internal_metadata sqlite_sequence]
abort "Destination is missing tables" unless (tables - target.tables).empty?
abort "Destination must be empty" if tables.any? { |table| target.select_value("SELECT COUNT(*) FROM #{target.quote_table_name(table)}").to_i.positive? }

# Insert parent tables before their foreign-key dependents.
ordered = []
remaining = tables.dup
until remaining.empty?
  ready = remaining.select do |table|
    (target.foreign_keys(table).map(&:to_table) & remaining).empty?
  end
  abort "Cyclic foreign keys require an explicit import plan" if ready.empty?
  ordered.concat(ready)
  remaining -= ready
end

def canonical(value)
  case value
  when Hash then value.keys.sort.to_h { |key| [key, canonical(value[key])] }
  when Array then value.map { |item| canonical(item) }
  when Time, DateTime then value.utc.iso8601(6)
  when Date then value.iso8601
  when BigDecimal then value.to_s("F")
  else value
  end
end

target.transaction do
  ordered.each do |table|
    legacy_model = Class.new(LegacySnapshot) { self.table_name = table; self.inheritance_column = :_disabled_sti }
    target_model = Class.new(ActiveRecord::Base) { self.table_name = table; self.inheritance_column = :_disabled_sti }
    expected = Digest::SHA256.new
    copied = 0
    legacy_model.unscoped.order(:id).find_in_batches(batch_size: 500) do |records|
      rows = records.map(&:attributes)
      rows.each { |row| expected.update(JSON.generate(canonical(row))) }
      target_model.insert_all!(rows, record_timestamps: false)
      copied += rows.length
    end
    actual = Digest::SHA256.new
    target_model.unscoped.order(:id).find_each do |record|
      actual.update(JSON.generate(canonical(record.attributes)))
    end
    unless target_model.count == copied && actual.hexdigest == expected.hexdigest
      raise "Verification failed for #{table}; rolling back the import"
    end
    target.reset_pk_sequence!(table)
    puts "#{table}: #{copied} rows verified"
  end
end
puts "Import verified and committed. IDs and attachment references preserved."
