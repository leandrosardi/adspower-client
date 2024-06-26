require 'uri'
require 'net/http'
require 'json'
require 'blackstack-core'
require 'selenium-webdriver'
require 'watir'

class AdsPowerClient    
    # reference: https://localapi-doc-en.adspower.com/
    # reference: https://localapi-doc-en.adspower.com/docs/Rdw7Iu
    attr_accessor :key, :port, :server_log, :adspower_listener, :adspower_default_browser_version
    
    # control over the drivers created, in order to don't create the same driver twice and don't generate memory leaks.
    # reference: https://github.com/leandrosardi/adspower-client/issues/4
    @@drivers = {}

    def initialize(h={})
        self.key = h[:key] # mandatory
        self.port = h[:port] || '50325'
        self.server_log = h[:server_log] || '~/adspower-client.log'
        self.adspower_listener = h[:adspower_listener] || 'http://127.0.0.1'
        self.adspower_default_browser_version = h[:adspower_default_browser_version] || '116'
#        self.profiles_created = []
    end

    # return an array of PIDs of all the adspower_global processes running in the local computer.
    def server_pids
        `ps aux | grep "adspower_global" | grep -v grep | awk '{print $2}'`.split("\n")
    end

    # return true if there is any adspower_global process running in the local computer.

    # run async command to start adspower server in headless mode.
    # wait up to 10 seconds to start the server, or raise an exception.
    def server_start(timeout=30)
        `xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' /usr/bin/adspower_global --headless=true --api-key=#{self.key.to_s} --api-port=#{self.port.to_s} > #{self.server_log} 2>&1 &`
        # wait up to 10 seconds to start the server
        timeout.times do
            break if self.online?
            sleep(1)
        end
        # add a delay of 5 more seconds
        sleep(5)
        # raise an exception if the server is not running
        raise "Error: the server is not running" if self.online? == false
        return
    end

    # kill all the adspower_global processes running in the local computer.
    def server_stop
        self.server_pids.each { |pid|
            `kill -9 #{pid}`
        }
        return
    end
    
    # send an GET request to "#{url}/status".
    # Return true if it responded successfully.
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/6DSiws
    # 
    def online?
        begin
            url = "#{self.adspower_listener}:#{port}/status"
            uri = URI.parse(url)
            res = Net::HTTP.get(uri)
            # show respose body
            return JSON.parse(res)['msg'] == 'success'
        rescue => e
            return false
        end
    end

    # send a post request to "#{url}/api/v1/user/create"
    # and return the response body.
    #
    # return id of the created user
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/6DSiws
    # reference: https://localapi-doc-en.adspower.com/docs/Lb8pOg
    # reference: https://localapi-doc-en.adspower.com/docs/Awy6Dg
    # 
    def create
        url = "#{self.adspower_listener}:#{port}/api/v1/user/create"
        body = {
            #'api_key' => self.key,
            'group_id' => '0',
            'proxyid' => '1',
            'fingerprint_config' => {
                'browser_kernel_config' => {"version": self.adspower_default_browser_version, "type":"chrome"}
            }
        }
        # api call
        res = BlackStack::Netting.call_post(url, body)
        # show respose body
        ret = JSON.parse(res.body)
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
        # add to array of profiles created
#        self.profiles_created << ret
        # return id of the created user
        ret['data']['id']
    end

    def delete(id)
        url = "#{self.adspower_listener}:#{port}/api/v1/user/delete"
        body = {
            'api_key' => self.key,
            'user_ids' => [id],
        }
        # api call
        res = BlackStack::Netting.call_post(url, body)
        # show respose body
        ret = JSON.parse(res.body)
        # validation
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
    end

    # run the browser
    # return the URL to operate the browser thru selenium
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/FFMFMf
    # 
    def start(id, headless=false)
        url = "#{self.adspower_listener}:#{port}/api/v1/browser/start?user_id=#{id}&headless=#{headless ? '1' : '0'}"
        uri = URI.parse(url)
        res = Net::HTTP.get(uri)
        # show respose bo
        ret = JSON.parse(res)
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
        # return id of the created user
        ret
    end

    # run the browser
    # return the URL to operate the browser thru selenium
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/DXam94
    # 
    def stop(id)
        # if the profile is running with driver, kill chromedriver
        if @@drivers[id] && self.check(id)
            @@drivers[id].quit
            @@drivers[id] = nil
        end

        uri = URI.parse("#{self.adspower_listener}:#{port}/api/v1/browser/stop?user_id=#{id}")
        res = Net::HTTP.get(uri)
        # show respose body
        ret = JSON.parse(res)
        raise "Error: #{ret.to_s}" if ret['msg'].to_s.downcase != 'success'
        # return id of the created user
        ret
    end

    # send an GET request to "#{url}/status"
    # and return if I get the json response['data']['status'] == 'Active'.
    # Otherwise, return false.
    # 
    # reference: https://localapi-doc-en.adspower.com/docs/YjFggL
    # 
    def check(id)
        url = "#{self.adspower_listener}:#{port}/api/v1/browser/active?user_id=#{id}"
        uri = URI.parse(url)
        res = Net::HTTP.get(uri)
        # show respose body
        return false if JSON.parse(res)['msg'] != 'success'
        # return
        JSON.parse(res)['data']['status'] == 'Active'
    end

    #
    def driver(id, headless=false)
        ret = self.start(id, headless)
        old = @@drivers[id]

        # si este driver sigue activo, lo devuelvo
        return old if old && self.check(id)
        
        # Attach test execution to the existing browser
        # reference: https://zhiminzhan.medium.com/my-innovative-solution-to-test-automation-attach-test-execution-to-the-existing-browser-b90cda3b7d4a
        url = ret['data']['ws']['selenium']
        opts = Selenium::WebDriver::Chrome::Options.new
        opts.add_option("debuggerAddress", url)

        # connect to the existing browser
        # reference: https://localapi-doc-en.adspower.com/docs/K4IsTq
        driver = Selenium::WebDriver.for(:chrome, :options=>opts)

        # save the driver
        @@drivers[id] = driver

        # return
        driver
    end # def driver

    # create a new profile
    # start the browser
    # visit the page
    # grab the html
    # quit the browser from webdriver
    # stop the broser from adspower
    # delete the profile
    # return the html
    def html(url)
        ret = {
            :profile_id => nil,
            :html => nil,
            :status => 'success',
        }
        id = nil
        html = nil
        begin
            # create the profile
            sleep(1) # Avoid the "Too many request per second" error
            id = self.create

            # update the result
            ret[:profile_id] = id

            # start the profile and attach the driver
            driver = self.driver(id)

            # get html
            driver.get(url)
            html = driver.page_source

            # update the result
            ret[:html] = html

            # stop the profile
            sleep(1) # Avoid the "Too many request per second" error
            driver.quit
            self.stop(id)

            # delete the profile
            sleep(1) # Avoid the "Too many request per second" error
            self.delete(id)

            # reset id
            id = nil
        rescue => e
            # stop and delete current profile
            if id
                sleep(1) # Avoid the "Too many request per second" error
                self.stop(id)
                sleep(1) # Avoid the "Too many request per second" error
                driver.quit
                self.delete(id) if id
            end # if id
            # inform the exception
            ret[:status] = e.to_s
#        # process interruption
#        rescue SignalException, SystemExit, Interrupt => e 
#            if id
#                sleep(1) # Avoid the "Too many request per second" error
#                self.stop(id)
#                sleep(1) # Avoid the "Too many request per second" error
#                driver.quit
#                self.delete(id) if id
#            end # if id
        end
        # return
        ret
    end # def html
end # class AdsPowerClient
