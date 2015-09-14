class Image < ActiveRecord::Base
	belongs_to :building, touch: true
	belongs_to :unit, touch: true
  default_scope { order("priority ASC") }
  after_save :check_priority

	# This method associates the attribute ":file" with a file attachment
  has_attached_file :file, styles: {
    thumb: '100x100>',
    square: '200x200#',
    medium: '300x300>'
  }, default_url: "/images/:style/missing.png"
  process_in_background :file

  # Validate filename
  validates_attachment_file_name :file, :matches => [/png\Z/, /jpe?g\Z/, /gif\Z/, /PNG\Z/, /JPE?G\Z/, /GIF\Z/]

	# Validate the attached image content is image/jpg, image/png, etc
  validates_attachment :file,
		:presence => true,
		:content_type => { :content_type => /\Aimage\/.*\Z/ },
		:size => { :less_than => 4.megabyte }

  # class CopyResidentialUnitImages
  #   @queue = :copy_images

  #   def self.perform(src_id, dst_id)
  #     #puts "YEAAAAAA MAN #{src_id} #{dst_id}"
  #     @src = ResidentialUnit.find(src_id)
  #     @dst = ResidentialUnit.find(dst_id)

  #     # deep copy photos
  #     @src.images.each {|i| 
  #       img_copy = Image.new
  #       img_copy.file = i.file
  #       img_copy.save
  #       @dst.images << img_copy
  #     }
  #     @dst.save
  #   end
  # end

  # def self.async_copy_residential_unit_images(src_id, dst_id)
  #   #Resque.enqueue(CopyResidentialUnitImages, src_id, dst_id)
  # end

  def to_builder
    Jbuilder.new do |i|
    end
  end

  def self.reorder_by_unit(unit_id)
    images = Image.where(unit_id: unit_id).order("priority ASC")
    pos = 0
    images.each{ |x|
      if x.priority != pos
        x.update_columns(priority: pos)
      end
      pos = pos + 1
    }
  end

  def self.reorder_by_building(bldg_id)
    images = Image.where(building_id: bldg_id).order("priority ASC")
    pos = 0
    images.each{ |x|
      if x.priority != pos
        x.update_columns(priority: pos)
      end
      pos = pos + 1
    }
  end

  private

    # preserve order. keep numbers starting at 0
    def check_priority
      images = []
      if self.building_id
        Image.reorder_by_building(building_id)
      elsif self.unit_id
        Image.reorder_by_unit(unit_id)
      end
    end
end