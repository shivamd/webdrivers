# frozen_string_literal: true

module Webdrivers
  class ChromeFinder
    class << self
      def version
        location = Selenium::WebDriver::Chrome.path || send("#{System.platform}_location")
        version = send("#{System.platform}_version", location)

        raise VersionError, 'Failed to find Chrome binary or its version.' if version.nil? || version.empty?

        Webdrivers.logger.debug "Browser version: #{version}"
        version[/\d+\.\d+\.\d+\.\d+/] # Google Chrome 73.0.3683.75 -> 73.0.3683.75
      end

      def win_location
        return Selenium::WebDriver::Chrome.path unless Selenium::WebDriver::Chrome.path.nil?

        envs = %w[LOCALAPPDATA PROGRAMFILES PROGRAMFILES(X86)]
        directories = ['\\Google\\Chrome\\Application', '\\Chromium\\Application']
        file = 'chrome.exe'

        directories.each do |dir|
          envs.each do |root|
            option = "#{ENV[root]}\\#{dir}\\#{file}"
            return option if File.exist?(option)
          end
        end
      end

      def mac_location
        locations = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
                     '/Applications/Chromium.app/Contents/MacOS/Chromium']

        locations.each { |loc| return loc if File.exist?(loc) }
      end

      def linux_location
        directories = %w[/usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /opt/google/chrome]
        files = %w[google-chrome chrome chromium chromium-browser]

        directories.each do |dir|
          files.each do |file|
            option = "#{dir}/#{file}"
            return option if File.exist?(option)
          end
        end
      end

      def win_version(location)
        System.call "powershell (Get-ItemProperty '#{location}').VersionInfo.ProductVersion"
      end

      def linux_version(location)
        System.call("#{Shellwords.escape location} --product-version").strip
      end

      def mac_version(location)
        System.call("#{Shellwords.escape location} --version").strip
      end
    end
  end
end
