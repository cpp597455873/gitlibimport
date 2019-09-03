# frozen_string_literal: true

module PaginatedCollection
  extend ActiveSupport::Concern

  private

  def collection_page_count(collection)
    @collection_page_count ||= collection.total_pages
  end

  def redirect_out_of_range(collection)
    total_pages = collection_page_count(collection)
    return false if total_pages.nil? || total_pages.zero?

    out_of_range = collection.current_page > total_pages

    if out_of_range
      redirect_to(url_for(safe_params.merge(page: total_pages, only_path: true)))
    end

    out_of_range
  end
end
