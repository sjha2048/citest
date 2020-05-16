class AdvancedSearchesController < ApplicationController
    skip_before_filter :project_membership_required
    def new
        @advanced_search = AdvancedSearch.new
    end

    def show
        @advanced_search = AdvancedSearch.find(params[:id])
    end
    
    def create
	search_params
	d = params[:advanced_search]
	if !d[:browse_type].blank?
	  Rails.logger.info "Should redirect right here.." 
	  redirect_to controller: d[:browse_type], action: 'index'
	else
	  redirect_to controller: 'search', action: 'index', q: d[:keywords], tool: d[:tool], search_type: d[:search_type], advanced_search: true, min_due_date: d[:min_due_date], max_due_date: d[:max_due_date], institution: d[:institution], discipline: d[:discipline], city: d[:city], expertise: d[:expertise], project_status: d[:project_status]
        end
    end

    private

    def search_params 
        params.require(:advanced_search).permit(:keywords, :tool, :browse_type, :search_type, :project_status, :min_due_date, :max_due_date, :institution, :discipline, :city, :expertise) 
	d = params[:advanced_search]
        @search_query = d[:keywords]
	@search_type = d[:search_type]
    end
end
