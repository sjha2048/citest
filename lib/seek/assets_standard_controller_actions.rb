module Seek
  # The standard basic actions for assets - currently show, new, create, edit, destroy. THe intention is to support all methods for all asset types.
  # DataFile is currently not fully supported due to biosample complications which are intended to be revisited.
  module AssetsStandardControllerActions
    include Seek::DestroyHandling
    include Seek::UploadHandling::DataUpload

    def new
      setup_new_asset
      respond_for_new
    end

    def show
      asset = determine_asset_from_controller
      # store timestamp of the previous last usage
      @last_used_before_now = asset.last_used_at

      # update timestamp in the current record
      # (this will also trigger timestamp update in the corresponding Asset)
      asset.just_used
      asset_version = find_display_asset asset
      respond_to do |format|
        format.html
        format.xml
        if asset.respond_to?(:to_rdf)
          format.rdf { render template: 'rdf/show' }
        else
          format.rdf { render text: 'This resource does not support RDF', status: :not_acceptable, content_type: 'text/plain' }
        end
        format.json { render json: asset, scope: { requested_version: params[:version] } }
      end
    end

    def setup_new_asset
      item = class_for_controller_name.new
      item.parent_name = params[:parent_name] if item.respond_to?(:parent_name)
      set_shared_item_variable(item)
      @content_blob = ContentBlob.new
      @page_title = params[:page_title]
    end

    def respond_for_new
      respond_to do |format|
        if User.logged_in_and_member?
          format.html # new.html.erb
        else
          flash[:error] = "You are not authorized to upload a new #{t(controller_name.singularize)}. Only members of known projects, institutions or work groups are allowed to create new content."
          format.html { redirect_to eval("#{controller_name}_path") }
        end
      end
    end

    def edit
    end

    def create
      item = initialize_asset

      if handle_upload_data
        create_asset_and_respond(item)
      else
        handle_upload_data_failure
      end
    end

    # i.e. Model, or DataFile according to the controller name
    def class_for_controller_name
      controller_name.classify.constantize
    end

    # i.e. @model = item, or @data_file = item - according to the item class name
    def set_shared_item_variable(item)
      instance_variable_set("@#{item.class.name.underscore}", item)
    end

    # the standard response block after created a new asset
    def create_asset_and_respond(item)
      item = create_asset(item)
      if item.save
        unless return_to_fancy_parent(item)
          flash[:notice] = "#{t(item.class.name.underscore)} was successfully uploaded and saved."
          respond_to do |format|
            format.html { redirect_to item }
            format.json { render json: item }
          end
        end
      else
        respond_to do |format|
          format.html { render action: 'new' }
          format.json { render json: json_api_errors(item), status: :unprocessable_entity }
        end
      end
    end

    #makes sure the asset it only associated with projects that match the current user
    def filter_associated_projects(asset,user=User.current_user)
      asset.projects = asset.projects & user.person.projects
    end

    def update_sharing_policies(item)
      item.policy.set_attributes_with_sharing(policy_params) if policy_params.present?
    end

    def initialize_asset
      item = class_for_controller_name.new(asset_params)
      set_shared_item_variable(item)

      item
    end

    def create_asset(item)
      update_sharing_policies item
      update_annotations(params[:tag_list], item)
      update_relationships(item, params)
      build_model_image item, model_image_params if item.is_a?(Model) && model_image_present?
      item
    end

    def return_to_fancy_parent(item)
      return false unless item.respond_to?(:parent_name) && !item.parent_name.blank?
      render partial: 'assets/back_to_fancy_parent', locals: { child: item, parent_name: item.parent_name }
      true
    end
  end
end

