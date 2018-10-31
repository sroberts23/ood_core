require "spec_helper"
require "ood_core/job/adapters/sge"
require "ood_core/job/adapters/sge/batch"

def load_resource_file(file_name)
  File.open(file_name, 'r') { |f| f.read }
end

describe OodCore::Job::Adapters::Sge::Batch do
  subject(:batch) {described_class.new({:conf => '', :cluster => '', :bin => ''})}
  let(:jobs_from_qstat) {[
    OodCore::Job::Info.new( # Running job, w/ project
      :id => '88',
      :job_owner => 'vagrant',
      :accounting_id => 'project_a',
      :job_name => 'job_15',
      :status => :running,
      :procs => 1,
      :queue_name => 'general.q',
      :dispatch_time => DateTime.parse('2018-10-10T14:37:16').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => Time.now.to_i - DateTime.parse('2018-10-10T14:37:16').to_time.to_i
    ),
    OodCore::Job::Info.new( # Queued job, w/ project
      :id => '1045',
      :job_owner => 'vagrant',
      :accounting_id => 'project_b',
      :job_name => 'job_RQ',
      :status => :queued,
      :procs => 1,
      :queue_name => 'general.q',
      :submission_time => DateTime.parse('2018-10-09T18:47:05').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => 0
    ),
    OodCore::Job::Info.new( # Queued job w/o project
      :id => '1046',
      :job_owner => 'vagrant',
      :job_name => 'job_RR',
      :status => :queued,
      :procs => 1,
      :queue_name => 'general.q',
      :submission_time => DateTime.parse('2018-10-09T18:47:05').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => 0
    ),
    OodCore::Job::Info.new( # Held job w/o project
      :id => '44',
      :job_owner => 'vagrant',
      :job_name => 'c_d',
      :status => :queued_held,
      :procs => 1,
      :queue_name => 'general.q',
      :submission_time => DateTime.parse('2018-10-09T18:35:12').to_time.to_i,
      :wallclock_limit => 360,
      :wallclock_time => 0
    )
  ]}

  let(:job_from_qacct) {
    OodCore::Job::Info.new(
      :accounting_id => nil,
      :allocated_nodes => [],
      :cpu_time => nil,
      :dispatch_time => Time.parse('2018-10-25 13:16:29 +0000'),
      :id => "1072",
      :job_name => "job_7",
      :job_owner => "vagrant",
      :native => nil,
      :procs => 1,
      :queue_name => "general.q",
      :status => :completed,
      :submission_time => Time.parse('2018-10-24 20:22:31 +0000'),
      :submit_host => nil,
      :wallclock_limit => nil,
      :wallclock_time => 361
    )
  }

  describe "#get_all" do
    context "when no owner is set" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/qstat.xml') }
      }

      it "returns the correct job info" do
        expect(batch.get_all).to eq(jobs_from_qstat)
      end
    end

    context "when owner is set to vagrant" do
      before {
        allow(batch).to receive(:call) {''}
      }

      it "expects to have qstat called with -u vagrant" do
        batch.get_all(owner: 'vagrant')
        expect(batch).to have_received(:call).with('qstat',  '-r', '-xml', '-u', 'vagrant')
      end
    end
  end

  describe "#get_info_enqueued_job" do
    context "when the specific job is in the queue" do
      before {
        allow(batch).to receive(:get_all) { jobs_from_qstat }
      }

      it "expects to receive the correct job info" do
        expect(batch.get_info_enqueued_job('88') ).to eq(jobs_from_qstat.first)
      end
    end

    context "when the specific job is absent from the queue" do
      before {
        allow(batch).to receive(:get_all) { jobs_from_qstat }
      }

      it "expects to receive a job with status completed" do
        expect(batch.get_info_enqueued_job('1234') ).to eq(OodCore::Job::Info.new(id: '1234', status: :completed))
      end
    end
  end

  describe "#get_info_historical_job" do
    context "when the specific job is in the accounting database" do
      before {
        allow(batch).to receive(:call) { load_resource_file('spec/job/adapters/sge/output_examples/qacct.txt') }
      }

      it "returns the correct job info" do
        expect(batch.get_info_historical_job('1072')).to eq(job_from_qacct)
      end
    end

    context "when the specific job is absent from the accounting database" do
      before {
        allow(batch).to receive(:call).and_raise(OodCore::Job::Adapters::Sge::Batch::Error)
      }

      it "returns nil to signal nothing was found" do
        expect(batch.get_info_historical_job('10372')).to eq(nil)
      end
    end
  end
end



