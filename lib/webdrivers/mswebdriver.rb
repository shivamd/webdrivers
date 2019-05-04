# frozen_string_literal: true

require 'nokogiri'

module Webdrivers
  class MSWebdriver < Common
    class << self
      attr_accessor :ignore

      def current_version
        raise NotImplementedError, 'Unable to programatically determine the version of most MicrosoftWebDriver.exe'
      end

      def windows_version
        return @windows_version if @windows_version

        # current_version() from other webdrivers returns the version from the webdriver EXE.
        # Unfortunately, MicrosoftWebDriver.exe does not have an option to get the version.
        # To work around it we query the currently installed version of Microsoft Edge instead
        # and compare it to the list of available downloads.
        version = system_call('powershell (Get-AppxPackage -Name Microsoft.MicrosoftEdge).Version')
        raise VersionError, 'Failed to check Microsoft Edge version' if version.empty? # Package name changed?

        Webdrivers.logger.debug "Current version of Microsoft Edge is #{version}"

        @windows_version = Gem::Version.new(version)
      end

      def latest_version
        return @latest_version if @latest_version

        if windows_version.segments.first > 44
          raise VersionError, 'Webdrivers is unable to provide this driver; Run this command: '\
          '`DISM.exe /Online /Add-Capability /CapabilityName:Microsoft.WebDriver~~~~0.0.1.0` '\
          'as discussed here: https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/#downloads; '\
          'Also please set `Webdrivers::MSWebdriver.ignore = true`'
        end

        version = windows_version.segments[1]

        Webdrivers.logger.debug "Desired build of Microsoft WebDriver is #{version}"

        @latest_version = Gem::Version.new(version)
      end

      private

      def file_name
        'MicrosoftWebDriver.exe'
      end

      def base_url
        'https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/'
      end

      def download_url
        @download_url ||= downloads[Gem::Version.new windows_version.segments[1]]
      end

      def downloads
        array = Nokogiri::HTML(get(base_url)).xpath("//li[@class='driver-download']/a")
        array.each_with_object({}) do |link, hash|
          next if link.text == 'Insiders'

          key = normalize_version link.text.scan(/\d+/).first.to_i
          hash[key] = link['href']
        end
      end

      # Assume we have the latest if we are offline and file exists
      def correct_binary?
        get(base_url)
        false
      rescue ConnectionError
        File.exist?(binary)
      end
    end
  end
end
