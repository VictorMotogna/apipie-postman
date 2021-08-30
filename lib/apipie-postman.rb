# frozen_string_literal: true

require 'json'
require 'faraday'

module ApipiePostman
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Configuration class for gem
  class Configuration
    attr_accessor :postman_api_key,
                  :postman_collection_name,
                  :base_url

    def initialize
      @postman_api_key = ''
      @postman_collection_name = ''
      @base_url = ''
    end
  end

  def self.generate_docs
    file = File.read('doc/apipie_examples.json')
    @docs = JSON.parse(file)
    docs_hashes = []
    endpoints_hashes = []

    @docs.each_key do |key|
      docs_hashes << @docs[key]
    end

    docs_hashes.each do |doc_hash|
      doc_hash.each do |endpoint|
        req_body = if endpoint['request_data'].nil?
                     {}
                   else
                     endpoint['request_data']
                   end

        endpoints_hashes << {
          name: endpoint['title'] == 'Default' ? "#{endpoint['verb']} #{endpoint['path']}" : endpoint['title'],
          request: {
            url: "#{self.configuration.base_url}#{endpoint['path']}",
            method: endpoint['verb'],
            header: [],
            body: {
              mode: 'raw',
              raw: req_body.to_json
            },
            description: endpoint['title']
          },
          response: []
        }
      end
    end

    body = {
      collection: {
        info: {
          name: self.configuration.postman_collection_name,
          description: 'Test description',
          schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
        },
        item: endpoints_hashes
      }
    }.to_json

    headers = {
      'X-Api-Key': self.configuration.postman_api_key,
      'Content-Type': 'application/json'
    }

    collection_uid = check_collection_uid_by_name(headers)

    if collection_uid.nil?
      Faraday.public_send(:post, 'https://api.getpostman.com/collections/', body, headers)
    else
      Faraday.public_send(:put, "https://api.getpostman.com/collections/#{collection_uid['uid']}", body, headers)
    end
  end

  def self.check_collection_uid_by_name(headers)
    response = Faraday.public_send(:get, 'https://api.getpostman.com/collections/', {}, headers)
    JSON.parse(response.body)['collections'].select do |col|
      col['name'] == self.configuration.postman_collection_name
    end.last
  end
end
