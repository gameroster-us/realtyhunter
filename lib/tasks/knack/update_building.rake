namespace :knack do
  desc "update building in knack"
  task :update_building => :environment do
    include KnackInterface

    log = ActiveSupport::Logger.new('log/knack_update_building.log')
    start_time = Time.now

    puts "Sending updated building to knack..."
    log.info "Sending updated building to knack..."

    cb = UpdateBuilding
    cb.perform(3631) # 173 Herkimer

    puts "Done!\n"
    log.info "Done!\n"
    end_time = Time.now
    duration = (start_time - end_time) / 1.minute
    log.info "Task finished at #{end_time} and last #{duration} minutes."
    log.close
  end
end
