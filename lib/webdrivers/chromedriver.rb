# frozen_string_literal: true

require 'shellwords'
require 'webdrivers/common'
require 'webdrivers/chrome_finder'

module Webdrivers
  class Chromedriver < Common
    class << self
      def current_version
        Webdrivers.logger.debug 'Checking current version'
        return nil unless exists?

        version = binary_version
        return nil if version.nil?

        # Matches 2.46, 2.46.628411 and 73.0.3683.75
        normalize_version version[/\d+\.\d+(\.\d+)?(\.\d+)?/]
      end

      def latest_version
        @latest_version ||= begin
          # Versions before 70 do not have a LATEST_RELEASE file
          return normalize_version('2.41') if release_version < normalize_version('70')

          latest_applicable = with_cache(file_name) { latest_point_release(release_version) }

          Webdrivers.logger.debug "Latest version available: #{latest_applicable}"
          normalize_version(latest_applicable)
        end
      end

      # Returns currently installed Chrome version
      def chrome_version
        normalize_version ChromeFinder.version
      end

      private

      def latest_point_release(version)
        release_file = "LATEST_RELEASE_#{version}"
        begin
          normalize_version(Network.get(URI.join(base_url, release_file)))
        rescue StandardError
          latest_release = normalize_version(Network.get(URI.join(base_url, 'LATEST_RELEASE')))
          Webdrivers.logger.debug "Unable to find a driver for: #{version}"

          msg = version > latest_release ? 'you appear to be using a non-production version of Chrome; ' : ''
          msg = "#{msg}please set `Webdrivers::Chromedriver.required_version = <desired driver version>` to an known "\
'chromedriver version: https://chromedriver.storage.googleapis.com/index.html'
          raise VersionError, msg
        end
      end

      def file_name
        System.platform == 'win' ? 'chromedriver.exe' : 'chromedriver'
      end

      def base_url
        'https://chromedriver.storage.googleapis.com'
      end

      def download_url
        return @download_url if @download_url

        version = if required_version.version.empty?
                    latest_version
                  else
                    normalize_version(required_version)
                  end

        file_name = System.platform == 'win' ? 'win32' : "#{System.platform}64"
        url = "#{base_url}/#{version}/chromedriver_#{file_name}.zip"
        Webdrivers.logger.debug "chromedriver URL: #{url}"
        @download_url = url
      end

      # Returns release version from the currently installed Chrome version
      #
      # @example
      #   73.0.3683.75 -> 73.0.3683
      def release_version
        chrome = normalize_version(chrome_version)
        normalize_version(chrome.segments[0..2].join('.'))
      end

      def sufficient_binary?
        super && current_version && (current_version < normalize_version('70.0.3538') ||
            current_version.segments.first == release_version.segments.first)
      end
    end
  end
end

if ::Selenium::WebDriver::Service.respond_to? :driver_path=
  ::Selenium::WebDriver::Chrome::Service.driver_path = proc { ::Webdrivers::Chromedriver.update }
else
  # v3.141.0 and lower
  module Selenium
    module WebDriver
      module Chrome
        def self.driver_path
          @driver_path ||= Webdrivers::Chromedriver.update
        end
      end
    end
  end
end
