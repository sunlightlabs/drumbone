require 'httparty'

class Brisket
  include HTTParty
  format :json
  base_uri "http://influenceexplorer.com:8000/api/1.0/"
  
  def self.api_key=(api_key); @@api_key = api_key; end
  def self.api_key; @@api_key; end
  
    
  def get_entity_id(crp_id)
    response = Brisket.get "/entities/id_lookup", :query => {
      :apikey => Brisket.api_key,
      :namespace => "urn:crp:recipient",
      :id => crp_id
    }
    case response.code
    when 200
      begin
        response and response.size > 0 ? response.first["id"] : nil
      rescue
        raise RuntimeError, "Error parsing response: #{response.body}"
      end
    else
      raise RuntimeError, "Bad response code: #{response.body}"
    end
  end
  
  def top_contributors(crp_id, cycle, top = 10)
    entity_id = get_entity_id crp_id
    return nil unless entity_id
    
    response = Brisket.get "/aggregates/pol/#{entity_id}/contributors.json", :query => {
      :apikey => Brisket.api_key,
      :cycle => cycle,
      :top => top
    }
    case response.code
    when 200
      response
    else
      raise RuntimeError, "Bad response code: #{response.body}"
    end
  end
  
end