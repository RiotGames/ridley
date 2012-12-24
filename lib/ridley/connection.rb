module Ridley
  # @author Jamie Winsor <jamie@vialstudios.com>
  class Connection
    class << self
      def sync(options, &block)
        conn = new(options)
        conn.sync(&block)
      ensure
        conn.terminate if conn && conn.alive?
      end
      
      # @raise [ArgumentError]
      #
      # @return [Boolean]
      def validate_options(options)
        missing = (REQUIRED_OPTIONS - options.keys)

        unless missing.empty?
          missing.collect! { |opt| "'#{opt}'" }
          raise ArgumentError, "Missing required option(s): #{missing.join(', ')}"
        end

        missing_values = options.slice(*REQUIRED_OPTIONS).select { |key, value| !value.present? }
        unless missing_values.empty?
          values = missing_values.keys.collect { |opt| "'#{opt}'" }
          raise ArgumentError, "Missing value for required option(s): '#{values.join(', ')}'"
        end
      end

      # A hash of default options to be used in the Connection initializer
      #
      # @return [Hash]
      def default_options
        {
          thread_count: DEFAULT_THREAD_COUNT,
          ssh: Hash.new
        }
      end
    end

    extend Forwardable

    include Celluloid
    include Ridley::DSL
    include Ridley::Logging

    attr_reader :organization

    attr_accessor :client_name
    attr_accessor :client_key
    attr_accessor :validator_client
    attr_accessor :validator_path
    attr_accessor :encrypted_data_bag_secret_path

    attr_accessor :ssh
    attr_accessor :thread_count

    def_delegator :conn, :build_url
    def_delegator :conn, :scheme
    def_delegator :conn, :host
    def_delegator :conn, :port
    def_delegator :conn, :path_prefix

    def_delegator :conn, :url_prefix=
    def_delegator :conn, :url_prefix

    def_delegator :conn, :get
    def_delegator :conn, :put
    def_delegator :conn, :post
    def_delegator :conn, :delete
    def_delegator :conn, :head

    def_delegator :conn, :in_parallel

    OPTIONS = [
      :server_url,
      :client_name,
      :client_key,
      :organization,
      :validator_client,
      :validator_path,
      :encrypted_data_bag_secret_path,
      :thread_count,
      :ssl
    ].freeze

    REQUIRED_OPTIONS = [
      :server_url,
      :client_name,
      :client_key
    ].freeze

    DEFAULT_THREAD_COUNT = 8

    # @option options [String] :server_url
    #   URL to the Chef API
    # @option options [String] :client_name
    #   name of the client used to authenticate with the Chef API
    # @option options [String] :client_key
    #   filepath to the client's private key used to authenticate with the Chef API
    # @option options [String] :organization
    #   the Organization to connect to. This is only used if you are connecting to
    #   private Chef or hosted Chef
    # @option options [String] :validator_client (nil)
    # @option options [String] :validator_path (nil)
    # @option options [String] :encrypted_data_bag_secret_path (nil)
    # @option options [Integer] :thread_count (DEFAULT_THREAD_COUNT)
    # @option options [Hash] :ssh (Hash.new)
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on (required)
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of keys (or a single key) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) [5.0] timeout value for SSH bootstrap
    #   * :sudo (Boolean) [true] bootstrap with sudo
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
    def initialize(options = {})
      log.info { "Ridley starting..." }
      configure(options)
    end

    # Configure this instance of Ridley::Connection
    #
    # @param [Hash] options
    def configure(options)
      options = self.class.default_options.merge(options)
      self.class.validate_options(options)

      @client_name      = options[:client_name]
      @client_key       = File.expand_path(options[:client_key])
      @organization     = options[:organization]
      @thread_count     = options[:thread_count]
      @ssh              = options[:ssh]
      @validator_client = options[:validator_client]
      @validator_path   = options[:validator_path]
      @encrypted_data_bag_secret_path = options[:encrypted_data_bag_secret_path]

      unless @client_key.present? && File.exist?(@client_key)
        raise Errors::ClientKeyFileNotFound, "client key not found at: '#{@client_key}'"
      end

      faraday_options = options.slice(:params, :headers, :request, :ssl, :proxy)
      uri_hash = Addressable::URI.parse(options[:server_url]).to_hash.slice(:scheme, :host, :port)

      unless uri_hash[:port]
        uri_hash[:port] = (uri_hash[:scheme] == "https" ? 443 : 80)
      end

      if org_match = options[:server_url].match(/.*\/organizations\/(.*)/)
        @organization ||= org_match[1]
      end

      unless organization.nil?
        uri_hash[:path] = "/organizations/#{organization}"
      end

      server_uri = Addressable::URI.new(uri_hash)

      @conn = Faraday.new(server_uri, faraday_options) do |c|
        c.request :chef_auth, client_name, client_key
        c.response :chef_response
        c.response :json

        c.adapter :net_http_persistent
      end
    end

    def sync(&block)
      unless block
        raise Errors::InternalError, "A block must be given to synchronously process requests."
      end

      evaluate(&block)
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

    # The encrypted data bag secret for this connection.
    #
    # @raise [Ridley::Errors::EncryptedDataBagSecretNotFound]
    #
    # @return [String, nil]
    def encrypted_data_bag_secret
      return nil if encrypted_data_bag_secret_path.nil?

      IO.read(encrypted_data_bag_secret_path).chomp
    rescue Errno::ENOENT => e
      raise Errors::EncryptedDataBagSecretNotFound, "Encrypted data bag secret provided but not found at '#{encrypted_data_bag_secret_path}'"
    end

    def finalize
      log.info { "Ridley stopping..." }
    end

    private

      attr_reader :conn

      def evaluate(&block)
        @self_before_instance_eval = eval("self", block.binding)
        instance_eval(&block)
      end

      def method_missing(method, *args, &block)
        if block_given?
          @self_before_instance_eval ||= eval("self", block.binding)
        end

        if @self_before_instance_eval.nil?
          super
        end

        @self_before_instance_eval.send(method, *args, &block)
      end
  end
end
