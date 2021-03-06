require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def clean_phone_number(number)
  number.gsub!(/\D/, '')
  if number.length == 11 && number.start_with?('1')
    number[1..10]
  elsif number.length == 10
    number
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def parse_regdate(regdate)
  time = Time.strptime(regdate, "%m/%d/%y %R")
  weekday = time.strftime("%A")
  hour = time.hour
  { day: weekday, hour: hour }
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registrations_by_hour = {}
registrations_by_weekday = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone_number(row[:homephone])
  time = parse_regdate(row[:regdate])

  registrations_by_weekday.include?(time[:day]) ? registrations_by_weekday[time[:day]] += 1 : registrations_by_weekday[time[:day]] = 1
  registrations_by_hour.include?(time[:hour]) ? registrations_by_hour[time[:hour]] += 1 : registrations_by_hour[time[:hour]] = 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

sorted_hour = registrations_by_hour.sort_by { |_key, value| value }
sorted_hour.each do |key, value|
  puts "#{key}:00 had #{value} registrations."
end
sorted_day = registrations_by_weekday.sort_by { |_key, value| value }
sorted_day.each do |key, value|
  puts "#{key} had #{value} registrations."
end
