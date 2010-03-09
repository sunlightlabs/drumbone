require 'hpricot'

class UsaSpending
  BASE_URL = "http://www.usaspending.gov/fpds/fpds.php"
  
  def self.top_contractors_for_state(year, state)
    top_contractors_from url(year, :stateCode, state)
  end
  
  def self.top_contractors_for_district(year, state, district)
    district = 98 if ['GU', 'VI', 'AS', 'PR', 'DC'].include? state
    district = 90 if state == 'MP'
    top_contractors_from url(year, :pop_cd, "#{state}#{zero district}")
  end
  
  private
  
  def self.top_contractors_from(url)
    xml = fetch_url url
    return unless xml
    
    doc = Hpricot.XML xml
    
    top_contractors = doc.search("//top_contractor_parent_companies/contractor_parent_company").map do |company|
      {
        :rank => company['rank'],
        :amount => company['total_obligatedAmount'],
        :name => company.inner_text.toutf8.strip
      }
    end
    
    {
      :total_amount => doc.at("//data/record/totals/total_ObligatedAmount").inner_text.to_f,
      :total_contractors => doc.at("//data/record/totals/number_of_contractors").inner_text.to_i,
      :top_contractors => top_contractors
    }
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