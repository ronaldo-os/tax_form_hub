module ApplicationHelper
  # Determines the effective active theme:
  # - For unauthenticated sessions (including login), always use the default "light" theme.
  # - For authenticated sessions, use the cookie (for instantaneous toggle sync) or fallback to current_user.theme.
  def current_theme
    return "light" unless user_signed_in?

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

  # Breadcrumbs management
  def breadcrumbs
    @breadcrumbs ||= []
  end

  def add_breadcrumb(name, path = nil)
    breadcrumbs << { name: name, path: path }
  end

  def render_breadcrumbs(custom_class: "")
    return if breadcrumbs.empty?

    content_tag(:nav, aria: { label: "breadcrumb" }, class: "app-breadcrumbs-nav #{custom_class}".strip) do
      content_tag(:ol, class: "breadcrumb mb-0 py-0 align-items-center flex-nowrap") do
        breadcrumbs.each_with_index.map do |crumb, index|
          is_last = (index == breadcrumbs.length - 1)
          item_class = "breadcrumb-item #{'active' if is_last}".strip

          content_tag(:li, class: item_class, aria: (is_last ? { current: "page" } : nil)) do
            if !is_last && crumb[:path].present?
              link_to crumb[:path], class: "text-decoration-none breadcrumb-link d-inline-flex align-items-center gap-1" do
                if index == 0 && crumb[:name] == "Home"
                  concat content_tag(:i, "", class: "fa-solid fa-house fs-8 me-1")
                end
                concat content_tag(:span, crumb[:name])
              end
            else
              content_tag(:span, crumb[:name], class: "breadcrumb-current fw-semibold text-truncate")
            end
          end
        end.join.html_safe
      end
    end
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
