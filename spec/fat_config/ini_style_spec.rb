# frozen_string_literal: true

require 'spec_helper'

module FatConfig
  RSpec.describe FatConfig do
    context "with INI Config Files" do
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

      describe 'Basic INI reading' do
        let(:reader) { Reader.new('labrat', config_lang: ini) }
        let(:ini_str) do
          <<~INI
            doe = "a deer, a female deer"
            ray = "a drop of golden sun"
            pi = 3.14159

            [section1]
            xmas = true
            french-hens = 3
            calling-birds = [ "huey", "dewey", "louie", "fred" ]
            ducks = { "huey", "dewey", "louie", "fred" }
            xmas-fifth-day = ""
            golden-rings = 0o11
            turtle-doves = "two"
            the-day = 2024-12-24

            [partridges]
            count = 1
            location = "a pear tree"
          INI
        end
        let(:bad_ini_str) do
          <<~INI
            doe = "a deer, a female deer"
            ray = "a drop of golden sun"
            pi = 3.14159

            [section1]
            xmas = true
            french-hens = 3
            # Here is error on line 9
            calling-birds - "huey", "dewey", "louie", "fred
            xmas-fifth-day = ""
            golden-rings = 5
            turtle-doves = "two"
            the-day = 2024-12-24

            [partridges]
            count = 1
            location = "a pear tree"
          INI
        end

        it 'can read a INI string' do
          hsh = INIStyle.new.load_string(ini_str)
          expect(hsh.keys).to include(:global)
          expect(hsh.keys).to include(:section1)
          expect(hsh[:global][:pi]).to be_a Float
          expect(hsh[:section1][:the_day]).to be_a String
        end

        it 'raises FatConfig::ParseError on a bad string' do
          expect { INIStyle.new.load_string(bad_ini_str) }.to raise_error(/could not parse.*calling/i)
        end

        it 'raises FatConfig::ParseError on a bad file' do
          setup_test_file('/etc/xdg/labrat/config.ini', bad_ini_str)
          expect {
            Reader.new('labrat', config_style: :ini, root_prefix: sandbox_dir)
              .read(verbose: true)
          }.to raise_error(/could not parse.*calling/i)
        end
      end

      describe 'Reading XDG config files' do
        let(:reader) { Reader.new('labrat', config_style: :ini, root_prefix: sandbox_dir) }

        it 'reads an xdg system config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file('/etc/xdg/labrat/config.ini', config_ini)

          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq('%%')
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_DIRS xdg system directory config file' do
          # Higher priority XDG
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
          INI
          setup_test_file('/lib/junk/labrat/config.ini', config_ini)

          # Lower priority XDG
          config2_ini = <<~INI
            page-width = "3cm"
            page-height = "10cm"
            delta-x =  "-4pt"
            delta-y = "1cm"
            printer = "dymo4"
            rows = 10
            columns = 3
          INI
          setup_test_file('/lib/lowjunk/labrat/config.ini', config2_ini)

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_DIRS'] = "/lib/junk:#{ENV['XDG_CONFIG_DIRS']}:/lib/lowjunk"
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          # Since these were not specified in the high-priority config, but were in
          # the low-priority config, they get set.
          expect(hsh[:global][:printer]).to eq('dymo4')
          expect(hsh[:global][:rows]).to eq(10)
          expect(hsh[:global][:columns]).to eq(3)
        end

        it 'reads an xdg system ENV-specified config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat.ini'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_ini)
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads an xdg user config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.ini", config_ini)
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads an empty xdg system config file and reports empty' do
          config_ini = <<~YAML
            # page-width: 33mm
            # page-height: 101mm
            # delta-x: -4mm
            # delta-y: 1cm
            # nl-sep: '%%'
            # printer: seiko3
          YAML
          setup_test_file("/etc/xdg/labrat/config.ini", config_ini)
          hsh = nil
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(/System config files found/i)
          expect(result[:stderr]).to match(/Merging system config from file/i)
          expect(result[:stderr]).to match(/Empty config/i)
          expect(hsh).to be_empty
        end

        it 'reads an xdg ENV-specified user config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          ENV['LABRAT_CONFIG'] = "/home/#{ENV['USER']}/.labrc"
          setup_test_file(ENV['LABRAT_CONFIG'], config_ini)

          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'merges an xdg user config into an xdg system config file' do
          sys_config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file('/etc/xdg/labrat/config.ini', sys_config_ini)
          usr_config_ini = <<~INI
            page-height = "102mm"
            delta-x = "-3mm"
          INI
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.ini", usr_config_ini)

          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('102mm')
          expect(hsh[:global][:delta_x]).to eq('-3mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'verbosely merges an xdg user config into an xdg system config file' do
          sys_config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file('/etc/xdg/labrat/config.ini', sys_config_ini)
          usr_config_ini = <<~INI
            page-height = "102mm"
            delta-x = "-3mm"
          INI
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.ini", usr_config_ini)
          # With verbose true, stderr should be the following:
          #
          # System config files found: /home/ded/src/[...]/sandbox/etc/xdg/labrat/config.yml
          # User config files found: /home/ded/src/[...]/sandbox/etc/xdg/labrat/config.yml
          # Merging system config from file '/home/ded/src/[...]/sandbox/etc/xdg/labrat/config.yml':
          #   Added: delta_x: -4mm
          #   Added: delta_x: -4mm
          #   Added: delta_y: 1cm
          #   Added: nl_sep: %%
          #   Added: page_height: 101mm
          #   Added: page_width: 33mm
          #   Added: printer: seiko3
          # Merging user config from file '/home/ded/src/fat_config/[...]/sandbox/home/ded/.config/labrat/config.yml':
          #   Changed: delta_x: -4mm -> -3mm
          #   Unchanged: delta_y: 1cm
          #   Unchanged: nl_sep: %%
          #   Changed: page_height: 101mm -> 102mm
          #   Unchanged: page_width: 33mm
          #   Unchanged: printer: seiko3
          hsh = {}
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(/Config key: global/)
          expect(result[:stderr]).to match(%r{/etc/xdg/labrat/config.ini})
          expect(result[:stderr]).to match(%r{/\.config/labrat/config.ini})
          expect(result[:stderr]).to match(/Merging system config/)
          expect(result[:stderr]).to match(/Merging user config/)
          expect(result[:stderr]).to match(/Added: *delta_x/)
          expect(result[:stderr]).to match(/Added: *delta_y/)
          expect(result[:stderr]).to match(/Changed: *delta_x/)
          expect(result[:stderr]).to match(/Unchanged: *delta_y/)
          expect(result[:stderr]).to match(/Changed: *page_height/)
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('102mm')
          expect(hsh[:global][:delta_x]).to eq('-3mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_HOME xdg user directory config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
          INI
          setup_test_file('~/.foncig/labrat/config.ini', config_ini)

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to be_nil
        end

        it 'reads an empty XDG_CONFIG_HOME xdg user directory config file' do
          setup_test_file('~/.foncig/labrat/config.INI', '')

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end
      end

      describe 'Reading classic config files' do
        let(:reader) { Reader.new('labrat', xdg: false, config_style: 'ini', root_prefix: sandbox_dir) }

        it 'read an empty classic system config file' do
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.ini'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], '')
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end

        it 'reads a classic system config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.ini'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_ini)

          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file("/home/#{ENV['USER']}/.labrat.ini", config_ini)
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file in ENV[\'LABRAT_CONFIG\']' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          ENV['LABRAT_CONFIG'] = '~/junk/random/lr.y'
          setup_test_file(ENV['LABRAT_CONFIG'], config_ini)
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it "reads a classic user rc-style config file in HOME" do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file('~/.labratrc', config_ini)
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads a classic ~/.labrat config dir in HOME' do
          config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          setup_test_file('~/.labrat/config', config_ini)
          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('101mm')
          expect(hsh[:global][:delta_x]).to eq('-4mm')
          expect(hsh[:global][:delta_y]).to eq('1cm')
          expect(hsh[:global][:nl_sep]).to eq("%%")
          expect(hsh[:global][:printer]).to eq('seiko3')
        end

        it 'reads a classic system and user config files' do
          sys_config_ini = <<~INI
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = "%%"
            printer = "seiko3"
          INI
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.ini'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], sys_config_ini)
          usr_config_ini = <<~INI
            page-height = "102mm"
            delta-x = "-7mm"
            delta-y = "+30mm"
            nl-sep = "~~"
          INI
          setup_test_file('~/.labrat/config.ini', usr_config_ini)

          hsh = reader.read
          expect(hsh[:global][:page_width]).to eq('33mm')
          expect(hsh[:global][:page_height]).to eq('102mm')
          expect(hsh[:global][:delta_x]).to eq('-7mm')
          expect(hsh[:global][:delta_y]).to eq('+30mm')
          expect(hsh[:global][:nl_sep]).to eq('~~')
          expect(hsh[:global][:printer]).to eq('seiko3')
        end
      end
    end
  end
end
