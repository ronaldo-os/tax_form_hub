module ApplicationHelper
  # Responsive image helper with lazy loading and proper sizing
  def responsive_image_tag(source, options = {})
    default_options = {
      loading: "lazy",
      decoding: "async",
      class: "img-fluid",
      style: "max-width: 100%; height: auto;"
    }
    
    # Merge user options with defaults
    merged_options = default_options.merge(options)
    
    # Add srcset for responsive images if it's an Active Storage attachment
    if source.respond_to?(:attached?) && source.attached?
      variants = [
        { resize: "400x400" },
        { resize: "800x800" },
        { resize: "1200x1200" }
      ]
      
      srcset = variants.map do |variant_options|
        variant = source.variant(variant_options)
        "#{rails_representation_url(variant)} #{variant_options[:resize].split('x').first}w"
      end.join(", ")
      
      merged_options[:srcset] = srcset
      merged_options[:sizes] = "(max-width: 400px) 400px, (max-width: 800px) 800px, 1200px"
    end
    
    image_tag(source, merged_options)
  end
  
  # Lazy load placeholder for images
  def lazy_image_placeholder(width: 100, height: 100, text: "Loading...")
    content_tag(:div, 
      content_tag(:div, text, class: "placeholder-text"),
      class: "lazy-image-placeholder",
      style: "width: #{width}px; height: #{height}px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; border-radius: 4px;"
    )
  end
end
