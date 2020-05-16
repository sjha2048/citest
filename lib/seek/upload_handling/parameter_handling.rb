module Seek
  module UploadHandling
    module ParameterHandling
      include Seek::UrlValidation

      def asset_params
        params.require(controller_name.downcase.singularize.to_sym)
      end

      def content_blobs_params
        params.require(:content_blobs)
      end

      def retained_content_blob_ids
        (params[:retained_content_blob_ids] || []).map(&:to_i).sort
      end

      def model_image_present?
        params[:model_image] && params[:model_image][:image_file]
      end

      def check_for_data_or_url(blob_param)
        if blob_param[:data].blank? && blob_param[:data_url].blank?  && blob_param[:base64_data].blank?
          if blob_param.include?(:data_url)
            flash.now[:error] = 'Please select a file to upload or provide a URL to the data.'
          elsif blob_param.include?(:data_url)
            flash.now[:error] = 'Please select a file to upload.'
          else
            # What to do?
          end
          false
        else
          true
        end
      end

      def check_for_valid_uri_if_present(blob_params)
        blob_params[:data_url].strip!
        data_url_param = blob_params[:data_url]
        if !data_url_param.blank? && !valid_url?(data_url_param)
          flash.now[:error] = "The URL '#{data_url_param}' is not valid"
          false
        else
          true
        end
      end

      def check_for_base64_data(blob_params)
        base64_data = blob_params[:base64_data]
        if base64_data.blank?
          return false
        end
        return true
      end

      def check_for_empty_data_if_present(blob_params)
        return true unless blob_params[:data_url].blank?
        Array(blob_params[:data]).each do |data|
          if !data.blank? && data.size == 0
            flash.now[:error] = 'The file that you are uploading is empty. Please check your selection and try again!'
            return false
          end
        end
        true
      end
    end
  end
end
