class AddMultilingualFieldsToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :title_zh, :string
    add_column :posts, :title_it, :string
    add_column :posts, :title_fr, :string

    add_column :posts, :summary_zh, :text
    add_column :posts, :summary_it, :text
    add_column :posts, :summary_fr, :text

    add_column :posts, :meta_title_zh, :string
    add_column :posts, :meta_title_it, :string
    add_column :posts, :meta_title_fr, :string

    add_column :posts, :meta_description_zh, :text
    add_column :posts, :meta_description_it, :text
    add_column :posts, :meta_description_fr, :text

    add_column :posts, :meta_keywords_zh, :string
    add_column :posts, :meta_keywords_it, :string
    add_column :posts, :meta_keywords_fr, :string
  end
end
