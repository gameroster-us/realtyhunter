class Unit < ActiveRecord::Base
	actable

	belongs_to :building, touch: true
  belongs_to :primary_agent, :class_name => 'User', touch: true
  belongs_to :listing_agent, :class_name => 'User', touch: true
  has_many :images, dependent: :destroy
  # before_validation :generate_unique_id

  scope :unarchived, ->{ where(archived: false) }
  scope :active, ->{ where(status: "active") }
  #scope :residential, ->{ where("actable_type = 'ResidentialUnit'") }
  #scope :commercial, ->{ where("actable_type = 'CommercialUnit'") }

	enum status: [ :active, :pending, :off ]
  scope :on_market, ->{where.not(status: Unit.statuses["off"])}
	validates :status, presence: true, inclusion: { in: %w(active pending off) }
	
	validates :rent, presence: true, numericality: { only_integer: true }
	validates :listing_id, presence: true, uniqueness: true
	
  validates :building, presence: true
  validates :building_unit, allow_blank: true, length: {maximum: 50}

  def archive
    self.archived = true
    self.save
  end

  def self.find_unarchived(id)
    find_by!(id: id, archived: false)
  end

end