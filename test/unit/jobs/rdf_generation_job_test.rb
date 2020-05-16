require 'test_helper'

class RdfGenerationJobTest < ActiveSupport::TestCase
  def setup
    Delayed::Job.delete_all
  end

  def teardown
    Delayed::Job.delete_all
  end

  test 'rdf generation job created after save' do
    item = nil

    assert_difference('Delayed::Job.count', 2) do
      item = Factory :project
    end
    handlers = Delayed::Job.all.collect(&:handler).join(',')
    assert_includes(handlers, 'RdfGenerationJob')

    Delayed::Job.delete_all # necessary, otherwise the next assert will fail since it won't create a new job if it already exists as pending

    assert_difference('Delayed::Job.count', 2) do
      item.title = 'sdfhsdfkhsdfklsdf2'
      disable_authorization_checks { item.save! }
    end
    handlers = Delayed::Job.all.collect(&:handler).join(',')
    assert_includes(handlers, 'RdfGenerationJob')

    # check a new job isn't created when nothing (except the last used timestamp) has changed
    item = Factory :model
    item.save!
    item.last_used_at = Time.now
    assert_no_difference('Delayed::Job.count') do
      disable_authorization_checks { item.save! }
    end
  end

  test 'rdf generation job created after policy change' do
    item = Factory(:sop, policy: Factory(:public_policy))
    Delayed::Job.delete_all

    handlers = Delayed::Job.all.collect(&:handler).join(',')
    refute_includes(handlers, 'RdfGenerationJob')

    item.policy.access_type = Policy::NO_ACCESS
    disable_authorization_checks do
      assert_difference('Delayed::Job.count', 1) do
        item.policy.save!
      end
    end

    handlers = Delayed::Job.all.collect(&:handler).join(',')
    assert_includes(handlers, 'RdfGenerationJob')
  end

  test 'rdf generation job not created after policy change for non rdf supported entity' do
    item = Factory(:event, policy: Factory(:public_policy))
    Delayed::Job.delete_all

    handlers = Delayed::Job.all.collect(&:handler).join(',')
    refute_includes(handlers, 'RdfGenerationJob')

    item.policy.access_type = Policy::NO_ACCESS
    disable_authorization_checks do
      assert_no_difference('Delayed::Job.count') do
        item.policy.save!
      end
    end

    handlers = Delayed::Job.all.collect(&:handler).join(',')
    refute_includes(handlers, 'RdfGenerationJob')
  end

  test 'create job' do
    item = Factory(:assay)

    Delayed::Job.delete_all

    assert_difference('Delayed::Job.count', 1) do
      RdfGenerationJob.new(item).queue_job
    end
    job = Delayed::Job.last
    assert_equal 2, job.priority
  end

  test 'skip items that dont support rdf' do
    item = Factory(:event)
    refute item.rdf_supported?

    assert_empty RdfGenerationJob.new(item).gather_items

    item = Factory(:sop)
    assert item.rdf_supported?

    assert_equal [item], RdfGenerationJob.new(item).gather_items
  end

  test 'exists' do
    project = Factory(:project)
    project2 = Factory(:project)

    Delayed::Job.delete_all

    refute RdfGenerationJob.new(project, true).exists?
    refute RdfGenerationJob.new(project, false).exists?

    Delayed::Job.enqueue RdfGenerationJob.new(project, true), priority: 1, run_at: Time.now
    assert RdfGenerationJob.new(project, true).exists?
    assert RdfGenerationJob.new(project, false).exists?, 'should say that it exists, because one already exists with refresh_dependents true'
    refute RdfGenerationJob.new(project2, true).exists?
    refute RdfGenerationJob.new(project2, false).exists?

    Delayed::Job.enqueue RdfGenerationJob.new(project2, false), priority: 1, run_at: Time.now
    assert RdfGenerationJob.new(project2, false).exists?
    refute RdfGenerationJob.new(project2, true).exists?, "shouldn't reports exists, because one already exists with refresh_dependents false, but this is true"
  end

  test 'perform' do
    item = Factory(:assay, policy: Factory(:public_policy))

    expected_rdf_file = File.join(Rails.root, 'tmp/testing-filestore/rdf/public', "Assay-test-#{item.id}.rdf")
    assert_equal expected_rdf_file, item.rdf_storage_path
    FileUtils.rm expected_rdf_file if File.exist?(expected_rdf_file)

    job = RdfGenerationJob.new(item)
    job.perform

    assert File.exist?(expected_rdf_file)
    rdf = ''
    open(expected_rdf_file) do |f|
      rdf = f.read
    end
    assert_equal item.to_rdf, rdf
    FileUtils.rm expected_rdf_file
    refute File.exist?(expected_rdf_file)
  end

  test 'should not allow duplicates' do
    assay = Factory(:assay)
    Delayed::Job.delete_all
    refute RdfGenerationJob.new(assay, false).exists?
    assert_difference('Delayed::Job.count', 1) do
      RdfGenerationJob.new(assay, false).queue_job
    end

    assert_no_difference('Delayed::Job.count') do
      RdfGenerationJob.new(assay, false).queue_job
    end

    refute RdfGenerationJob.new(assay, true).exists?
    assert_difference('Delayed::Job.count', 1) do
      RdfGenerationJob.new(assay, true).queue_job
    end

    assert_no_difference('Delayed::Job.count') do
      RdfGenerationJob.new(assay, true).queue_job
    end
  end
end
