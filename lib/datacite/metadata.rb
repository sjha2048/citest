require_relative 'metadata_builder'

module DataCite
  class Metadata < Hash
    REQUIRED_FIELDS = %i[title identifier publisher year creators].freeze

    def initialize(hash)
      super.merge!(hash)
    end

    def build
      validate
      DataCite::MetadataBuilder.new(self).build
    end

    def to_s
      build.to_s
    end

    def validate
      REQUIRED_FIELDS.each do |property|
        raise MissingMetadataException, "Required field: '#{property}' is missing" unless keys.include?(property)
      end
      self[:creators].each do |creator|
        unless creator.respond_to?(:first_name) && !creator.first_name.blank?
          raise MissingMetadataException, "Creator missing first name: #{creator.inspect}"
        end
        unless creator.respond_to?(:last_name) && !creator.last_name.blank?
          raise MissingMetadataException, "Creator missing last name: #{creator.inspect}"
        end
      end

      true
    end
  end

  class MissingMetadataException < RuntimeError; end
end
