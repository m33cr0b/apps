require 'simple_worker'
# For the pretty time syntax, we need active_support/core_ext
require "active_support/core_ext"

load "tsn_parser_worker.rb"
load "railscasts_parser_worker.rb"
require 'yaml'
conf = YAML.load_file('config.yml')

# Create a project at SimpleWorker.com and enter your credentials below
#-------------------------------------------------------------------------
SimpleWorker.configure do |config|
  config.project_id = conf[:project_id]
  config.token = conf[:token]
end
#-------------------------------------------------------------------------

# Now let's create a third worker and schedule it to run in 3 minutes, every minute, 5 times.
worker = TsnParserWorker.new
worker.schedule(:start_at => 2.minutes.since, :run_every => 3600, :run_times => 1000000000)

railscasts_worker = RailscastsParserWorker.new
railscasts_worker.schedule(:start_at => 2.minutes.since, :run_every => (4 * 3600), :run_times => 1000000000)



def self.wait_for_task(params={})
  tries  = 0
  status = nil
  sleep 1
  while tries < 60
    status = status_for(params)
    puts 'status = ' + status.inspect
    if status["status"] == "complete" || status["status"] == "error"
      break
    end
    sleep 2
  end
  status
end

def self.status_for(ob)
  if ob.is_a?(Hash)
    ob[:schedule_id] ? WORKER.schedule_status(ob[:schedule_id]) : WORKER.status(ob[:task_id])
  else
    ob.status
  end
end

status3 = wait_for_task(worker)
