class SearchController < ApplicationController

  before_filter :set_default_search_params

  include Seek::ExternalSearch
  include Seek::FacetedBrowsing

  def index

    if Seek::Config.solr_enabled
      if params.has_key?(:keywords) || params.has_key?(:advanced_search)
        perform_advanced_search (request.format.json?)
      else
        perform_search (request.format.json?)
      end    
    else
      @results = []
    end

    #strip out nils, which can occur if the index is out of sync
    @results.compact!
    #select only items, that can be viewed by the current_user
    @results.select!(&:can_view?)

    @results_scaled = Scale.all.collect {|scale| [scale.key, @results.select {|item| !item.respond_to?(:scale_ids) or item.scale_ids.include? scale.id}]}
    @results_scaled << ['all', @results]
    @results_scaled = Hash[*@results_scaled.flatten(1)]
    logger.info @results_scaled.inspect
    if params[:scale]
      # when user does not login, params[:scale] is nil
      @results = @results_scaled[params[:scale]]
      @scale_key = params[:scale]
    else
       @results = @results_scaled['all']
       @scale_key = 'all'
    end


    if @results.empty?
      flash.now[:notice]="No matches found for '<b>#{@search_query}</b>'.".html_safe
    else
      flash.now[:notice]="#{@results.size} #{@results.size==1 ? 'item' : 'items'} matched '<b>#{@search_query}</b>' within their title or content.".html_safe
    end

    @include_external_search = params[:include_external_search]=="1"

    view_context.ie_support_faceted_browsing? if Seek::Config.faceted_search_enabled

    respond_to do |format|
      format.html
      format.json {render json: @results,
                          each_serializer: SkeletonSerializer,
                          meta: {:base_url =>   Seek::Config.site_base_host,
                                 :api_version => ActiveModel::Serializer.config.api_version
                          }}
    end
    
  end

  def perform_search (is_json = false)
    @search_query = ActionController::Base.helpers.sanitize(params[:q] || params[:search_query])
    @search=@search_query # used for logging, and logs the origin search query - see ApplicationController#log_event
    @search_query||=""
    @search_type = params[:search_type]
    type=@search_type.downcase unless @search_type.nil?

    @search_query = Seek::Search::SearchTermFilter.filter @search_query

    downcase_query = @search_query.downcase

    @results=[]

    searchable_types = Seek::Util.searchable_types

    if (Seek::Config.solr_enabled and !downcase_query.blank?)
      if type == "all"
          sources = searchable_types
          if is_json
            sources -= [Strain, Sample]
          end
          sources.each do |source|
            search = source.search do |query|
              query.keywords(downcase_query)
              query.paginate(:page => 1, :per_page => source.count ) if source.count > 30  # By default, Sunspot requests the first 30 results from Solr
            end #.results
            @search_hits = search.hits
            search_result = search.results
            @results |= search_result
          end
      else
           search_type = type.singularize.camelize.constantize
           raise "#{type} is not a valid search type" unless searchable_types.include?(search_type)
           search = search_type.search do |query|
             query.keywords(downcase_query)
             query.paginate(:page => 1, :per_page => search_type.count ) if search_type.count > 30 # By default, Sunspot requests the first 30 results from Solr
           end #.results
           @search_hits = search.hits
           search_result = search.results
           @results = search_result
      end

      if (params[:include_external_search]=="1")
        external_results = external_search downcase_query,type
        @results |= external_results
      end

      @results = apply_filters(@results)
    end

  end

  #executes perform_search and applies filters from params after results have been found
  def perform_advanced_search(is_json = false)
    #puts "Advanced search has been performed!" 
    #@results = []
    if !params[:q].blank?	  
      perform_search (request.format.json?)
    elsif params[:search_type] != "all" 
      Rails.logger.info "Search type is: #{params[:search_type].singularize.camelize.constantize}" 
      Rails.logger.info "Search box was left blank" 
      search_type = params[:search_type].singularize.camelize.constantize
      @results = search_type.all
    else
      Rails.logger.info "No keywords or search type present! No results" 
      @results = []
    end

    new_results = []
    #filtering results
    @results.each do |result|     
      passed_filters = true 
      #searching based on associated models: institutions and disciplines
      result_type = result.class
      associated_models = result_type.reflect_on_all_associations.map(&:class_name)
      Rails.logger.info "These are the associated types: #{associated_models}" 

      #filter by institution
      if params.has_key?(:institution) && params[:institution] != "All"
        if associated_models.include?("Institution")
	  insts = result.institutions.map{|i| i.title}
          Rails.logger.info "Institutions: #{insts}, Search Institution: #{params[:institution]}" 
          if !insts.include?("#{params[:institution]}")
	    passed_filters = false
          end
        else
          Rails.logger.info "Model did not have associated institutions"
          passed_filters = false
        end
      end

      #filter by disciplines
      if params.has_key?(:discipline) && params[:discipline] != "All"  
        if associated_models.include?("Discipline")
	  discs = result.disciplines.map{|i| i.title}
          Rails.logger.info "Disciplines: #{discs}, Search Discipline: #{params[:discipline]}"
          if !discs.include?("#{params[:discipline]}")
	    passed_filters = false
          end
        else
          Rails.logger.info "Model didn't have discipline, but searched for discipline"
	  passed_filters = false  
        end
      end

      #TODO: add filters to tags  
      if params.has_key?(:tool) && !params[:tool].blank?
	if associated_models.include?("Annotation") && result.instance_of?(Person) 	  
	  tools_list = result.tool_annotations.map{|t| t.value.text}
          if !tools_list.empty?
	    Rails.logger.info "Tools are: #{tools_list}" 
	    if !tools_list.include?(params[:tool])
	      passed_filters = false
              Rails.logger.info "Did not include searched tool" 
            end
          else
	    Rails.logger.info "No tools were present"
            passed_filters = false
          end
	else
	  Rails.logger.info "Result did not contain tools or was not a person" 
          passed_filters = false
	end
      end

      if params.has_key?(:expertise) && !params[:expertise].blank?
	if associated_models.include?("Annotation") && result.instance_of?(Person) 	  
	  expertise_list = result.expertise_annotations.map{|e| e.value.text}
          if !expertise_list.empty?
	    Rails.logger.info "Areas of Expertise are: #{expertise_list}" 
	    if !expertise_list.include?(params[:expertise])
	      passed_filters = false
              Rails.logger.info "Did not include searched area of expertise" 
            end
          else
	    Rails.logger.info "No areas of expertise present"
            passed_filters = false
          end
	else
	  Rails.logger.info "Result did not contain expertise or was not a person" 
          passed_filters = false
	end
      end

      if params.has_key?(:project_status) && params[:project_status] != "All"
        if result.has_attribute?(:project_status)      
          if params[:project_status] != result.project_status
	    Rails.logger.info "Result status was actually this: '#{result.project_status}' Project status: '#{params[:project_status]}'"
            passed_filters = false
          end
        else
          passed_filters = false
	  Rails.logger.info "Result had no status"
        end
      end

      if params.has_key?(:min_due_date) && !params[:min_due_date].empty?
	if result.has_attribute?(:target_completion) && !result.target_completion.blank?
          Rails.logger.info "Result's completion is this: #{result.target_completion}" 
          if Date.parse(params[:min_due_date]) > Date.parse(result.target_completion) 
	    passed_filters = false
            Rails.logger.info "Comparison: #{Date.parse(params[:min_due_date])} is less than #{Date.parse(result.target_completion)}?"
          end
        else
          passed_filters = false
	  Rails.logger.info "Result had no target completion"
        end
      end
 
      if params.has_key?(:max_due_date) && !params[:max_due_date].empty?
	if result.has_attribute?(:target_completion) && !result.target_completion.blank?
          Rails.logger.info "Result's completion is this: #{result.target_completion}" 
          if Date.parse(params[:max_due_date]) < Date.parse(result.target_completion) 
	    passed_filters = false
	    Rails.logger.info "Result had later completion of #{result.target_completion} as compared to #{params[:max_due_date]}"
          end
        else
          passed_filters = false
	  Rails.logger.info "Result had later completion"
        end
      end

      if passed_filters
	new_results.push(result)
	Rails.logger.info "Result '#{result} passed filter inspection" 
      else
        Rails.logger.info "Result '#{result}' did not pass filter inspection"	
      end
    end
    Rails.logger.info "Results are in: '#{new_results}'"
    @results = new_results
  end


  private

  def set_default_search_params
    params[:include_external_search] ||= 0
    params[:search_type] = 'all' if params[:search_type].blank?
  end

  def include_external_search?
    Seek::Config.external_search_enabled && params[:include_external_search]
  end

end
