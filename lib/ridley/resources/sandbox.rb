module Ridley
  class Sandbox
    class << self
      # @param [Ridley::Connection] connection
      # @param [Array] checksums
      #
      # @return [Ridley::Sandbox]
      def create(connection, checksums = [])
        sumhash = { checksums: Hash.new }.tap do |chks|
          Array(checksums).each { |chk| chks[:checksums][chk] = nil }
        end

        attrs = connection.post("sandboxes", sumhash.to_json).body
        new(connection, attrs[:sandbox_id], attrs[:checksums])
      end

      # Checksum the file at the given filepath for a Chef API.
      #
      # @param [String] path
      #
      # @return [String]
      def checksum(path)
        File.open(path, 'rb') { |f| checksum_io(f, Digest::MD5.new) }
      end

      # Checksum and encode the file at the given filepath for uploading
      #
      # @param [String] path
      #
      # @return [String]
      #   a base64 encoded checksum
      def checksum64(path)
        Base64.encode64([checksum(path)].pack("H*")).strip
      end

      # @param [String] io
      # @param [Object] digest
      #
      # @return [String]
      def checksum_io(io, digest)
        while chunk = io.read(1024 * 8)
          digest.update(chunk)
        end
        digest.hexdigest
      end
    end

    attr_reader :sandbox_id
    attr_reader :checksums

    def initialize(connection, id, checksums)
      @connection = connection
      @sandbox_id = id
      @checksums = checksums
    end

    def checksum(chk_id)
      checksums.fetch(chk_id.to_sym)
    end

    # @param [String] chk_id
    # @param [String] path
    #
    # @return [Hash, nil]
    def upload(chk_id, path)
      checksum = self.checksum(chk_id)
      
      unless checksum[:needs_upload]
        return nil
      end

      headers  = {
        'Content-Type' => 'application/x-binary',
        'content-md5' => self.class.checksum64(path)
      }
      contents = File.open(path, 'rb') { |f| f.read }

      # Hosted Chef returns Amazon S3 URLs for where to upload
      # checksums to. OSS Chef Server and Hosted Chef return URLs
      # to the same Chef API that the Sandbox creation request was
      # sent to.
      #
      # The connection object is duplicated to ensure all of our connection
      # settings persist, but the scheme, host, and port are set to the
      # value of the given checksum.
      conn = connection.send(:conn).dup

      url = URI(checksum[:url])
      upload_path = url.path
      url.path = ""

      conn.url_prefix = url.to_s

      conn.put(upload_path, contents, headers)
    end

    def commit
      connection.put("sandboxes/#{sandbox_id}", { is_completed: true }.to_json).body
    end

    def to_s
      "#{sandbox_id}: #{checksums}"
    end

    private

      attr_reader :connection
  end

  module DSL
    # Coerces instance functions into class functions on Ridley::Sandbox. This coercion
    # sends an instance of the including class along to the class function.
    #
    # @see Ridley::ChainLink
    #
    # @return [Ridley::ChainLink]
    #   a context object to delegate instance functions to class functions on Ridley::Sandbox
    def sandbox
      ChainLink.new(self, Ridley::Sandbox)
    end
  end
end
