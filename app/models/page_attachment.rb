class PageAttachment < ActiveRecord::Base
  acts_as_list :scope => :page_id
  has_attachment :storage => :file_system,
  :thumbnails => defined?(PAGE_ATTACHMENT_SIZES) && PAGE_ATTACHMENT_SIZES || {:icon => '50x50>'},
  :max_size => 10.megabytes,
  :path_prefix => 'public'

  validates_as_attachment

  after_resize do |page_attachment, img|
    unless page_attachment.thumbnail == 'icon'
      page_attachment.with_image do |img|
        if page_attachment.respond_to?(:apply_rounded_corners!)
          page_attachment.instance_eval {apply_rounded_corners! img}
        end
      end
    end
    page_attachment.pngize!
  end

  belongs_to :created_by,
  :class_name => 'User',
  :foreign_key => 'created_by'
  belongs_to :updated_by,
  :class_name => 'User',
  :foreign_key => 'updated_by'
  belongs_to :page

  attr_accessible :title, :description, :screen_gallery_attachment_type

  def short_filename(wanted_length = 15, suffix = ' ...')
    (self.filename.length > wanted_length) ? (self.filename[0,(wanted_length - suffix.length)] + suffix) : self.filename
  end

  def short_title(wanted_length = 15, suffix = ' ...')
    (self.title.length > wanted_length) ? (self.title[0,(wanted_length - suffix.length)] + suffix) : self.title
  end

  def short_description(wanted_length = 15, suffix = ' ...')
    (self.description.length > wanted_length) ? (self.description[0,(wanted_length - suffix.length)] + suffix) : self.description
  end

  def any_source_files_missing?
    if self.image?
      [nil, :thumb, :icon].any? {|t| source_file_missing?(t)}
    else
      source_file_missing?()
    end
  end

  def source_file_missing?(thumbnail = nil)
    !File.exist?(full_filename(thumbnail))
  end

  # Let's customize this bad boy
  def full_filename(thumbnail = nil)
    File.join(RAILS_ROOT, file_system_path(thumbnail), *partitioned_path(thumbnail, thumbnail_name_for(thumbnail)))
  end

  def file_system_path(thumbnail = nil)
    (thumbnail ? thumbnail_class : self).attachment_options[:path_prefix].to_s
  end

  def partitioned_path(thumbnail = nil, *args)
    # Let's just assume one level deep
    the_page = (self.parent_id.nil? ? self : self.parent).page
    scgat = path_screen_gallery_attachment_type
    if scgat == 'site_image'
      args = [path_sub_type(thumbnail), *args]
    end
    PageAttachment.partitioned_path_for_url(the_page.url, scgat, *args)
  end

  def path_sub_type(thumbnail = nil)
    case (thumbnail || self.thumbnail).to_s
    when 'thumb' : 'thumbnail'
    when 'icon' : 'icon'
    else
      self.image? ? 'hi-res' : ''
    end
  end

  def path_screen_gallery_attachment_type
    (self.parent_id.nil? ? self : self.parent).screen_gallery_attachment_type
  end

  def self.partitioned_path_for_url(the_url, screen_gallery_attachment_type, *args)
    case screen_gallery_attachment_type
    when 'site_image'
      ['site_images'] + the_url.split('/') + args
    when 'promotional_video', 'editorial_content_showreel'
      ['site_videos'] + the_url.split('/') + args
    else
      ['site_documents'] + the_url.split('/') + args
    end
  end

  # We'll make every thumbnail a PNG - cope with pngizing the main images below in pngize!
  def thumbnail_name_for(thumbnail = nil)
    return filename if thumbnail.blank? || thumbnail == self.thumbnail
    ext = nil
    basename = filename.gsub /\.\w+$/ do |s|
      ext = s; ''
    end
    # Going to force everything to be a PNG
    ext = '.png'
    "#{self.parent_id.nil? ? self.id : self.parent_id}_#{basename}_#{thumbnail}#{ext}"
  end

  def pngize!(img = nil)
    if img.nil?
      with_image do |img|
        self.convert_to_png! img
      end
    else
      self.convert_to_png! img
    end
    self.filename = filename.gsub(/\.\w+$/, '.png')
  end

  def move_from(location)
    file_system_path = self.file_system_path(self.thumbnail)
    new_path = full_filename(self.thumbnail)
    unless File.exists?(new_path)
      sgat = path_screen_gallery_attachment_type
      args = if sgat == 'site_image'
        [path_sub_type(thumbnail), filename]
      else
        args = [filename]
      end
      old_path = File.join(RAILS_ROOT,
      file_system_path(self.thumbnail),
      *PageAttachment.partitioned_path_for_url(location, sgat, *args))
      if File.exists?(old_path)
        FileUtils.mkdir_p(File.dirname(new_path))
        FileUtils.mv(old_path, new_path)
      end
    end
    self.thumbnails.each do |t|
      t.move_from(location)
    end
  end

  def after_process_attachment
    if @saved_attachment
      if respond_to?(:process_attachment_with_processing) && thumbnailable? && !attachment_options[:thumbnails].blank? && parent_id.nil?
        # I want to create the thumbnails from the original data, not
        # the stuff I've just added corners to.
        temp_file = @temp_paths.last
        temp_file = temp_file.respond_to?(:path) ? temp_file.path : temp_file.to_s
        temp_file ||= create_temp_file
        attachment_options[:thumbnails].each { |suffix, size| create_or_update_thumbnail(temp_file, suffix, *size) }
      end
      save_to_storage
      @temp_paths.clear
      @saved_attachment = nil
      callback :after_attachment_saved
    end
  end
end
