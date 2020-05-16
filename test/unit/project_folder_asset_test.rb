require 'test_helper'

class ProjectFolderAssetTest < ActiveSupport::TestCase
  test 'associations' do
    pf = Factory :project_folder
    person = Factory(:person,project:pf.project)
    sop = Factory :sop, policy: Factory(:public_policy), projects: [pf.project], contributor:person
    pfa = ProjectFolderAsset.create asset: sop, project_folder: pf
    pfa.save!
    pfa.reload
    assert_equal sop, pfa.asset
    assert_equal pf, pfa.project_folder

    pf.reload
    assert_equal 1, pf.assets.count
    assert pf.assets.include?(sop)
    sop.reload
    assert_equal 1, sop.folders.count
    assert sop.folders.include?(pf)
  end

  test 'dependents destroyed' do
    pf = Factory :project_folder
    person = Factory(:person,project:pf.project)
    sop = Factory :sop, policy: Factory(:public_policy), projects: [pf.project], contributor: person
    pfa = ProjectFolderAsset.create asset: sop, project_folder: pf

    assert_difference('ProjectFolderAsset.count', -1) do
      sop.destroy
      assert_nil ProjectFolderAsset.find_by_id(pfa.id)
    end

    pf = Factory :project_folder
    person = Factory(:person,project:pf.project)
    sop = Factory :sop, policy: Factory(:public_policy), projects: [pf.project], contributor:person
    pfa = ProjectFolderAsset.create asset: sop, project_folder: pf

    assert_difference('ProjectFolderAsset.count', -1) do
      pf.destroy
      assert_nil ProjectFolderAsset.find_by_id(pfa.id)
    end
  end

  test 'assets added to default folder upon creation' do
    pf = Factory :project_folder, title: 'Unsorted items', editable: false, incoming: true
    pf2 = Factory :project_folder, title: 'Unsorted items', editable: false, incoming: true

    person = Factory(:person,project: pf.project)
    person.add_to_project_and_institution(pf2.project, person.institutions.first)

    model = Factory.build :model, projects: [pf.project, pf2.project], policy: Factory(:public_policy), contributor: person

    model.save!

    pf.reload
    model.reload
    assert_equal 1, pf.assets.count
    assert_equal 1, pf.assets.count
    assert pf.assets.include?(model)
    assert pf2.assets.include?(model)
    assert_equal 2, model.folders.count
    assert model.folders.include?(pf)
    assert model.folders.include?(pf2)
  end

  test 'validations' do
    pfa = ProjectFolderAsset.new
    pf = Factory :project_folder
    person = Factory(:person, project: pf.project)
    model = Factory :model, policy: Factory(:public_policy), projects: [pf.project], contributor: person

    assert !pfa.valid?

    # must have asset and folder
    pfa.asset = model
    assert !pfa.valid?
    pfa.project_folder = pf
    assert pfa.valid?
    pfa.asset = nil
    assert !pfa.valid?

    # asset must belong in same project as folder
    pfa.asset = model
    assert pfa.valid?
    person.add_to_project_and_institution(Factory(:project),person.institutions.first)
    pfa.asset = Factory :model, policy: Factory(:public_policy), projects: person.projects, contributor: person
    assert pfa.valid?

    other_person = Factory(:person)
    pfa.asset = Factory :model, policy: Factory(:public_policy), projects: other_person.projects,contributor: other_person
    assert !pfa.valid?

    # final check for save
    pfa.asset = model
    assert pfa.save
  end

  test 'assign existing assets to folders' do

    proj = Factory :project
    contributor = Factory(:person,project:proj)

    old_sop = Factory :sop, policy: Factory(:public_policy), projects: [proj], contributor:contributor
    old_model = Factory :model, policy: Factory(:public_policy), projects: [proj], contributor:contributor
    old_presentation = Factory :presentation, policy: Factory(:public_policy), projects: [proj], contributor:contributor
    old_publication = Factory :publication, policy: Factory(:public_policy), projects: [proj], contributor:contributor
    old_datafile = Factory :data_file, policy: Factory(:public_policy), projects: [proj], contributor:contributor
    old_private_datafile = Factory :data_file, policy: Factory(:private_policy), projects: [proj], contributor:contributor
    old_datafile_other_proj = Factory :model, policy: Factory(:public_policy), contributor:Factory(:person)

    pf = Factory :project_folder, project: proj
    pf_incoming = Factory :project_folder, project: pf.project, title: 'New items', incoming: true
    already_assigned_sop = Factory :sop, policy: Factory(:public_policy), projects: [proj], contributor:contributor
    pf.add_assets already_assigned_sop

    ProjectFolderAsset.assign_existing_assets(proj)
    pf.reload
    pf_incoming.reload

    assert_equal 1, pf.assets.count
    assert pf.assets.include?(already_assigned_sop)

    assert_equal 7, pf_incoming.assets.count
    assert pf_incoming.assets.include?(old_sop)
    assert pf_incoming.assets.include?(old_model)
    assert pf_incoming.assets.include?(old_presentation)
    assert pf_incoming.assets.include?(old_publication)
    assert pf_incoming.assets.include?(old_datafile)
    assert pf_incoming.assets.include?(old_private_datafile)
    assert !pf_incoming.assets.include?(old_datafile_other_proj)
  end
end
