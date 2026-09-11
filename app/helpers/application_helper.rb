module ApplicationHelper
  # Determines the effective active theme, prioritizing cookies for instantaneous client-server sync
  def current_theme
    theme = cookies[:user_theme].presence || current_user&.theme.presence || "light"
    %w[light dark].include?(theme) ? theme : "light"
  end

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

  # Cached critical CSS inliner to avoid repeated disk reads
  def inline_critical_css
    if Rails.env.production?
      @cached_critical_css ||= begin
        path = Rails.root.join("app/assets/builds/critical.css")
        File.exist?(path) ? File.read(path) : ""
      end
    else
      path = Rails.root.join("app/assets/builds/critical.css")
      File.exist?(path) ? File.read(path) : ""
    end
  end
end
