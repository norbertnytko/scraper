require 'httparty'
require 'pry'
require 'nokogiri'
require 'ostruct'
require 'csv'

class Speaker < OpenStruct; end

class ExpoClient
  include HTTParty
  BASE_URL = 'https://eu.augmentedworldexpo.com'

  def speakers_page
    self.class.get("#{BASE_URL}/speakers/").body
  end

  def speaker_page(slug)
    self.class.get("#{BASE_URL}/speakers/#{slug}").body
  end
end

class Parser
  def speaker_slugs(page)
    body = Nokogiri::HTML(page)
    body.css(".speakers__person").map(&:attributes).map { |speaker| speaker['href'].value.split('/').last }
  end

  def speaker_info(page)
    body = Nokogiri::HTML(page)
    social = body.css('.social').first.children.map(&:attributes).select { |el| el['href'] }.map { |el| el['href'].value }

    Speaker.new(
      name: body.css('.site__title_white').first.children.first.text,
      additiona_info: body.css('.speaker-info__text').first.children.first.text.strip,
      twitter: social.select { |l| l[/twitter/] }.first,
      linkedin: social.select { |l| l[/linkedin/] }.first
    )
  end
end

class SpeakersInfo
  def initialize(parser: Parser.new, expo_clinet: ExpoClient.new)
    @expo_clinet = expo_clinet
    @parser = parser
  end

  def call
    speakers
  end

  private

  attr_reader :expo_clinet, :parser

  def slugs
    parser.speaker_slugs(expo_clinet.speakers_page)
  end

  def speakers
    slugs.map do |slug|
      puts "###"
      puts "Getting data from 'https://eu.augmentedworldexpo.com/speakers/#{slug}'"
      page = expo_clinet.speaker_page(slug)
      parser.speaker_info(page)
    end
  end
end

class CSVExporter
  def call(speakers)
    CSV.open("speakers.csv", "wb") do |csv|
      csv << ["Name", "Role", "Twitter", "Linkedin"]
      speakers.each do |speaker|
        csv << [speaker.name, speaker.additiona_info, speaker.twitter, speaker.linkedin]
      end
    end
  end
end

class App
  def initialize(speakers_info: SpeakersInfo.new, csv_exporter: CSVExporter.new)
    @speakers_info = speakers_info
    @csv_exporter  = csv_exporter
  end

  def self.run
    new.run
  end

  def run
    csv_exporter.call(speakers_info.call)
  end

  private

  attr_reader :speakers_info, :csv_exporter
end

App.run
