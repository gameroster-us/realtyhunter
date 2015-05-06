# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

@password = "713lorimer"
users = User.create([
	{ fname: 'Raquel', lname: 'Bujans',   email: 'rbujans@myspacenyc.com', bio: "blah blah blah", password:@password, password_confirmation:@password},
	{ fname: 'Nir',    lname: 'Mizrachi', email: 'nir@myspacenyc.com',     bio: "blah blah blah", password:@password, password_confirmation:@password},
	{ fname: 'Cheryl', lname: 'Hoyles',   email: 'info@myspacenyc.com',    bio: "blah blah blah", password:@password, password_confirmation:@password},
	])

50.times do |n|
  fname  = Faker::Name.first_name
  lname  = Faker::Name.last_name
  email = "example-#{n+1}@railstutorial.org"
  password = "password"
  User.create!(fname:  fname,
  						 lname: lname,
               email: email,
               password:              password,
               password_confirmation: password)
end