require 'hpricot'

class UsaSpending
  BASE_URL = "http://www.usaspending.gov/fpds/fpds.php"
  
  def self.totals_for_state(year, state)
    totals_from url(year, :stateCode, state)
  end
  
  def self.totals_for_district(year, state, district)
    district = 98 if ['GU', 'VI', 'AS', 'PR', 'DC'].include? state
    district = 90 if state == 'MP'
    totals_from url(year, :pop_cd, "#{state}#{zero district}")
  end
  
  private
  
  def self.totals_from(url)
    xml = fetch_url url
    return unless xml
    
    doc = Hpricot::XML xml
    
    amount = doc.at("//data/record/totals/total_ObligatedAmount").inner_text.to_f
    contractors = doc.at("//data/record/totals/number_of_contractors").inner_text.to_i
    {:amount => amount, :contractors => contractors}
  end
  
  def self.url(year, key, location)
    "#{BASE_URL}?datype=X&detail=-1&fiscal_year=#{year}&#{key}=#{location}"
  end
  
  def self.fetch_url(url)
    response = Net::HTTP.get_response URI.parse(url)
    response.body
  end
  
  def self.zero(number)
    number.to_i < 10 ? "0#{number}" : "#{number}"
  end
  
end