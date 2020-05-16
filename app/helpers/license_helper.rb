require 'json'
require 'seek/license'

module LicenseHelper
  def license_select(name, selected = nil, opts = {})
    select_tag(name, options_for_select(license_options(opts), selected), opts)
  end

  def grouped_license_select(name, selected = nil, opts = {})
    select_tag(name, grouped_options_for_select(grouped_license_options(opts), selected), opts)
  end

  def describe_license(id, source = nil)
    license = Seek::License.find(id, source)
    if license && !license.is_null_license?
      if license.url.blank?
        license.title
      else
        link_to(license.title, license.url, target: :_blank)
      end
    else
      content_tag(:span, 'No license specified', class: 'none_text')
    end
  end

  # whether to enable to auto selection of the license based on the selected project
  # only enabled if it is a new item, and the logged in person belongs to projects with a default license
  def enable_auto_project_license?
    resource_for_controller.try(:new_record?) && logged_in_and_registered? &&
      default_license_for_current_user
  end

  def default_license_for_current_user
    current_user.person.projects_with_default_license.any?
  end

  # JSON that creates a lookup for project license by id
  def project_licenses_json
    projects = current_user.person.projects_with_default_license
    Hash[projects.collect { |proj| [proj.id, proj.default_license] }].to_json.html_safe
  end

  private

  def license_values(opts = {})
    opts.delete(:source) || Seek::License::OPENDEFINITION[:all]
  end

  def license_options(opts = {})
    license_values(opts).map { |value| [value['title'], value['id'], { 'data-url' => value['url'] }] }
  end

  def grouped_license_options(opts = {})
    grouped_licenses = sort_grouped_licenses(group_licenses(opts))

    grouped_licenses.each do |_, licenses|
      licenses.map! { |value| [value['title'], value['id'], { 'data-url' => value['url'] }] }
    end

    grouped_licenses
  end

  def sort_grouped_licenses(licenses)
    licenses.sort_by do |pair|
      case pair[0]
      when 'Recommended'
        0
      when 'Generic'
        1
      else
        2
      end
    end
  end

  def group_licenses(opts)
    license_values(opts).group_by do |l|
      if l.key?('is_generic') && l['is_generic']
        'Generic'
      elsif l.key?('od_recommended') && l['od_recommended']
        'Recommended'
      else
        'Other'
      end
    end.to_a
  end
end
