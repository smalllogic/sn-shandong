class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.unscoped.where(parent_id: nil).order(:position, :id).includes(:children)
  end

  def show
  end

  def new
    if params[:parent_id].present?
      parent = Category.find(params[:parent_id])
      @category = Category.new(parent_id: parent.id)
    else
      @category = Category.new
    end
  end

  def edit
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to admin_categories_path, notice: '分类创建成功。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: '分类更新成功。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.parent_id.nil? && Category::ROOT_CATEGORIES.key?(@category.slug)
      redirect_to admin_categories_path, alert: '顶级分类不可删除。'
    else
      @category.destroy
      redirect_to admin_categories_path, notice: '分类已删除。'
    end
  end

  private

  def set_category
    @category = Category.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(
      :name, :name_zh, :name_en, :name_it, :name_fr,
      :slug, :parent_id, :category_kind, :hidden, :position, :featured, :featured_position, :image, :banner,
      :meta_title, :meta_title_zh, :meta_title_en, :meta_title_it, :meta_title_fr,
      :meta_description, :meta_description_zh, :meta_description_en, :meta_description_it, :meta_description_fr,
      :meta_keywords, :meta_keywords_zh, :meta_keywords_en, :meta_keywords_it, :meta_keywords_fr,
      :keywords, :keywords_zh, :keywords_en, :keywords_it, :keywords_fr
    )
  end
end
