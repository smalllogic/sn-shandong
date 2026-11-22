class Order < ApplicationRecord
  belongs_to :user, optional: true
  has_many :order_items, dependent: :destroy
  validates :name, :country, :phone, :email, presence: true

  validates :status, inclusion: { in: %w[pending replied] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def self.statuses
    { 'pending' => 'pending', 'replied' => 'replied' }
  end

  def pending?
    status == 'pending'
  end

  def replied?
    status == 'replied'
  end
end
