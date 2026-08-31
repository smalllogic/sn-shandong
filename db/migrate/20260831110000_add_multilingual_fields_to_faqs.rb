class AddMultilingualFieldsToFaqs < ActiveRecord::Migration[8.1]
  def change
    add_column :faq_categories, :name_zh, :text
    add_column :faq_categories, :name_it, :text
    add_column :faq_categories, :name_fr, :text

    add_column :faqs, :question_zh, :text
    add_column :faqs, :question_it, :text
    add_column :faqs, :question_fr, :text

    add_column :faqs, :answer_zh, :text
    add_column :faqs, :answer_it, :text
    add_column :faqs, :answer_fr, :text
  end
end
