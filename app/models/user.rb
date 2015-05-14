class User < ActiveRecord::Base
  rolify
  belongs_to :office
  belongs_to :company
  belongs_to :manager, :class_name => "User"
  belongs_to :employee_title
  has_many :subordinates, :class_name => "User", :foreign_key => "manager_id"
  attachment :avatar #, extension: ["jpg", "jpeg", "png", "gif"]

	attr_accessor :remember_token, :activation_token, :reset_token, :agent_types
  before_create :create_activation_digest
  before_save :downcase_email
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
	validates :email, presence: true, length: {maximum: 100}, 
						format: { with: VALID_EMAIL_REGEX }, 
            uniqueness: { case_sensitive: false }

  validates :name, presence: true, length: {maximum: 50}
            #uniqueness: { case_sensitive: false }
	has_secure_password
	validates :password, length: { minimum: 6 }, allow_blank: true

	# Returns the hash digest of the given string.
  def User.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                  BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  # Returns a random token.
  def User.new_token
    SecureRandom.urlsafe_base64
  end

  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # Returns true if the given token matches the digest.
  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?
    BCrypt::Password.new(digest).is_password?(token)
  end

  # Forgets a user.
  def forget
    update_attribute(:remember_digest, nil)
  end

  # Activates an account.
  def activate
    update_columns(activated: true, activated_at: Time.zone.now)
  end

  def fname
    self.name.split(' ')[0]
  end

  # Sends activation email.
  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  # Sets the password reset attributes.
  def create_reset_digest
    self.reset_token = User.new_token
    update_columns(reset_digest:  User.digest(reset_token),
                   reset_sent_at: Time.zone.now)
  end

  # Sends password reset email.
  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  # Returns true if a password reset has expired.
  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  def self.search(query_string)
    @running_list = User.all

    if !query_string
      return @running_list
    end
    
    @terms = query_string.split(" ")
    @terms.each do |term|
      #puts "**** #{term} ****\n"
      term = "%#{term}%"
      @running_list = @running_list.where('name ILIKE ? or email ILIKE ?', "%#{term}%", "%#{term}%").all
    end

    @running_list.uniq
  end

  #def avatar_thumbnail_url
  #  return S3_AVATAR_THUMBNAIL_BUCKET.objects[self.avatar_key].url_for(:read).to_s
  #end

  #def avatar_url
  #  return S3_AVATAR_BUCKET.url + self.avatar_key
  #end

  # copies in new roles from 
  # user.agent_types & user.employee_title
  def update_roles
    # clear out old roles
    self.roles = [];
    
    # add a role representing your position in the company.
    # default to an agent if none otherwise specified
    if !self.employee_title
      self.employee_title = EmployeeTitle.agent
    end
    self.save

    # if you're an agent, add in specific roles for the type of
    # agent that you are
    if self.employee_title == EmployeeTitle.agent
      # always make sure they at least have one area selected
      if !self.agent_types || self.agent_types.length == 0
        self.add_role :residential_agent
      else
        for role in self.agent_types do
          @real_role_name = role.downcase.gsub(' ', '_')
          self.add_role @real_role_name
        end
      end
    else 
      self.add_role self.employee_title.name
    end
  end

  def is_manager?
    self.has_role? :manager
  end

  def is_company_admin?
    self.has_role? :company_admin
  end

  def make_manager
    self.add_role :manager
  end

  def remove_manager
    subordinates.clear
    self.remove_role :manager
  end

  def add_subordinate(subord)
    if self.has_role? :manager
      subord.manager = self
      subord.save
      #puts "#{subord.manager.name} "
      #puts "#{subord.manager.subordinates.length} \n\n"
    else
      raise 'Tried to add subordinate without being manager first'  
    end
  end

  def remove_subordinate(subord)
    if self.has_role? :manager
      subord.manager = nil
    else
      raise 'Tried to remove subordinate without being manager first'  
    end
  end

  def is_management?
    if (has_role? :company_admin) || 
      (has_role? :operations) ||
      (has_role? :broker) || 
      (has_role? :associate_broker) ||
      (has_role? :manager)
      true
    else 
      false
    end    
  end

  def coworkers
    @coworkers = Array.new(self.company.users)
    @coworkers.delete(self)
    @coworkers
  end

  # this is just so we can define the busines logic in a centralized place.
  # this is a non-functional user
  def self.define_roles
    @user = User.create({
      email: 'topsecret@admin.com', 
      name: "Roles Definition",
      password:"test123" });
    # Inactive Agent:
    @user.add_role :inactive_agent
    # Licensed Agent:
    @user.add_role :residential_agent
    @user.add_role :commercial_agent
    @user.add_role :sales_agent
    @user.add_role :roomsharing_agent
    @user.add_role :associate_broker
    @user.add_role :broker
    # Executive Agent:
    @user.add_role :manager
    @user.add_role :closing_manager
    @user.add_role :marketing
    @user.add_role :operations
    @user.add_role :company_admin
    # Not for nestio:
    @user.add_role :super_admin

    @user.delete
  end

  def agent_specialties
    @specialities = []
    AgentType.all.each do |a|
      if self.has_role? a.name + "_agent"
        @specialities << a.name.titleize
      end
    end

    @specialities
  end


  private

    # Converts email to all lower-case.
    def downcase_email
      self.email = email.downcase
    end
    
    def create_activation_digest
      # Create the token and digest.
      self.activation_token  = User.new_token
      self.activation_digest = User.digest(activation_token)
    end



end
