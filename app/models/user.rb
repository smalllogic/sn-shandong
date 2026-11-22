class User < ApplicationRecord
  attr_accessor :apply_dealer

  has_many :login_logs, dependent: :destroy
  has_many :operation_logs, dependent: :destroy
  has_many :contact_messages, dependent: :nullify
  has_many :orders, dependent: :nullify

  after_commit :clear_dashboard_cache

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable, :lockable

  ROLES = %w[user editor admin super_admin].freeze
  DEALER_STATUSES = %w[none pending approved rejected].freeze

  validates :role, inclusion: { in: ROLES }
  validates :dealer_status, inclusion: { in: DEALER_STATUSES }
  before_save :sync_dealer_approval_time, if: :will_save_change_to_dealer_status?
  before_update :protect_last_super_admin, if: -> { role_in_database == "super_admin" && role != "super_admin" }
  before_destroy :protect_last_super_admin, if: :super_admin?, prepend: true

  scope :dealers, -> { where(dealer_status: %w[pending approved rejected]) }
  scope :pending_dealers, -> { where(dealer_status: 'pending') }

  def super_admin?
    role == 'super_admin'
  end

  def editor?
    role == 'editor'
  end

  def admin_role?
    ['super_admin', 'admin', 'editor'].include?(role)
  end

  def user?
    role == 'user'
  end

  def dealer?
    dealer_approved?
  end

  def dealer_pending?
    dealer_status == 'pending'
  end

  def dealer_approved?
    dealer_status == 'approved'
  end

  def dealer_rejected?
    dealer_status == 'rejected'
  end

  def dealer_applicant?
    %w[pending approved rejected].include?(dealer_status)
  end

  def approve_dealer!
    update(dealer_status: 'approved')
  end

  def reject_dealer!
    update(dealer_status: 'rejected')
  end

  def display_name
    contact_name.presence || company_name.presence || email.split('@').first
  end

  private

  def sync_dealer_approval_time
    self.dealer_approved_at = dealer_approved? ? Time.current : nil
  end

  def protect_last_super_admin
    # Serialize role removal across accounts, including concurrent deletions.
    self.class.connection.execute("SELECT pg_advisory_xact_lock(2026112201)")
    return if self.class.where(role: "super_admin").where.not(id: id).exists?

    errors.add(:base, "必须保留至少一位大管理员")
    throw :abort
  end

  def clear_dashboard_cache
    Rails.cache.delete("admin_users_count")
    Rails.cache.delete("admin_dealers_count")
    Rails.cache.delete("admin_pending_dealers_count")
  end
end
