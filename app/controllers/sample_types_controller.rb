class SampleTypesController < ApplicationController
  respond_to :html, :json
  include Seek::UploadHandling::DataUpload
  include Seek::IndexPager

  before_filter :samples_enabled?
  before_filter :find_sample_type, only: [:show, :edit, :update, :destroy, :template_details]
  before_filter :check_no_created_samples, only: [:destroy]
  before_filter :find_assets, only: [:index]
  before_filter :auth_to_create, only: [:new, :create]
  before_filter :project_membership_required, only: [:create, :new, :select, :filter_for_select]

  before_filter :authorize_requested_sample_type, except: [:index, :new, :create]

  # GET /sample_types/1  ,'sample_attributes','linked_sample_attributes'
  # GET /sample_types/1.json
  def show
    respond_to do |format|
      format.html
      # format.json {render json: @sample_type}
      format.json {render json: :not_implemented, status: :not_implemented }
    end
  end

  # GET /sample_types/new
  # GET /sample_types/new.json
  def new
    @tab = 'manual'

    @sample_type = SampleType.new
    @sample_type.sample_attributes.build(is_title: true, required: true) # Initial attribute

    respond_with(@sample_type)
  end

  def create_from_template
    build_sample_type_from_template
    @sample_type.contributor = User.current_user.person

    @tab = 'from-template'

    respond_to do |format|
      if @sample_type.errors.empty? && @sample_type.save
        format.html { redirect_to edit_sample_type_path(@sample_type), notice: 'Sample type was successfully created.' }
      else
        @sample_type.content_blob.destroy if @sample_type.content_blob.persisted?
        format.html { render action: 'new' }
      end
    end
  end

  # GET /sample_types/1/edit
  def edit
    respond_with(@sample_type)
  end

  # POST /sample_types
  # POST /sample_types.json
  def create
    # because setting tags does an unfortunate save, these need to be updated separately to avoid a permissions to edit error
    tags = params[:sample_type].delete(:tags)
    @sample_type = SampleType.new(sample_type_params)
    @sample_type.contributor = User.current_user.person

    # removes controlled vocabularies or linked seek samples where the type may differ
    @sample_type.resolve_inconsistencies
    @tab = 'manual'

    respond_to do |format|
      if @sample_type.save
        @sample_type.update_attribute(:tags, tags)
        format.html { redirect_to @sample_type, notice: 'Sample type was successfully created.' }
        format.json { render json: @sample_type, status: :created, location: @sample_type}
      else
        format.html { render action: 'new' }
        format.json { render json: @sample_type.errors, status: :unprocessable_entity}
      end
    end
  end

  # PUT /sample_types/1
  # PUT /sample_types/1.json
  def update
    @sample_type.update_attributes(sample_type_params)
    @sample_type.resolve_inconsistencies
    flash[:notice] = 'Sample type was successfully updated.' if @sample_type.save
    respond_to do |format|
      format.html { respond_with(@sample_type) }
      format.json {render json: @sample_type}
    end

  end

  # DELETE /sample_types/1
  # DELETE /sample_types/1.json
  def destroy
    if @sample_type.can_delete? && @sample_type.destroy
      flash[:notice] = 'The sample type was successfully deleted.'
    else
      flash[:notice] = 'It was not possible to delete the sample type.'
    end

    respond_with(@sample_type, location: sample_types_path)
  end

  def template_details
    render partial: 'template'
  end

  # current just for selecting a sample type for creating a sample, but easily has potential as a general browser
  def select
    respond_with(@sample_types)
  end

  # used for ajax call to get the filtered sample types for selection
  def filter_for_select
    @sample_types = SampleType.joins(:projects).where('projects.id' => params[:projects]).uniq.to_a
    unless params[:tags].blank?
      @sample_types.select! do |sample_type|
        if params[:exclusive_tags] == '1'
          (params[:tags] - sample_type.annotations_as_text_array).empty?
        else
          (sample_type.annotations_as_text_array & params[:tags]).any?
        end
      end
    end
    render partial: 'sample_types/select/filtered_sample_types'
  end

  private

  def sample_type_params
    params.require(:sample_type).permit(:title, :description, :tags,
                                        {project_ids: [],
                                         sample_attributes_attributes: [:id, :title, :pos, :required, :is_title,
                                                                        :sample_attribute_type_id,
                                                                        :sample_controlled_vocab_id,
                                                                        :linked_sample_type_id,
                                                                        :unit_id, :_destroy]})
  end


  def build_sample_type_from_template
    @sample_type = SampleType.new(sample_type_params)
    @sample_type.uploaded_template = true

    handle_upload_data
    @sample_type.content_blob.save! # Need's to be saved so the spreadsheet can be read from disk
    @sample_type.build_attributes_from_template
  end

  private

  def find_sample_type
    @sample_type = SampleType.find(params[:id])
  end

  #intercepts the standard 'find_and_authorize_requested_item' for additional special check for a referring_sample_id
  def authorize_requested_sample_type
    privilege = Seek::Permissions::Translator.translate(action_name)
    return if privilege.nil?

    if privilege == :view && params[:referring_sample_id].present?
      @sample_type.can_view?(User.current_user,Sample.find_by_id(params[:referring_sample_id])) || find_and_authorize_requested_item
    else
      find_and_authorize_requested_item
    end

  end

  def check_no_created_samples
    if (count = @sample_type.samples.count) > 0
      flash[:error] = "Cannot #{action_name} this sample type - There are #{count} samples using it."
      redirect_to @sample_type
    end
  end
end
