require 'test_helper'

class CategoryImportTest < ActiveSupport::TestCase
  def setup
    @csv_file = Tempfile.new(['categories', '.csv'])
    @csv_file.write("\xEF\xBB\xBFID,名称(ZH),名称(EN),Slug,父级ID,分类类型,排序,是否显示,是否推荐,推荐排序\n")
    @csv_file.write(",测试分类,Test Category,test-category,,refrigeration,1,是,否,0\n")
    @csv_file.close
  end

  def teardown
    @csv_file.unlink
  end

  test "should import category from csv" do
    assert_difference 'Category.count', 1 do
      service = CategoryImportService.new(@csv_file.path)
      result = service.call
      assert_equal 1, result[:success]
      assert_empty result[:errors]
    end

    category = Category.find_by(slug: 'test-category')
    assert_not_nil category
    assert_equal '测试分类', category.name_zh
    assert_equal 'refrigeration', category.category_kind
  end

  test "should update existing category if slug matches" do
    existing = Category.create!(name: 'Old Name', slug: 'test-category', name_zh: '旧名称', category_kind: 'refrigeration')
    
    service = CategoryImportService.new(@csv_file.path)
    result = service.call
    
    assert_equal 1, result[:success]
    existing.reload
    assert_equal '测试分类', existing.name_zh
  end
end
