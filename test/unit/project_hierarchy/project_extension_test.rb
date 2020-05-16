require 'test_helper'
require 'project_hierarchy_test_helper'

class ProjectExtensionTest < ActiveSupport::TestCase
  include ProjectHierarchyTestHelper

  test 'change parent' do
    parent_proj = Factory(:project, title: 'test parent')
    proj = Factory(:project, parent_id: parent_proj.id)
    assert_equal proj.parent, parent_proj
    assert parent_proj.descendants.include?(proj)
    parent_proj_changed = Factory(:project, title: 'changed test parent')
    proj.parent = parent_proj_changed
    disable_authorization_checks { proj.save! }

    assert_equal 'changed test parent', proj.parent.title
  end

  test 'create ancestor work groups after adding institutions' do
    institutions = [Factory(:institution), Factory(:institution)]
    parent_proj = Factory :project, title: 'parent proj'
    project = Factory :project, parent: parent_proj
    project.institutions = institutions

    institutions.each do |ins|
      assert parent_proj.institutions.include?(ins)
    end
  end


  test 'related resource to parent project' do
    parent_proj = Factory :project
    proj = Factory :project, parent: parent_proj

    Project::RELATED_RESOURCE_TYPES.each do |type|
      proj.send "#{type.underscore.pluralize}=".to_sym, [Factory(type.underscore.to_sym)] unless %w(Study Assay).include?(type)

      proj.send("#{type.underscore.pluralize}".to_sym).each do |resource|
        assert parent_proj.send("related_#{type.underscore.pluralize}".to_sym).include?(resource)
      end
    end
  end

  test 'projects with children cannot be deleted' do
    refute @proj.children.empty?
    refute @proj.can_delete?(Factory(:admin))
  end
end
