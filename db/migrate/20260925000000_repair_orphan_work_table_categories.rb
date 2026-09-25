class RepairOrphanWorkTableCategories < ActiveRecord::Migration[8.1]
  ORPHAN_SLUGS = %w[
    work-tables-600mm-deep work-tables-700mm-deep
    work-tables-with-drawers-600mm-deep work-tables-with-drawers-700mm-deep
  ].freeze

  def up
    return if select_value("SELECT id FROM categories WHERE id = 123 LIMIT 1")

    work_tables_id = select_value("SELECT id FROM categories WHERE slug = 'work-tables' LIMIT 1")
    return unless work_tables_id

    quoted_slugs = ORPHAN_SLUGS.map { |slug| connection.quote(slug) }.join(", ")
    execute <<~SQL
      UPDATE categories
      SET parent_id = #{connection.quote(work_tables_id)}
      WHERE parent_id = 123 AND slug IN (#{quoted_slugs})
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restoring an invalid parent reference would orphan these categories again"
  end
end
