require 'csv'

module Seek
  module Rdf
    module RdfGeneration
      include RdfRepositoryStorage
      include RightField
      include CSVMappingsHandling

      def self.included(base)
        base.after_save :create_rdf_generation_job
        base.before_destroy :remove_rdf
      end

      def to_rdf
        rdf_graph = to_rdf_graph
        RDF::Writer.for(:rdfxml).buffer(prefixes: ns_prefixes) do |writer|
          rdf_graph.each_statement do |statement|
            writer << statement
          end
        end
      end

      def to_rdf_graph
        rdf_graph = RDF::Graph.new
        rdf_graph = describe_type(rdf_graph)
        rdf_graph = generate_from_csv_definitions rdf_graph
        rdf_graph = additional_triples rdf_graph
        rdf_graph
      end

      def handle_rightfield_contents(object)
        graph = nil
        if object.respond_to?(:contains_extractable_spreadsheet?) && object.contains_extractable_spreadsheet?
          begin
            graph = generate_rightfield_rdf_graph(self)
          rescue Exception => e
            Rails.logger.error "Error generating RightField part of rdf for #{object} - #{e.message}"
          end
        end
        graph || RDF::Graph.new
      end

      def rdf_resource
        uri = URI.join(Seek::Config.site_base_host + "/", "#{self.class.name.tableize}/","#{id}").to_s
        RDF::Resource.new(uri)
      end

      # extra steps that cannot be easily handled by the csv template
      def additional_triples(rdf_graph)
        if is_a?(Model) && contains_sbml?
          rdf_graph << [rdf_resource, JERMVocab.hasFormat, JERMVocab.SBML_format]
        end
        rdf_graph
      end

      def describe_type(rdf_graph)
        unless rdf_type_entity_fragment.nil?
          resource = rdf_resource
          rdf_graph << [resource, RDF.type, rdf_type_uri]
        end
        rdf_graph
      end

      # this is what is needed for the SEEK_ID term from JERM. It is essentially the same as the resource, but this method
      # make the mappings clearer
      def rdf_seek_id
        rdf_resource.to_s
      end

      # the URI for the type of this object, for example http://jermontology.org/ontology/JERMOntology#Study for a Study
      def rdf_type_uri
        JERMVocab[rdf_type_entity_fragment]
      end

      def rdf_type_entity_fragment
        JERMVocab.defined_types[self.class]
      end

      # the hash of namespace prefixes to pass to the RDF::Writer when generating the RDF
      def ns_prefixes
        {
          'jerm' => JERMVocab.to_uri.to_s,
          'dcterms' => RDF::DC.to_uri.to_s,
          'owl' => RDF::OWL.to_uri.to_s,
          'foaf' => RDF::FOAF.to_uri.to_s,
          'sioc' => RDF::SIOC.to_uri.to_s
        }
      end

      def create_rdf_generation_job(force = false, refresh_dependents = true)
        unless !force && (changed - %w[updated_at last_used_at]).empty?
          RdfGenerationJob.new(self, refresh_dependents).queue_job
        end
      end

      def remove_rdf
        remove_rdf_from_repository if rdf_repository_configured?
        delete_rdf_file
        refresh_dependents_rdf
      end

      def refresh_dependents_rdf
        dependent_items.each do |item|
          item.refresh_rdf if item.respond_to?(:refresh_rdf)
        end
      end

      def dependent_items
        items = []
        # FIXME: this should go into a seperate mixin for active-record
        methods = %i[data_files sops models publications
                     data_file_masters sop_masters model_masters
                     assets
                     assays studies investigations
                     institutions creators owners owner contributors contributor projects events presentations compounds organisms strains]
        methods.each do |method|
          next unless respond_to?(method)
          deps = Array(send(method))
          # resolve User back to Person
          deps = deps.collect { |dep| dep.is_a?(User) ? [dep, dep.person] : dep }.flatten.compact
          items |= deps
        end

        items.compact.uniq

        items |= related_items_from_sparql if rdf_repository_configured?

        items.compact.uniq
      end

      def refresh_rdf
        create_rdf_generation_job(true, false)
      end
    end
  end
end
