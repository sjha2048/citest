class SopsController < ApplicationController
  
  include Seek::IndexPager

  include Seek::AssetsCommon

  before_filter :find_assets, :only => [ :index ]
  before_filter :find_and_authorize_requested_item, :except => [ :index, :new, :create, :request_resource,:preview, :test_asset_url, :update_annotations_ajax]
  before_filter :find_display_asset, :only=>[:show, :download]

  include Seek::Publishing::PublishingCommon

  include Seek::BreadCrumbs
  include Seek::Doi::Minting

  include Seek::IsaGraphExtensions

  def new_version
    if handle_upload_data(true)
      comments=params[:revision_comments]


      respond_to do |format|
        if @sop.save_as_new_version(comments)

          #Duplicate experimental conditions
          conditions = @sop.find_version(@sop.version - 1).experimental_conditions
          conditions.each do |con|
            new_con = con.dup
            new_con.sop_version = @sop.version
            new_con.save
          end
          flash[:notice]="New version uploaded - now on version #{@sop.version}"
        else
          flash[:error]="Unable to save new version"          
        end
        format.html {redirect_to @sop }
      end
    else
      flash[:error]=flash.now[:error] 
      redirect_to @sop
    end
    
  end

  # PUT /sops/1
  def update
    update_annotations(params[:tag_list], @sop) if params.key?(:tag_list)
    update_sharing_policies @sop
    update_relationships(@sop,params)

    respond_to do |format|
      if @sop.update_attributes(sop_params)
        flash[:notice] = "#{t('sop')} metadata was successfully updated."
        format.html { redirect_to sop_path(@sop) }
        format.json { render json: @sop }
      else
        format.html { render action: 'edit' }
        format.json { render json: json_api_errors(@sop), status: :unprocessable_entity }
      end
    end
  end

  private

  def sop_params
    params.require(:sop).permit(:title, :description, { project_ids: [] }, :license, :other_creators,
                                { special_auth_codes_attributes: [:code, :expiration_date, :id, :_destroy] },
                                { creator_ids: [] }, { assay_assets_attributes: [:assay_id] }, { scales: [] },
                                { publication_ids: [] })
  end

  alias_method :asset_params, :sop_params

end
