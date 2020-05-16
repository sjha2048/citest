module Seek
  module ActiveRecordExtensions
    def self.included(base)
      base.class_eval do
        # if after_initialize() is not an instance method, then the after_initialize callbacks don't get run.
        # this changes the after_initialize class method used to define the callbacks, so that it will
        # define the instance method if it does not exist
        def self.after_initialize_with_ensure_base_exists(*args)
          define_method(:after_initialize) {} unless method_defined? :after_initialize
          after_initialize_without_ensure_base_exists(*args)
        end

        class_alias_method_chain :after_initialize, :ensure_base_exists

        def self.is_taggable?
          false # defaults to false, unless it includes Taggable which will override this and check the configuration
        end
      end
    end

    # takes and ignores arguments for use in :after_add => :update_timestamp, etc.
    def update_timestamp(*_args)
      current_time = current_time_from_proper_timezone

      write_attribute('updated_at', current_time) if respond_to?(:updated_at)
      write_attribute('updated_on', current_time) if respond_to?(:updated_on)
    end

    def defines_own_avatar?
      respond_to?(:avatar)
    end

    def use_mime_type_for_avatar?
      false
    end

    def avatar_key
      thing = self
      thing = thing.parent if thing.class.name.include?('::Version')
      return nil if thing.use_mime_type_for_avatar? || thing.defines_own_avatar?
      "#{thing.class.name.underscore}_avatar"
    end

    def show_contributor_avatars?
      respond_to?(:contributor) || respond_to?(:creators)
    end

    def is_downloadable?
      (respond_to?(:content_blob) || respond_to?(:content_blobs))
    end

    # a method that can be overridden for cases where an item is downloadable, but for some reason (e.g. size), is disabled
    def download_disabled?
      !is_downloadable?
    end

    def versioned?
      respond_to? :versions
    end

    def suggested_type?
      self.class.include? Seek::Ontologies::SuggestedType
    end

    def rdf_supported?
      self.class.include? Seek::Rdf::RdfGeneration
    end
  end
end

ActiveRecord::Base.class_eval do
  include Seek::ActiveRecordExtensions
end
