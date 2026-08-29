class AddMultiLanguageFieldsToCategoriesAndSkus < ActiveRecord::Migration[7.0]
  def change
    # Categories
    add_column :categories, :name_en, :string
    add_column :categories, :name_it, :string
    add_column :categories, :name_fr, :string
    
    add_column :categories, :meta_title_zh, :string
    add_column :categories, :meta_title_en, :string
    add_column :categories, :meta_title_it, :string
    add_column :categories, :meta_title_fr, :string
    
    add_column :categories, :meta_description_zh, :text
    add_column :categories, :meta_description_en, :text
    add_column :categories, :meta_description_it, :text
    add_column :categories, :meta_description_fr, :text
    
    add_column :categories, :meta_keywords_zh, :string
    add_column :categories, :meta_keywords_en, :string
    add_column :categories, :meta_keywords_it, :string
    add_column :categories, :meta_keywords_fr, :string

    # Skus
    add_column :skus, :name_zh, :string
    add_column :skus, :name_en, :string
    add_column :skus, :name_it, :string
    add_column :skus, :name_fr, :string
    
    add_column :skus, :meta_title_zh, :string
    add_column :skus, :meta_title_en, :string
    add_column :skus, :meta_title_it, :string
    add_column :skus, :meta_title_fr, :string
    
    add_column :skus, :meta_description_zh, :text
    add_column :skus, :meta_description_en, :text
    add_column :skus, :meta_description_it, :text
    add_column :skus, :meta_description_fr, :text
    
    add_column :skus, :meta_keywords_zh, :string
    add_column :skus, :meta_keywords_en, :string
    add_column :skus, :meta_keywords_it, :string
    add_column :skus, :meta_keywords_fr, :string
    
    add_column :categories, :keywords_zh, :string
    add_column :categories, :keywords_en, :string
    add_column :categories, :keywords_it, :string
    add_column :categories, :keywords_fr, :string
  end
end
