module Seek
  module Permissions
    class Translator
      # Using Sets instead of Arrays because lookups are much faster
      MAP = {
          view: Set.new([
            :view, :show, :index, :search, :favourite, :favourite_delete, :comment, :comment_delete, :comments,
            :comments_timeline, :rate, :tag, :items, :statistics, :tag_suggestions, :preview, :runs,
            :new_object_based_on_existing_one, :samples_table, :matching_models, :matching_data
          ]).freeze,

          download: Set.new([
            :download, :named_download, :launch, :submit_job, :data, :execute, :plot, :explore, :visualise,
            :export_as_xgmml, :download_log, :download_results, :input, :output, :download_output, :download_input,
            :view_result, :compare_versions, :simulate
          ]).freeze,

          edit: Set.new([
             :edit, :new, :create, :update, :new_version, :create_version, :destroy_version, :edit_version,
             :update_version, :new_item , :create_item, :edit_item, :update_item, :quick_add, :resolve_link,
             :describe_ports, :retrieve_nels_sample_metadata
          ]).freeze,

          delete: Set.new([
              :delete, :destroy, :destroy_item, :cancel, :destroy_samples_confirm
          ]).freeze,

          manage: Set.new([
             :manage, :notification, :read_interaction, :write_interaction, :report_problem, :storage_report,
             :select_sample_type, :extraction_status, :extract_samples, :confirm_extraction, :cancel_extraction
          ]).freeze,
      }.freeze

      def self.translate(action)
        (MAP.find { |_, value| value.include?(action.to_sym) } || []).first
      end
    end
  end
end
