module Ridley
  # @author Jamie Winsor <jamie@vialstudios.com>
  class Connection < Faraday::Connection
    include Celluloid

    VALID_OPTIONS = [
      :params,
      :headers,
      :request,
      :ssl,
      :proxy
    ]

    attr_reader :organization
    attr_reader :client_key
    attr_reader :client_name

    # @param [String] :server_url
    # @param [String] :client_name
    # @param [String] :client_key
    #
    # @option options [Hash] :params
    #   URI query unencoded key/value pairs
    # @option options [Hash] :headers
    #   unencoded HTTP header key/value pairs
    # @option options [Hash] :request
    #   request options
    # @option options [Hash] :ssl
    #   * :verify (Boolean) [true] set to false to disable SSL verification
    # @option options [URI, String, Hash] :proxy
    #   URI, String, or Hash of HTTP proxy options
    def initialize(server_url, client_name, client_key, options = {})
      @client_name  = client_name
      @client_key   = client_key

      options = options.reverse_merge(
        builder: Faraday::Builder.new { |b|
          b.request :chef_auth, client_name, client_key
          b.response :chef_response
          b.response :json

          b.adapter :net_http_persistent
        }
      )

      uri_hash = Addressable::URI.parse(server_url).to_hash.slice(:scheme, :host, :port)

      unless uri_hash[:port]
        uri_hash[:port] = (uri_hash[:scheme] == "https" ? 443 : 80)
      end

      if org_match = server_url.match(/.*\/organizations\/(.*)/)
        @organization = org_match[1]
      end

      unless @organization.nil?
        uri_hash[:path] = "/organizations/#{@organization}"
      end

      server_uri = Addressable::URI.new(uri_hash)

      super(server_uri, options)
    end

    # @return [Symbol]
    def api_type
      organization.nil? ? :foss : :hosted
    end

    # @return [Boolean]
    def hosted?
      api_type == :hosted
    end

    # @return [Boolean]
    def foss?
      api_type == :foss
    end

    def server_url
      self.url_prefix.to_s
    end
  end
end
