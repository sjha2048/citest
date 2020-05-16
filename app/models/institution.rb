class Institution < ActiveRecord::Base

  acts_as_yellow_pages
  title_trimmer

  validates :title, uniqueness: true
  scope :default_order, -> { order('title') }

  validates :web_page, url: {allow_nil: true, allow_blank: true}
  validates :country, :presence => true

  has_many :work_groups, dependent: :destroy, inverse_of: :institution
  has_many :projects, through: :work_groups,  inverse_of: :institutions
  has_many :programmes, -> { uniq }, through: :projects, inverse_of: :institutions
  has_many :group_memberships, through: :work_groups, inverse_of: :institutions
  has_many :people, -> { order('last_name ASC').uniq }, through: :group_memberships, inverse_of: :institutions

  searchable(auto_index: false) do
    text :city, :address
  end if Seek::Config.solr_enabled

  def can_be_edited_by?(user)
    return false if user.nil?
    user.is_admin? || self.is_managed_by?(user)
  end

  # determines if this person is the member of a project for which the user passed is a project manager
  def is_managed_by?(user)
    match = projects.find do |p|
      user.person.is_project_administrator?(p)
    end
    !match.nil?
  end

  # get a listing of all known institutions
  def self.get_all_institutions_listing
    Institution.all.collect { |i| [i.title, i.id] }
  end

  def can_delete?(user = User.current_user)
    user.nil? ? false : (user.is_admin? && work_groups.collect(&:people).flatten.empty?)
  end

  def self.can_create?
    true
    #User.admin_or_project_administrator_logged_in? ||
      #User.activated_programme_administrator_logged_in?
  end
  
end
