# frozen_string_literal: true

require 'spec_helper'

module FatConfig
  RSpec.describe FatConfig do
    context "with TOML Config Files" do
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

      describe 'Basic TOML reading' do
        let(:reader) { Reader.new('labrat', config_lang: toml) }
        let(:toml_str) do
          <<~TOML
            doe = "a deer, a female deer"
            ray = "a drop of golden sun"
            pi = 3.14159
            xmas = true
            french-hens = 3
            calling-birds = [ "huey", "dewey", "louie", "fred" ]
            xmas-fifth-day = ""
            golden-rings = 5
            turtle-doves = "two"
            the-day = 2024-12-24

            [partridges]
            count = 1
            location = "a pear tree"
          TOML
        end

        it 'can read a toml string' do
          hsh = Tomlib.load(toml_str)
          hsh = hsh.methodize
          expect(hsh.keys).to include(:doe)
          expect(hsh.keys).to include(:french_hens)
          expect(hsh[:calling_birds]).to be_an Array
          expect(hsh[:the_day]).to be_a Date
        end
      end

      describe 'Reading XDG config files' do
        let(:reader) { Reader.new('labrat', config_style: :toml, root_prefix: sandbox_dir) }

        it 'reads an xdg system config file' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file('/etc/xdg/labrat/config.toml', config_tml)

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
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
          TOML
          setup_test_file('/lib/junk/labrat/config.toml', config_tml)

          # Lower priority XDG
          config2_tml = <<~TOML
            page-width = "3cm"
            page-height = "10cm"
            delta-x =  "-4pt"
            delta-y = "1cm"
            printer = "dymo4"
            rows = 10
            columns = 3
          TOML
          setup_test_file('/lib/lowjunk/labrat/config.toml', config2_tml)

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
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat.yml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_tml)
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
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.toml", config_tml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an xdg ENV-specified user config file' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          ENV['LABRAT_CONFIG'] = "/home/#{ENV['USER']}/.labrc"
          setup_test_file(ENV['LABRAT_CONFIG'], config_tml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'merges an xdg user config into an xdg system config file' do
          sys_config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file('/etc/xdg/labrat/config.toml', sys_config_tml)
          usr_config_tml = <<~TOML
            page-height = "102mm"
            delta-x = "-3mm"
          TOML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.toml", usr_config_tml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'vebosely merges an xdg user config into an xdg system config file' do
          sys_config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file('/etc/xdg/labrat/config.toml', sys_config_tml)
          usr_config_tml = <<~TOML
            page-height = "102mm"
            delta-x = "-3mm"
          TOML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.toml", usr_config_tml)

          # With verbose true, stderr should be the following:
          #
          # System config files found: /home/ded/src/fat_config/spec/fat_config/support/sandbox/etc/xdg/labrat/config.toml
          # User config files found: /home/ded/src/fat_config/spec/fat_config/support/sandbox/etc/xdg/labrat/config.toml
          # Merging system config from file '/home/ded/src/fat_config/spec/fat_config/support/sandbox/etc/xdg/labrat/config.toml':
          #   Added: delta_x: -4mm
          #   Added: delta_y: 1cm
          #   Added: nl_sep: %%
          #   Added: page_height: 101mm
          #   Added: page_width: 33mm
          #   Added: printer: seiko3
          # Merging user config from file '/home/ded/src/fat_config/spec/fat_config/support/sandbox/home/ded/.config/labrat/config.toml':
          #   Changed: delta_x: -4mm -> -3mm
          #   Unchanged: delta_y: 1cm
          #   Unchanged: nl_sep: %%
          #   Changed: page_height: 101mm -> 102mm
          #   Unchanged: page_width: 33mm
          #   Unchanged: printer: seiko3
          #
          hsh = {}
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(%r{/etc/xdg/labrat/config.toml})
          expect(result[:stderr]).to match(%r{/\.config/labrat/config.toml})
          expect(result[:stderr]).to match(%r{Merging system config})
          expect(result[:stderr]).to match(%r{Merging user config})
          expect(result[:stderr]).to match(%r{Added: *delta_x})
          expect(result[:stderr]).to match(%r{Added: *delta_y})
          expect(result[:stderr]).to match(%r{Changed: *delta_x})
          expect(result[:stderr]).to match(%r{Unchanged: *delta_y})
          expect(result[:stderr]).to match(%r{Changed: *page_height})

          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_HOME xdg user directory config file' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
          TOML
          setup_test_file('~/.foncig/labrat/config.toml', config_tml)

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
          setup_test_file('~/.foncig/labrat/config.toml', '')

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end
      end

      describe 'Reading classic config files' do
        let(:reader) { Reader.new('labrat', xdg: false, config_style: :toml, root_prefix: sandbox_dir) }

        it 'read an empty classic system config file' do
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.toml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], '')
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end

        it 'reads a classic system config file' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.toml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_tml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file("/home/#{ENV['USER']}/.labrat.toml", config_tml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file in ENV[\'LABRAT_CONFIG\']' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          ENV['LABRAT_CONFIG'] = '~/junk/random/lr.y'
          setup_test_file(ENV['LABRAT_CONFIG'], config_tml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it "reads a classic user rc-style config file in HOME" do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file('~/.labratrc', config_tml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic ~/.labrat config dir in HOME' do
          config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          setup_test_file('~/.labrat/config', config_tml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic system and user config files' do
          sys_config_tml = <<~TOML
            page-width = "33mm"
            page-height = "101mm"
            delta-x = "-4mm"
            delta-y = "1cm"
            nl-sep = '%%'
            printer = "seiko3"
          TOML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.toml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], sys_config_tml)
          usr_config_tml = <<~TOML
            page-height = "102mm"
            delta-x = "-7mm"
            delta-y = "+30mm"
            nl-sep = '~~'
          TOML
          setup_test_file('~/.labrat/config.toml', usr_config_tml)

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
