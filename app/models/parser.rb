#encoding: UTF-8
require 'mechanize'
require 'date'
require_relative 'apartment.rb'

class Parser

  BASE_PATH = "http://www.finn.no/finn/realestate/lettings/object?finnkode="

  def self.base_path
    return BASE_PATH
  end

  NOT_FOUND_ERROR = "Insertion not found"
  PARSE_ERROR = "Error during import"

  def parse(finn_id)
    agent = Mechanize.new
    begin
      page = agent.get("#{BASE_PATH}#{finn_id}")
    rescue Exception => ex
      return NOT_FOUND_ERROR
    end
    begin
      apartment = Apartment.new
      apartment.title = page.search("h1.mal").first.content
      image_src = page.search("#image_0").first
      if image_src
        apartment.image_src = image_src['data-main']
      end
      price_infos = get_prices(page)
      totalprice = get_value_of(price_infos, "Totalpris").split(",").first
      puts "Price infos = #{price_infos} and totalprice=#{totalprice}"
      apartment.totalprice = totalprice ? totalprice.gsub(/[^0-9]/, "").to_i : nil
      offerprice = get_value_of(price_infos, "Prisantydning").split(",").first
      apartment.rent = offerprice ? offerprice.gsub(/[^0-9]/, "").to_i : nil
      commondebt = get_value_of(price_infos, "Fellesgjeld").split(",").first
      apartment.debt = commondebt ? commondebt.gsub(/[^0-9]/, "").to_i : nil
      house_info = parse_objectinfo(page, "Prisdetaljer")
      sizes = [get_value_of(house_info, "Primærrom"), get_value_of(house_info, "Boligareal"), get_value_of(house_info, "Bruksareal")]
      apartment.size = sizes.select { |x| x != "" }.first 
      apartment.floor = get_value_of(house_info, "Etasje").gsub(/[^0-9]/, "").to_i
      apartment.bedrooms = get_value_of(house_info, "Soverom").gsub(/[^0-9]/, "").to_i
      apartment.location = page.search("div[@data-automation-id='map-container']//a").first.inner_html
      dates = get_value_of(house_info, "Leieperiode")
      if dates != ""
        if dates =~ /\-/
          apartment.start_date = DateTime.parse(dates.split("-")[0].strip)
          apartment.end_date   = DateTime.parse(dates.split("-")[1].strip)
        else
          apartment.start_date = DateTime.parse(dates.strip)
        end
      end
      parse_features(page).each do |text|
        feature = Feature.find_by_description(text)
        unless feature
          feature = Feature.new
          feature.description = text
        end
        apartment.features << feature
      end
      apartment.contact_infos = parse_contacts(page).map do |values|
        contact = ContactInfo.new
        contact.type = values.keys.first
        contact.value = values.values.first
        contact
      end
      apartment.html_description = get_description_html(page)
      apartment.code = finn_id
      return apartment
    rescue Exception => ex
      return PARSE_ERROR
    end
  end

  def update_locations
    agent = Mechanize.new
    Apartment.all.each do |apt|
      page = agent.get("#{BASE_PATH}#{apt.code}")
      element = page.search(".map-track").first
      if element && element.inner_html != ""
        begin
        apt.location = element.inner_html
        rescue Exception => ex
          p ex.message
        end
      end
      apt.save
    end

  end

  def parse_all_page(page_url)
    agent = Mechanize.new
    apartments = [] 
    page = agent.get(page_url)
    page.search('div.objectinfo//h2.mtn//a').each do |elem|
      finn_id = elem['href'].split("=").last
      existing_apartment = Apartment.where("code = ?", finn_id).first
      apartments << (existing_apartment || self.parse(finn_id))
    end
    return apartments
  end

  def get_prices(page)
    result = []
    target = page.search('div.mod//div.inner//div.bd.objectinfo').first
      if target 
        target.search('dl').each do |element|
          extract_from_dtable(result, element)
        end
      end
    return result
  end

  private 
  def get_value_of(values, target)
    value = values.select { |x| x[target] }.first
    return value && value[target] ? value[target] : ""
  end

  def extract_from_dtable(result, dtable)
    labels = dtable.search('dt')
    values = dtable.search('dd')
    labels.zip(values).each do |pair|
      if pair && pair[0] && pair[1]
        result << { pair[0].inner_text => pair[1].content.strip.split("\r\n").first.strip }
      end
    end
  end

  def parse_contacts(page)
    result = []
    target = page.search('#brokerContact-0').first
      if target 
        target.search('dl').each do |element|
          extract_from_dtable(result, element)
        end
      end
    return result
  end

  def parse_objectinfo(page, header)
    result = []
    page.search('div.bd.objectinfo').each do |test|
      if test.search('h2').first && test.search('h2').first.inner_text == header
        test.search('dl.multicol').each do |element|
          extract_from_dtable(result, element)
        end
      end
    end
    return result
  end

  def parse_features(page)
    result = []
    page.search('div.mod').each do |element|
      if element.search('h2').first && element.search('h2').first.inner_text == "Fasiliteter"
        result = element.search('p.mvn').map { |x| x.inner_text.strip.downcase.capitalize }
      end
    end
    return result
  end

  def get_description_html(page)
    element = page.search('#description .bd').first
    return "" unless element
    return element.inner_html.encode("utf-8").strip.gsub("\n", "<br/>")
  end

end
