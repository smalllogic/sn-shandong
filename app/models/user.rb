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

  scope :dealers, -> { where(dealer_status: ['pending', 'approved', 'rejected']).or(where(role: 'dealer')) }
  scope :pending_dealers, -> { where(dealer_status: 'pending') }

  def super_admin?
    role == 'super_admin' || admin
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
    role == 'dealer' || dealer_status == 'approved'
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
    ['pending', 'approved', 'rejected'].include?(dealer_status) || role == 'dealer'
  end

  def approve_dealer!
    update(role: 'dealer', dealer_status: 'approved', dealer_approved_at: Time.current)
  end

  def reject_dealer!
    update(dealer_status: 'rejected')
  end

  def display_name
    contact_name.presence || company_name.presence || email.split('@').first
  end

  private

  def clear_dashboard_cache
    Rails.cache.delete("admin_users_count")
    Rails.cache.delete("admin_dealers_count")
    Rails.cache.delete("admin_pending_dealers_count")
  end
end
