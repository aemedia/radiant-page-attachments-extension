module PageAttachmentAssociations
  def self.included(base)
    base.class_eval {
      has_many :attachments,
               :class_name => "PageAttachment",
               :dependent => :destroy,
               :order => 'position'
      include InstanceMethods
      accepts_nested_attributes_for :attachments, :allow_destroy => true
      after_save :check_url_for_changes_and_act_accordingly
    }
  end

  module InstanceMethods
    def after_find
      @my_slug_before_anything_changes = self.slug
    end

    def check_url_for_changes_and_act_accordingly
      # did we have a pre-save version of the url
      # and ... is it different to what we have now?
      # and ... do we actually have any attachments?
      if @my_slug_before_anything_changes && (@my_slug_before_anything_changes != self.slug)
        new_slug = self.slug
        self.slug = @my_slug_before_anything_changes
        old_url = self.url
        self.slug = new_slug
        self.move_page_and_children(old_url)
      end
    end

    def move_page_and_children(pre_save_url)
      if (self.attachments.count > 0)
        # Move my attachments
        self.attachments.each do |att|
          att.move_from(pre_save_url)
        end
      end
      if (self.children.count > 0)
        # Move my child page attachments
        self.children.each do |child_page|
          # TODO - constructing the child_page url is pretty fragile - what if we
          # change how that is constructedt?
          child_page.attachments.each do |att|
            att.move_from(pre_save_url + child_page.slug + '/')
          end
          child_page.move_page_and_children(pre_save_url + child_page.slug + '/')
        end
      end
    end


    def destroy_attachments
      if @delete_attachments
        @delete_attachments.each do |attachment_id|
          PageAttachment.destroy(attachment_id)
        end
      end
      @delete_attachments = nil
    end

    def save_attachments
      if @add_attachments
        @add_attachments.each do |key, value|
          attachments << PageAttachment.new(:uploaded_data => value[:file], :screen_gallery_attachment_type => value[:screen_gallery_attachment_type])
        end  
      end
      @add_attachments = nil
    end

    # Currently recursive, but could be simplified with some SQL
    def attachment(name)
      att = attachments.find(:first, :conditions => ["filename LIKE ?", name.to_s])
      att.blank? ? ((parent.attachment(name) if parent) or nil) : att
    end
  end
end
