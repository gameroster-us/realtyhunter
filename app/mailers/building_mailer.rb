class BuildingMailer < ApplicationMailer

  def inaccuracy_reported(building, reporter)
    data_enterers = building.company.data_enterers
    if !data_enterers
    	data_enterers = building.company.admins
    end
    @building = building
    @reporter = reporter
    mail to: data_enterers.map(&:email), 
    	subject: "Inaccuracy Reported for #{building.street_address}", from: @reporter.email
  end
end
