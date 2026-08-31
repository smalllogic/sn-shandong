class Admin::PostsController < Admin::BaseController
  before_action :set_post, only: [ :edit, :update, :destroy ]

  def index
    @posts = Post.order(created_at: :desc)
  end

  def new
    @post = Post.new(status: "draft")
  end

  def create
    @post = Post.new(post_params)
    @post.published_at = Time.current if @post.published?
    if @post.save
      redirect_to admin_posts_path, notice: "Blog post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @post.published_at ||= Time.current if post_params[:status] == "published"
    if @post.update(post_params)
      redirect_to admin_posts_path, notice: "Blog post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_posts_path, notice: "Blog post deleted."
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(
      :title, :title_zh, :title_it, :title_fr,
      :summary, :summary_zh, :summary_it, :summary_fr,
      :content, :content_zh, :content_it, :content_fr,
      :status, :cover_image, :category, :views_count,
      :meta_title, :meta_title_zh, :meta_title_it, :meta_title_fr,
      :meta_description, :meta_description_zh, :meta_description_it, :meta_description_fr,
      :meta_keywords, :meta_keywords_zh, :meta_keywords_it, :meta_keywords_fr
    )
  end
end
