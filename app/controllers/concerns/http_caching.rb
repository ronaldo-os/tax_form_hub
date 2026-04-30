# frozen_string_literal: true

# Provides HTTP caching headers for browser-level caching
# Helps reduce server load by allowing browsers to cache responses
#
# Usage:
#   class InvoicesController < ApplicationController
#     include HttpCaching
#     
#     before_action :set_cache_headers, only: [:index, :show]
#   end
#
module HttpCaching
  extend ActiveSupport::Concern

  # Default cache durations
  SHORT_CACHE = 5.minutes
  MEDIUM_CACHE = 15.minutes
  LONG_CACHE = 1.hour

  included do
    # Set browser caching headers for HTML responses
    def set_cache_headers(duration: MEDIUM_CACHE)
      return unless request.format.html?

      expires_in duration, public: true, stale_while_revalidate: 30.seconds
    end

    # Set aggressive caching for static-like content
    def set_long_cache_headers
      return unless request.format.html?

      expires_in LONG_CACHE, public: true, stale_while_revalidate: 5.minutes
    end

    # Disable caching for private/sensitive data
    def disable_cache_headers
      response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
    end
  end

  class_methods do
    # Helper to configure caching for specific actions
    def cache_page_for(duration, only: nil, except: nil)
      before_action(only: only, except: except) { set_cache_headers(duration: duration) }
    end
  end
end
