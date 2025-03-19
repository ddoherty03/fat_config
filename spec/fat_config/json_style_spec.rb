# frozen_string_literal: true

require 'spec_helper'

module FatConfig
  RSpec.describe FatConfig do
    context "with JSON Config Files" do
      # Put contents in path relative to SANDBOX
      def setup_test_file(path, content)
        path = File.expand_path(path)
        test_path = File.join(sandbox_dir, path)
        dir_part = File.dirname(test_path)
        FileUtils.mkdir_p(dir_part) unless Dir.exist?(dir_part)
        File.write(test_path, content)
      end

      before do
        # Save these, since they're not specific to this app.
        @xdg_config_dirs = ENV['XDG_CONFIG_DIRS']
        @xdg_config_home = ENV['XDG_CONFIG_HOME']
      end

      after do
        # Restore
        ENV['XDG_CONFIG_DIRS'] = @xdg_config_dirs
        ENV['XDG_CONFIG_HOME'] = @xdg_config_home
        # Remove anything set in examples
        ENV['LABRAT_SYS_CONFIG'] = nil
        ENV['LABRAT_CONFIG'] = nil
        FileUtils.rm_rf(sandbox_dir)
      end

      describe 'Basic JSON reading' do
        let(:reader) { Reader.new('labrat') }
        let(:json_str) do
          <<~JSON
            {
                "doe": "a deer, a female deer",
                "ray": "a drop of golden sun",
                "pi": 3.14159,
                "xmas": true,
                "french-hens": 3,
                "calling-birds": ["huey", "dewey", "louie", "fred"],
                "xmas-fifth-day": "2024-12-24",
                "golden-rings": 5,
                "partridges": {
                    "count": 1,
                    "location": "a pear tree"
                },
                "turtle-doves": "two"
            }
          JSON
        end
        let(:bad_json_str) do
          # NOTE: end-quote missing in "xmas-fifth-day" value.
          <<~JSON
            {
                "doe": "a deer, a female deer",
                "ray": "a drop of golden sun",
                "pi": 3.14159,
                "xmas": true,
                "french-hens": 3,
                "calling-birds": ["huey", "dewey", "louie", "fred"],
                "xmas-fifth-day": "2024-12-24,
                "golden-rings": 5,
                "partridges": {
                    "count": 1,
                    "location": "a pear tree"
                },
                "turtle-doves": "two"
            }
          JSON
        end

        it 'can read a JSON string' do
          hsh = JSONStyle.new.load_string(json_str)
          expect(hsh.keys).to include(:doe)
          expect(hsh.keys).to include(:french_hens)
          expect(hsh[:calling_birds]).to be_an Array
          expect(hsh[:xmas_fifth_day]).to be_a String
        end

        it 'raises FatConfig::ParseError on a bad string' do
          expect { JSONStyle.new.load_string(bad_json_str) }.to raise_error FatConfig::ParseError
        end

        it 'raises FatConfig::ParseError on a bad file' do
          setup_test_file('/etc/xdg/labrat/config.json', bad_json_str)
          expect {
            Reader.new('labrat', style: :json, root_prefix: sandbox_dir)
              .read(verbose: true)
          }.to raise_error FatConfig::ParseError
        end
      end

      describe 'Reading XDG config files' do
        let(:reader) { Reader.new('labrat', style: :json, root_prefix: sandbox_dir) }

        it 'reads an xdg system config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file('/etc/xdg/labrat/config.json', config_json)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_DIRS xdg system directory config file' do
          # Higher priority XDG
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%"
            }
          JSON
          setup_test_file('/lib/junk/labrat/config.json', config_json)

          # Lower priority XDG
          config2_json = <<~JSON
            {
              "page-width": "3cm",
              "page-height": "10cm",
              "delta-x": "-4pt",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "dymo4",
              "rows": 10,
              "columns": 3
            }
          JSON
          setup_test_file('/lib/lowjunk/labrat/config.json', config2_json)

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_DIRS'] = "/lib/junk:#{ENV['XDG_CONFIG_DIRS']}:/lib/lowjunk"
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          # Since these were not specified in the high-priority config, but were in
          # the low-priority config, they get set.
          expect(hsh[:printer]).to eq('dymo4')
          expect(hsh[:rows]).to eq(10)
          expect(hsh[:columns]).to eq(3)
        end

        it 'reads an xdg system ENV-specified config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat.yml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_json)
          hsh = reader.read
          # op = ArgParser.new.parse(hsh)
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an xdg user config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.json", config_json)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an empty xdg system config file and reports empty' do
          config_cfg = '{}'
          setup_test_file("/etc/xdg/labrat/config.json", config_cfg)
          hsh = nil
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(/System config files found/i)
          expect(result[:stderr]).to match(/Merging system config from file/i)
          expect(result[:stderr]).to match(/Empty config/i)
          expect(hsh).to be_empty
        end

        it 'reads an xdg ENV-specified user config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          ENV['LABRAT_CONFIG'] = "/home/#{ENV['USER']}/.labrc"
          setup_test_file(ENV['LABRAT_CONFIG'], config_json)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'merges an xdg user config into an xdg system config file' do
          sys_config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file('/etc/xdg/labrat/config.json', sys_config_json)
          usr_config_json = <<~JSON
            {
              "page-height": "102mm",
              "delta-x": "-3mm"
            }
          JSON
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.json", usr_config_json)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'verbosely merges an xdg user config into an xdg system config file' do
          sys_config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file('/etc/xdg/labrat/config.json', sys_config_json)
          usr_config_json = <<~JSON
            {
              "page-height": "102mm",
              "delta-x": "-3mm"
            }
          JSON
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.json", usr_config_json)

          # With verbose on, stderr should be:
          #
          # System config files found: /home/ded/src/fat_config[...]/sandbox/etc/xdg/labrat/config.json
          # User config files found: /home/ded/src/fat_config[...]/sandbox/etc/xdg/labrat/config.json
          # Merging system config from file '/home/ded/src/fat_config[...]/sandbox/etc/xdg/labrat/config.json':
          #   Added: delta_x: -4mm
          #   Added: delta_y: 1cm
          #   Added: nl_sep: %%
          #   Added: page_height: 101mm
          #   Added: page_width: 33mm
          #   Added: printer: seiko3
          # Merging user config from file '/home/ded/src/fat_config[...]/sandbox/home/ded/.config/labrat/config.json':
          #   Changed: delta_x: -4mm -> -3mm
          #   Unchanged: delta_y: 1cm
          #   Unchanged: nl_sep: %%
          #   Changed: page_height: 101mm -> 102mm
          #   Unchanged: page_width: 33mm
          #   Unchanged: printer: seiko3
          hsh = {}
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(/system config files found/i)
          expect(result[:stderr]).to match(/user config files found/i)
          expect(result[:stderr]).to match(%r{merging system.*/etc/xdg/labrat/config.json}i)
          expect(result[:stderr]).to match(%r{merging user.*/\.config/labrat/config.json}i)
          expect(result[:stderr]).to match(/Merging system config/)
          expect(result[:stderr]).to match(/Merging user config/)
          expect(result[:stderr]).to match(/Added: *delta_x/)
          expect(result[:stderr]).to match(/Added: *delta_y/)
          expect(result[:stderr]).to match(/Changed: *delta_x/)
          expect(result[:stderr]).to match(/Unchanged: *delta_y/)
          expect(result[:stderr]).to match(/Changed: *page_height/)

          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_HOME xdg user directory config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%"
            }
          JSON
          setup_test_file('~/.foncig/labrat/config.json', config_json)

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to be_nil
        end

        it 'reads an empty XDG_CONFIG_HOME xdg user directory config file' do
          setup_test_file('~/.foncig/labrat/config.json', '{}')

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end
      end

      describe 'Reading classic config files' do
        let(:reader) { Reader.new('labrat', xdg: false, style: 'json', root_prefix: sandbox_dir) }

        it 'read an empty classic system config file' do
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/configjson'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], '{}')
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end

        it 'reads a classic system config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/configjson'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_json)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file("/home/#{ENV['USER']}/.labrat.json", config_json)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file in ENV[\'LABRAT_CONFIG\']' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          ENV['LABRAT_CONFIG'] = '~/junk/random/lr.y'
          setup_test_file(ENV['LABRAT_CONFIG'], config_json)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it "reads a classic user rc-style config file in HOME" do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file('~/.labratrc', config_json)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic ~/.labrat config dir in HOME' do
          config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          setup_test_file('~/.labrat/config', config_json)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic system and user config files' do
          sys_config_json = <<~JSON
            {
              "page-width": "33mm",
              "page-height": "101mm",
              "delta-x": "-4mm",
              "delta-y": "1cm",
              "nl-sep": "%%",
              "printer": "seiko3"
            }
          JSON
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.json'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], sys_config_json)
          usr_config_json = <<~JSON
            {
              "page-height": "102mm",
              "delta-x": "-7mm",
              "delta-y": "+30mm",
              "nl-sep": "~~"
            }
          JSON
          setup_test_file('~/.labrat/config.json', usr_config_json)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-7mm')
          expect(hsh[:delta_y]).to eq('+30mm')
          expect(hsh[:nl_sep]).to eq('~~')
          expect(hsh[:printer]).to eq('seiko3')
        end
      end
    end
  end
end
