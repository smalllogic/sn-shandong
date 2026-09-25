require "test_helper"
require "stringio"
require "tempfile"
require "zip"

class AdminCatalogTransferTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(email: "catalog-admin@example.com", password: "password123", role: "super_admin")
    sign_in @admin
  end

  test "dashboard shows catalog actions and exports a readable zip" do
    get admin_root_path
    assert_response :success
    assert_select "a[href='#{admin_catalog_export_path}']", text: /导出分类和 SKU/
    assert_select "form[action='#{admin_catalog_import_path}']"

    get admin_catalog_export_path
    assert_response :success
    assert_equal "application/zip", response.media_type

    names = nil
    Zip::File.open_buffer(StringIO.new(response.body)) do |zip|
      names = zip.entries.map(&:name)
    end
    assert_equal CatalogTransfer::FILES.sort, names.sort
  end

  test "dashboard accepts its exported archive" do
    archive = CatalogTransfer::Export.new.call
    Tempfile.create(["catalog", ".zip"]) do |file|
      file.binmode
      file.write(archive)
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "application/zip")

      post admin_catalog_import_path, params: { file: upload }
      assert_redirected_to admin_root_path
      follow_redirect!
      assert_select "[role='alert']", text: /导入完成：分类 0 条，SKU 0 条/
    end
  end
end
