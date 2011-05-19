require 'RMagick'
module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Processors
      module RmagickProcessor
        def self.included(base)
          base.send :extend, ClassMethods
          base.alias_method_chain :process_attachment, :processing
        end

        module ClassMethods
          # Yields a block containing an RMagick Image for the given binary data.
          def with_image(file, &block)
            begin
              binary_data = file.is_a?(Magick::Image) ? file : Magick::Image.read(file).first unless !Object.const_defined?(:Magick)
            rescue
              # Log the failure to load the image.  This should match ::Magick::ImageMagickError
              # but that would cause acts_as_attachment to require rmagick.
              logger.debug("Exception working with image: #{$!}")
              binary_data = nil
            end
            block.call binary_data if block && binary_data
          ensure
            !binary_data.nil?
          end
        end

      protected
        def process_attachment_with_processing
          return unless process_attachment_without_processing
          with_image do |img|
            resize_image_or_thumbnail! img
            self.width  = img.columns if respond_to?(:width)
            self.height = img.rows    if respond_to?(:height)
            callback_with_args :after_resize, img
          end if image?
        end

        # Performs the actual resizing operation for a thumbnail
        def resize_image(img, size)
          size = size.first if size.is_a?(Array) && size.length == 1 && !size.first.is_a?(Fixnum)
          if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
            size = [size, size] if size.is_a?(Fixnum)
            img.thumbnail!(*size)
          elsif size.is_a?(String) && size =~ /^c.*$/ # Image cropping - example geometry string: c75x75
            dimensions = size[1..size.size].split("x")
            img.crop_resized!(dimensions[0].to_i, dimensions[1].to_i)
          elsif size.is_a?(String) && size =~ /^b.*$/ # Resize w/border - example geometry string: b75x75
            dimensions = size[1..size.size].split("x")
            img.change_geometry(dimensions.join("x")) do |cols, rows, image| 
              image.resize!(cols<1 ? 1 : cols, rows<1 ? 1 : rows ) 
            end
            img.background_color = "black"
            x_offset = (img.columns - dimensions[0].to_i) / 2
            y_offset = (img.rows - dimensions[1].to_i) / 2
            img = img.extent(dimensions[0].to_i, dimensions[1].to_i, x_offset, y_offset)
          else
            img.change_geometry(size.to_s) { |cols, rows, image| image.resize!(cols<1 ? 1 : cols, rows<1 ? 1 : rows) }
          end
          img.strip! unless attachment_options[:keep_profile]
          temp_paths.unshift write_to_temp_file(img.to_blob)
        end
        
        
        def apply_rounded_corners!(img)
          alpha_mask = ::Magick::Image.new(img.columns, img.rows) {
            self.background_color = 'black'
            self.format = 'PNG'
          }

          roundrect = ::Magick::Draw.new
          roundrect.fill = 'white'
          roundrect.stroke = 'white'

          # Work out the scaling of the corner.  We assume a 4:3 ratio, so take the width
          # (e.g. which would become 200 on a 200x150 thumb) and scale the 10x10 corner
          # we'd use on a 200x150 thumb.
          corner_size = (10 * (img.columns / 200.to_f)).round

          # the -1 on x+y is because the rect seems to go 1 over (perhaps this is a stroke width thing?)
          roundrect.roundrectangle(0, 0, (img.columns - 1), (img.rows - 1), corner_size, corner_size)
          roundrect.draw(alpha_mask)

          alpha_mask.write('/tmp/alpha_mask.png')

          alpha_mask.matte = false
          img.matte = true
          img.matte_color = 'black'
          img.format = 'PNG'
          img.composite!(alpha_mask, ::Magick::NorthGravity, ::Magick::CopyOpacityCompositeOp)

          img.strip!
          self.temp_path = self.class.write_to_temp_file(img.to_blob, random_tempfile_filename + ".png")
        end

        def convert_to_png!(img)
          if img.format !~ /png/i
            img.format = 'PNG'
            img.strip!
            self.temp_path = self.class.write_to_temp_file(img.to_blob, random_tempfile_filename + ".png")
          end
        end
                
                
                
      end
    end
  end
end
