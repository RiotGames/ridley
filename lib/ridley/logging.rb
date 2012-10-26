require 'logger'

module Ridley
  # @author Jamie Winsor <jamie@vialstudios.com>
  module Logging
    class << self
      # @return [Logger]
      def logger
        @logger ||= begin
          log = Logger.new(STDOUT)
          log.level = Logger::INFO
          log
        end
      end

      # @param [Logger, nil] obj
      #
      # @return [Logger]
      def set_logger(obj)
        @logger = (obj.nil? ? Logger.new('/dev/null') : obj)
      end
    end

    # @return [Logger]
    def logger
      Ridley::Logging.logger
    end
    alias_method :log, :logger
  end
end
