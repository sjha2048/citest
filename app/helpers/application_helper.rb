# Methods added to this helper will be available to all templates in the application.
# require_dependency File.join(Gem.loaded_specs['my_annotations'].full_gem_path,'lib','app','helpers','application_helper')
require 'app_version'

module ApplicationHelper
  include FancyMultiselectHelper
  include Recaptcha::ClientHelper
  include VersionHelper

  def no_items_to_list_text
    content_tag :div, id: 'no-index-items-text' do
      "There are no #{resource_text_from_controller.pluralize} found that are visible to you."
    end
  end

  def required_span
    content_tag :span, class: 'required' do
      '*'
    end
  end

  # e.g. SOP for sops_controller, taken from the locale based on the controller name
  def resource_text_from_controller
    internationalized_resource_name(controller_name.singularize.camelize, false)
  end

  def index_title(title = nil)
    content_tag(:h1) { title || resource_text_from_controller.pluralize }
  end

  def is_front_page?
    current_page?(main_app.root_url)
  end

  # turns the object name from a form builder, in the equivalent id
  def sanitized_object_name(object_name)
    object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, '_').sub(/_$/, '')
  end

  def seek_stylesheet_tags(main = 'application')
    css = (Seek::Config.css_prepended || '').split(',').map { |c| "prepended/#{c}" }
    css << main
    css |= (Seek::Config.css_appended || '').split(',').map { |c| "appended/#{c}" }
    css.empty? ? '' : stylesheet_link_tag(*css)
  end

  def seek_javascript_tags(main = 'application')
    js = (Seek::Config.javascript_prepended || '').split(',').map { |c| "prepended/#{c}" }
    js << main
    js |= (Seek::Config.javascript_appended || '').split(',').map { |c| "appended/#{c}" }
    js.empty? ? '' : javascript_include_tag(*js)
  end

  def date_as_string(date, show_time_of_day = false, year_only_1st_jan = false)
    # for publications, if it is the first of jan, then it can be assumed it is just the year (unlikely have a publication on New Years Day)
    if year_only_1st_jan && !date.blank? && date.month == 1 && date.day == 1
      str = date.year.to_s
    else
      date = Time.parse(date.to_s) unless date.is_a?(Time) || date.blank?
      if date.blank?
        str = "<span class='none_text'>No date defined</span>"
      else
        str = date.localtime.strftime("#{date.day.ordinalize} %b %Y")
        str = date.localtime.strftime("#{str} at %H:%M") if show_time_of_day
      end
    end

    str.html_safe
  end

  # provide the block that shows the URL to the resource, including the version if it is a versioned resource
  # label is based on the application name, for example <label>FAIRDOMHUB ID: </label>
  def persistent_resource_id(resource)

    # FIXME: this contains some duplication of Seek::Rdf::RdfGeneration#rdf_resource - however not every model includes that Module at this time.
    # ... its also a bit messy handling the version
    url= if resource.class.name.include?("::Version")
      URI.join(Seek::Config.site_base_host + "/", "#{resource.parent.class.name.tableize}/","#{resource.parent.id}?version=#{resource.version}").to_s
    else
      URI.join(Seek::Config.site_base_host + "/", "#{resource.class.name.tableize}/","#{resource.id}").to_s
    end

    content_tag :p, class: :id do
      content_tag(:strong) do
        t('seek_id')+":"
      end + ' ' + link_to(url, url)
    end
  end

  def show_title(title)
    render partial: 'general/page_title', locals: { title: title }
  end

  def version_text
    "(v.#{SEEK::Application::APP_VERSION})"
  end

  def authorized_list(all_items, attribute, sort = true, max_length = 75, count_hidden_items = false)
    items = all_items.select(&:can_view?)
    title_only_items = if Seek::Config.is_virtualliver
                         (all_items - items).select(&:title_is_public?)
                       else
                         []
                       end

    if count_hidden_items
      original_size = all_items.size
      hidden_items = []
      hidden_items |= (all_items - items - title_only_items)
    else
      hidden_items = []
    end

    html = "<b>#{(items.size > 1 ? attribute.pluralize : attribute)}:</b> "
    if items.empty? && title_only_items.empty? && hidden_items.empty?
      html << "<span class='none_text'>No #{attribute}</span>"
    else
      items = items.sort_by { |i| get_object_title(i) } if sort
      title_only_items = title_only_items.sort_by { |i| get_object_title(i) } if sort

      list = items.collect { |i| link_to truncate(i.title, length: max_length), show_resource_path(i), title: get_object_title(i) }
      list += title_only_items.collect { |i| h(truncate(i.title, length: max_length)) }
      html << list.join(', ')
      if count_hidden_items && !hidden_items.empty?
        text = !items.empty? ? ' and ' : ''
        text << "#{hidden_items.size} hidden #{hidden_items.size > 1 ? 'items' : 'item'}"
        html << hidden_items_html(hidden_items, text)
      end

    end
    html.html_safe
  end

  def hidden_items_html(hidden_items, text = 'hidden item')
    html = "<span class='none_text'>#{text}</span>"
    contributor_links = hidden_item_contributor_links hidden_items
    unless contributor_links.empty?
      html << "<span class='none_text'> - Please contact: #{contributor_links.join(', ')}</span>"
    end
    html.html_safe
  end

  def hidden_item_contributor_links(hidden_items)
    contributor_links = []
    hidden_items = hidden_items.reject { |hi| hi.contributing_user.try(:person).nil? }
    hidden_items.sort! { |a, b| a.contributing_user.person.name <=> b.contributing_user.person.name }
    hidden_items.each do |hi|
      contributor_person = hi.contributing_user.person
      next unless current_user.try(:person) && hi.can_see_hidden_item?(current_user.person) && contributor_person.can_view?
      contributor_name = contributor_person.name
      contributor_link = "<a href='#{person_path(contributor_person)}'>#{h(contributor_name)}</a>"
      contributor_links << contributor_link if contributor_link && !contributor_links.include?(contributor_link)
    end
    contributor_links
  end

  def tabbar
    Seek::Config.is_virtualliver ? render(partial: 'general/tabnav_dropdown') : render(partial: 'general/menutabs')
  end

  # joins the list with seperator and the last item with an 'and'
  def join_with_and(list, seperator = ', ')
    return list.first if list.count == 1
    result = ''
    list.each do |item|
      result << item
      next if item == list.last
      result << if item == list[-2]
                  ' and '
                else
                  seperator
                        end
    end
    result
  end

  def tab_definition(options = {})
    options[:gap_before] ||= false
    options[:title] ||= options[:controllers].first.capitalize
    options[:path] ||= eval "#{options[:controllers].first}_path"

    attributes = (options[:controllers].include?(controller.controller_name.to_s) ? ' id="selected_tabnav"' : '')
    attributes += " class='tab_gap_before'" if options[:gap_before]

    link = link_to options[:title], options[:path]
    "<li #{attributes}>#{link}</li>".html_safe
  end

  # Classifies each result item into a hash with the class name as the key.
  #
  # This is to enable the resources to be displayed in the asset tabbed listing by class, or defined by .tab. Items not originating within SEEK are identified by is_external
  def classify_for_tabs(result_collection)
    results = {}

    result_collection.each do |res|
      tab = res.respond_to?(:tab) ? res.tab : res.class.name
      results[tab] = { items: [], hidden_count: 0, is_external: (res.respond_to?(:is_external_search_result?) && res.is_external_search_result?) } unless results[tab]
      results[tab][:items] << res
    end

    results
  end

  # selection of assets for new asset gadget
  def new_creatable_selection_list
    Seek::Util.user_creatable_types.collect { |c| [c.name.underscore.humanize, url_for(controller: c.name.underscore.pluralize, action: 'new')] }
  end

  def is_nil_or_empty?(thing)
    thing.nil? || thing.empty?
  end

  def empty_list_li_text(list)
    return "<li><div class='none_text'> None specified</div></li>".html_safe if is_nil_or_empty?(list)
  end

  def text_or_not_specified(text, options = {})
    text = text.to_s
    if text.nil? || text.chomp.empty?
      not_specified_text ||= options[:none_text]
      not_specified_text ||= 'No description specified' if options[:description]
      not_specified_text ||= 'Not specified'
      res = content_tag(:span, not_specified_text, class: 'none_text')
    else
      text.capitalize! if options[:capitalize]
      res = text.html_safe
      res = white_list(res)
      res = truncate_without_splitting_words(res, options[:length]) if options[:length]
      res = auto_link(res, html: { rel: 'nofollow' }, sanitize: false) if options[:auto_link]
      res = simple_format(res, {}, sanitize: false).html_safe if options[:description] == true || options[:address] == true

      res = mail_to(res) if options[:email]
      res = link_to(res, res, popup: true) if options[:external_link]
      res = res + '&nbsp;' + flag_icon(text) if options[:flag]
      res = '&nbsp;' + flag_icon(text) + link_to(res, country_path(res)) if options[:link_as_country]
    end
    res.html_safe
  end

  def tooltip(text)
    h(text)
  end

  # text in "caption" will be used to display the item next to the image_tag_for_key;
  # if "caption" is nil, item.name will be used by default
  def list_item_with_icon(icon_type, item, caption, truncate_to, custom_tooltip = nil, size = nil)
    list_item = '<li>'
    list_item += if icon_type.casecmp('flag').zero?
                   flag_icon(item.country)
                 elsif icon_type == 'data_file' || icon_type == 'sop'
                   file_type_icon(item)
                 else
                   image_tag_for_key(icon_type.downcase, nil, icon_type.camelize, nil, '', false, size)
                 end
    item_caption = ' ' + (caption.blank? ? item.title : caption)
    list_item += link_to truncate(item_caption, length: truncate_to), url_for(item), 'data-tooltip' => tooltip(custom_tooltip.blank? ? item_caption : custom_tooltip)
    list_item += '</li>'

    list_item.html_safe
  end

  def contributor(contributor, avatar = false, size = 100, you_text = false)
    return unless contributor

    if contributor.class.name == 'User'
      # this string will output " (you) " for current user next to the display name, when invoked with 'you_text == true'
      you_string = you_text && logged_in? && user.id == current_user.id ? "<small style='vertical-align: middle; color: #666666; margin-left: 0.5em;'>(you)</small>" : ''
      contributor_name = h(contributor.name)
      contributor_url = person_path(contributor)
      contributor_name_link = link_to(contributor_name, contributor_url)

      if avatar
        result = avatar(contributor_person, size, false, contributor_url, contributor_name, false)
        result += "<p style='margin: 0; text-align: center;'>#{contributor_name_link}#{you_string}</p>"
        return result.html_safe
      else
        return (contributor_name_link + you_string).html_safe
      end
    else
      return nil
    end
  end

  # this helper is to be extended to include many more types of objects that can belong to the
  # user - for example, SOPs and others
  def mine?(thing)
    return false if thing.nil?
    return false unless logged_in?

    c_id = current_user.id.to_i

    case thing.class.name
    when 'Person'
      return (current_user.person.id == thing.id)
    else
      return false
    end
  end

  def link_to_draggable(link_name, url, link_options = {})
    link_to(link_name, url, link_options)
  end

  def page_title(controller_name, _action_name)
    resource = resource_for_controller
    if resource && resource.respond_to?(:title) && resource.title
      h(resource.title)
    elsif PAGE_TITLES[controller_name]
      PAGE_TITLES[controller_name]
    else
      "The #{Seek::Config.application_name}"
    end
  end

  def preview_permission_popup_link(resource)
    locals = {}
    locals[:resource_name] = resource.class.name.underscore
    locals[:resource_id] = resource.id
    locals[:url] = preview_permissions_policies_path
    locals[:is_new_file] = resource.new_record?
    locals[:contributor_id] = resource.contributing_user.try(:id)
    render partial: 'assets/preview_permission_link', locals: locals
  end

  # Finn's truncate method. Doesn't split up words, tries to get as close to length as possible
  def truncate_without_splitting_words(text, length = 50)
    truncated_result = ''
    remaining_length = length
    stop = false
    truncated = false
    # lines
    text.split("\n").each do |l|
      # words
      l.split(' ').each do |w|
        # If we're going to go over the length, and we've not already
        if (remaining_length - w.length) <= 0 && !stop
          truncated = true
          stop = true
          # Decide if adding or leaving out the last word puts us closer to the desired length
          if (remaining_length - w.length).abs < remaining_length.abs
            truncated_result += (w + ' ')
          end
        elsif !stop
          truncated_result += (w + ' ')
          remaining_length -= (w.length + 1)
        end
      end
      truncated_result += "\n"
    end
    # Need some kind of whitespace before elipses or auto-link breaks
    html = truncated_result.strip + (truncated ? "\n..." : '')
    html.html_safe
  end

  def get_object_title(item)
    h(item.title)
  end

  def can_manage_announcements?
    admin_logged_in?
  end

  def show_or_hide_block(visible = true)
    html = 'display:' + (visible ? 'block' : 'none')
    html.html_safe
  end

  def toggle_appear_javascript(block_id, reverse: false)
    "#{reverse ? '!' : ''}this.checked ? $j('##{block_id}').slideDown() : $j('##{block_id}').slideUp();".html_safe
  end

  def folding_box(id, title, options = nil)
    render partial: 'assets/folding_box', locals:         { fold_id: id,
                                                            fold_title: title,
                                                            contents: options[:contents],
                                                            hidden: options[:hidden] }
  end

  def resource_tab_item_name(resource_type, pluralize = true)
    resource_type = resource_type.singularize
    if resource_type == 'Assay'
      result = t('assays.assay')
    else
      translated_resource_type = translate_resource_type(resource_type)
      result = translated_resource_type.include?('translation missing') ? resource_type : translated_resource_type
    end
    pluralize ? result.pluralize : result
  end

  def internationalized_resource_name(resource_type, pluralize = true)
    resource_type = resource_type.singularize
    if resource_type == 'Assay'
      result = I18n.t('assays.assay')
    elsif resource_type == 'TavernaPlayer::Run'
      result = 'Run'
    else
      translated_resource_type = translate_resource_type(resource_type)
      result = translated_resource_type.include?('translation missing') ? resource_type : translated_resource_type
    end
    pluralize ? result.pluralize : result
  end

  def translate_resource_type(resource_type)
    I18n.t(resource_type.underscore.to_s)
  end

  def add_return_to_search
    referer = request.headers['Referer'].try(:normalize_trailing_slash)
    search_path = main_app.search_url.normalize_trailing_slash
    root_path = main_app.root_url.normalize_trailing_slash
    request_uri = request.fullpath.try(:normalize_trailing_slash)
    unless request_uri.include?(root_path)
      request_uri = root_path.chop + request_uri
    end

    if referer == search_path && referer != request_uri && request_uri != root_path
      javascript_tag "
        if (window.history.length > 1){
          var a = document.createElement('a');
          a.onclick = function(){ window.history.back(); };
          a.onmouseover = function(){ this.style.cursor='pointer'; }
          a.appendChild(document.createTextNode('Return to search'));
          a.style.textDecoration='underline';
          document.getElementById('return_to_search').appendChild(a);
        }
      "
      # link_to_function 'Return to search', "window.history.back();"
    end
  end

  def no_deletion_explanation_message(clz)
    no_deletion_explanation_messages[clz] || "You are unable to delete this #{clz.name}. It might be published"
  end

  def no_deletion_explanation_messages
    { Assay => "You cannot delete this #{I18n.t('assays.assay')}. It might be published or it has items associated with it.",
      Study => "You cannot delete this #{I18n.t('study')}. It might be published or it has #{I18n.t('assays.assay').pluralize} associated with it.",
      Investigation => "You cannot delete this #{I18n.t('investigation')}. It might be published or it has #{I18n.t('study').pluralize} associated with it.",
      Strain => 'You cannot delete this Strain. Samples associated with it or you are not authorized.',
      Project => "You cannot delete this #{I18n.t 'project'}. It may have people associated with it.",
      Institution => 'You cannot delete this Institution. It may have people associated with it.',
      SampleType => 'You cannot delete this Sample Type, it may have Samples associated with it or have another Sample Type linked to it',
      SampleControlledVocab => 'You can delete this Controlled Vocabulary, it may be associated with a Sample Type' }
  end

  def unable_to_delete_text(model_item)
    no_deletion_explanation_message(model_item.class).html_safe
  end

  # returns a new instance of the string describing a resource type, or nil if it is not applicable
  def instance_of_resource_type(resource_type)
    resource = nil
    begin
      resource_class = resource_type.classify.constantize unless resource_type.nil?
      resource = resource_class.send(:new) if !resource_class.nil? && resource_class.respond_to?(:new)
    rescue NameError => e
      logger.error("Unable to find constant for resource type #{resource_type}")
    end
    resource
  end

  # returns the class associated with the controller, e.g. DataFile for data_files
  #
  def klass_from_controller(c = controller_name)
    c.singularize.camelize.constantize
  end

  # returns the instance for the resource for the controller, e.g @data_file for data_files
  def resource_for_controller(c = controller_name)
    eval "@#{c.singularize}"
  end

  # returns the count of the total visible items, and also the count of the all items, according to controller_name
  # primarily used for the metrics on the item index page
  def resource_count_stats
    klass = klass_from_controller(controller_name)
    full_total = klass.count
    visible_total = if klass.authorization_supported?
                      klass.all_authorized_for('view').count
                    elsif klass.is_a?(Person) && Seek::Config.is_virtualliver && User.current_user.nil?
                      0
                    else
                      klass.count
                    end
    [visible_total, full_total]
  end

  def describe_visibility(model)
    text = '<strong>Visibility:</strong> '

    if model.policy.access_type == Policy::NO_ACCESS
      css_class = 'private'
      text << 'Private '
      text << 'with some exceptions ' unless model.policy.permissions.empty?
      text << image('lock', style: 'vertical-align: middle')
    else
      css_class = 'public'
      text << "Public #{image('world', style: 'vertical-align: middle')}"
    end

    "<span class='visibility #{css_class}'>#{text}</span>".html_safe
  end

  def cancel_button(path, html_options = {})
    html_options[:class] ||= ''
    html_options[:class] << ' btn btn-default'
    text = html_options.delete(:button_text) || 'Cancel'
    link_to text, path, html_options
  end

  def using_docker?
    Seek::Docker.using_docker?
  end

  private

  PAGE_TITLES = { 'home' => 'Home', 'projects' => I18n.t('project').pluralize, 'institutions' => 'Institutions', 'people' => 'People', 'sessions' => 'Login', 'users' => 'Signup', 'search' => 'Search',
                  'assays' => I18n.t('assays.assay').pluralize.capitalize, 'sops' => I18n.t('sop').pluralize, 'models' => I18n.t('model').pluralize, 'data_files' => I18n.t('data_file').pluralize,
                  'publications' => 'Publications', 'investigations' => I18n.t('investigation').pluralize, 'studies' => I18n.t('study').pluralize,
                  'samples' => 'Samples', 'strains' => 'Strains', 'organisms' => 'Organisms', 'biosamples' => 'Biosamples',
                  'presentations' => I18n.t('presentation').pluralize, 'programmes' => I18n.t('programme').pluralize, 'events' => I18n.t('event').pluralize, 'help_documents' => 'Help' }.freeze
end

class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  def fancy_multiselect(association, options = {})
    @template.fancy_multiselect object, association, options
  end

  def subform_delete_link(link_text = 'remove', link_options = {}, hidden_field_options = {})
    hidden_field(:_destroy, hidden_field_options) + @template.link_to_function(link_text, "$(this).previous().value = '1';$(this).up().hide();", link_options)
  end
end

ActionView::Base.default_form_builder = ApplicationFormBuilder
