# frozen_string_literal: true

require 'spec_helper'

module FatConfig
  RSpec.describe FatConfig do
    context "with YAML Config Files" do
      # Put files here to test file-system dependent specs.
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

      describe 'Basic YAML reading' do
        let(:reader) { Reader.new('labrat') }
        let(:yaml_str) do
          <<~YAML
            ---
            doe: "a deer, a female deer"
            ray: 'a drop of golden sun'
            pi: 3.14159
            xmas: Yes
            lying: TrUe
            sorry: FaLsE
            french-hens: 3
            nothing:
            calling-birds:
              - huey
              - dewey
              - louie
              - fred
            the-day: 2024-12-25
            the-moment: 2024-12-25T06:30:15
            xmas-fifth-day: 2024-12-30
            french-hens: 3
            golden-rings: 5
            partridges:
              count: 1
              location: "a pear tree"
            turtle-doves: two
          YAML
        end

        let(:bad_yaml_str) do
          <<~YAML
            doe: "a deer, a female deer"
            ray: 'a drop of golden sun'
            pi: 3.14.159
            xmas Yes
            the-day: 2024-12-25
            golden-rings: 0x5
            partridges:
              count: 1
              location: "a pear tree"
            turtle-doves: two
          YAML
        end

        it 'can read a yaml string' do
          hsh = YAMLStyle.new.load_string(yaml_str)
          expect(hsh.keys).to include(:doe)
          expect(hsh.keys).to include(:french_hens)
          expect(hsh[:calling_birds]).to be_an Array
          expect(hsh[:xmas_fifth_day]).to be_a Date
          expect(hsh[:pi]).to be_a Float
          expect(hsh[:pi]).to eq(3.14159)
          expect(hsh[:lying]).to be_a TrueClass
          expect(hsh[:lying]).to be true
          expect(hsh[:sorry]).to be_a FalseClass
          expect(hsh[:sorry]).to be false
          expect(hsh[:nothing]).to be_nil
          expect(hsh[:xmas]).to be_a TrueClass
          expect(hsh[:xmas]).to be true
          expect(hsh[:calling_birds]).to be_an Array
          expect(hsh[:golden_rings]).to be_an Integer
          expect(hsh[:the_day]).to be_a Date
          expect(hsh[:the_moment]).to be_a Time
          expect(hsh[:partridges][:count]).to be_an Integer
          expect(hsh[:turtle_doves]).to be_a String
        end

        it 'raises FatConfig::ParseError on a bad yaml string' do
          expect { YAMLStyle.new.load_string(bad_yaml_str) }.to raise_error(/could not find expected ':'/i)
        end

        it 'raises FatConfig::ParseError on a bad yaml file' do
          setup_test_file('/etc/xdg/labrat/config.yml', bad_yaml_str)
          expect {
            Reader.new('labrat', config_style: :yaml, root_prefix: sandbox_dir)
              .read(verbose: true)
          }.to raise_error(/could not find expected ':'/i)
        end
      end

      describe 'Reading XDG config files' do
        let(:reader) { Reader.new('labrat', root_prefix: sandbox_dir) }

        it 'reads an xdg system config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('/etc/xdg/labrat/config.yml', config_yml)

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
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl_sep: '%%'
          YAML
          setup_test_file('/lib/junk/labrat/config.yml', config_yml)

          # Lower priority XDG
          config2_yml = <<~YAML
            page-width: 3cm
            page-height: 10cm
            delta-x: -4pt
            printer: dymo4
            rows: 10
            columns: 3
          YAML
          setup_test_file('/lib/lowjunk/labrat/config.yml', config2_yml)

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
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat.yml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_yml)
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
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.yml", config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an empty xdg system config file and reports empty' do
          config_cfg = <<~CFG
            # page-width: 33mm
            # page-height: 101mm
            # delta-x: -4mm
            # delta-y: 1cm
            # nl-sep: '%%'
            # printer: seiko3
          CFG
          setup_test_file("/etc/xdg/labrat/config.yml", config_cfg)
          hsh = nil
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(/System config files found/i)
          expect(result[:stderr]).to match(/Merging system config from file/i)
          expect(result[:stderr]).to match(/Empty config/i)
          expect(hsh).to be_empty
        end

        it 'reads an alternative base-named xdg user config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/labeldb.yml", config_yml)
          hsh = reader.read('labeldb')
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an xdg ENV-specified user config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_CONFIG'] = "/home/#{ENV['USER']}/.labrc"
          setup_test_file(ENV['LABRAT_CONFIG'], config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'merges an xdg user config into an xdg system config file' do
          sys_config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('/etc/xdg/labrat/config.yml', sys_config_yml)
          usr_config_yml = <<~YAML
            page-height: 102mm
            delta-x: -3mm
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.yml", usr_config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'verbosely merges an xdg user config into an xdg system config file' do
          sys_config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('/etc/xdg/labrat/config.yml', sys_config_yml)
          usr_config_yml = <<~YAML
            page-height: 102mm
            delta-x: -3mm
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.yml", usr_config_yml)

          hsh = {}
          # With verbose true, stderr should be the following:
          #
          # System config files found: /home/ded/src/fat_config[...]/sandbox/etc/xdg/labrat/config.yml
          # User config files found: /home/ded/src/fat_config[...]/sandbox/etc/xdg/labrat/config.yml
          # Merging system config from file '/home/ded/src/fat_config[...]/sandbox/etc/xdg/labrat/config.yml':
          #   Added: delta_x: -4mm
          #   Added: delta_x: -4mm
          #   Added: delta_y: 1cm
          #   Added: nl_sep: %%
          #   Added: page_height: 101mm
          #   Added: page_width: 33mm
          #   Added: printer: seiko3
          # Merging user config from file '/home/ded/src/fat_config[...]/sandbox/home/ded/.config/labrat/config.yml':
          #   Changed: delta_x: -4mm -> -3mm
          #   Unchanged: delta_y: 1cm
          #   Unchanged: nl_sep: %%
          #   Changed: page_height: 101mm -> 102mm
          #   Unchanged: page_width: 33mm
          #   Unchanged: printer: seiko3
          result = capture { hsh = reader.read(verbose: true) }
          expect(result[:stderr]).to match(%r{/etc/xdg/labrat/config.yml})
          expect(result[:stderr]).to match(%r{/\.config/labrat/config.yml})
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
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
          YAML
          setup_test_file('~/.foncig/labrat/config.yml', config_yml)

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
          setup_test_file('~/.foncig/labrat/config.yml', '')

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end
      end

      describe 'Reading classic config files' do
        let(:reader) { Reader.new('labrat', xdg: false, root_prefix: sandbox_dir) }

        it 'read an empty classic system config file' do
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.yaml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], '')
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end

        it 'reads a classic system config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.yaml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file("/home/#{ENV['USER']}/.labrat.yml", config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file in ENV[\'LABRAT_CONFIG\']' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_CONFIG'] = '~/junk/random/lr.y'
          setup_test_file(ENV['LABRAT_CONFIG'], config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it "reads a classic user rc-style config file in HOME" do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('~/.labratrc', config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic ~/.labrat config dir in HOME' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('~/.labrat/config', config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic system and user config files' do
          sys_config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.yaml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], sys_config_yml)
          usr_config_yml = <<~YAML
            page-height: 102mm
            delta-x: -7mm
            delta-y: +30mm
            nl-sep: '~~'
          YAML
          setup_test_file('~/.labrat/config.yml', usr_config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-7mm')
          expect(hsh[:delta_y]).to eq('+30mm')
          expect(hsh[:nl_sep]).to eq('~~')
          expect(hsh[:printer]).to eq('seiko3')
        end
      end

      describe "All types of config at once, verbosely" do
        let(:reader) { Reader.new('labrat', root_prefix: sandbox_dir) }

        after do
          ENV.delete('LABRAT_OPTIONS')
        end

        it 'verbosely merges an xdg user config into an xdg system config file' do
          sys_config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('/etc/xdg/labrat/config.yml', sys_config_yml)
          usr_config_yml = <<~YAML
            page-height: 102mm
            delta-x: -3mm
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.yml", usr_config_yml)
          # With verbose true, stderr should be the following:
          #
          # System config files found: /tmp/fat_config/sandbox/etc/xdg/labrat/config.yml
          # User config files found: /tmp/fat_config/sandbox/etc/xdg/labrat/config.yml
          # Merging system config from file '/tmp/fat_config/sandbox/etc/xdg/labrat/config.yml':
          #   Added:     delta_x: -4mm
          #   Added:     delta_y: 1cm
          #   Added:     nl_sep: %%
          #   Added:     page_height: 101mm
          #   Added:     page_width: 33mm
          #   Added:     printer: seiko3
          # Merging user config from file '/tmp/fat_config/sandbox/home/ded/.config/labrat/config.yml':
          #   Changed:   delta_x: -4mm -> -3mm
          #   Unchanged: delta_y: 1cm
          #   Unchanged: nl_sep: %%
          #   Changed:   page_height: 101mm -> 102mm
          #   Unchanged: page_width: 33mm
          #   Unchanged: printer: seiko3
          # Merging environment from LABRAT_OPTIONS:
          #   Unchanged: delta_x: -3mm
          #   Unchanged: delta_y: 1cm
          #   Added:     flip: false
          #   Added:     flop: true
          #   Added:     grid_gap: 4pt
          #   Unchanged: nl_sep: %%
          #   Unchanged: page_height: 102mm
          #   Unchanged: page_width: 33mm
          #   Changed:   printer: seiko3 -> hp1
          # Merging command-line:
          #   Unchanged: delta_x: -3mm
          #   Unchanged: delta_y: 1cm
          #   Unchanged: flip: false
          #   Unchanged: flop: true
          #   Unchanged: grid_gap: 4pt
          #   Unchanged: nl_sep: %%
          #   Unchanged: page_height: 102mm
          #   Changed:   page_width: 33mm -> 10cm
          #   Changed:   printer: hp1 -> hp2
          ENV['LABRAT_OPTIONS'] = "--grid-gap=4pt --printer=hp1 --flop --!flip"
          command_line = { printer: "hp2", page_width: "10cm" }
          hsh = {}
          result = capture { hsh = reader.read(command_line: command_line, verbose: true) }
          expect(result[:stderr]).to match(%r{/etc/xdg/labrat/config.yml})
          expect(result[:stderr]).to match(%r{/\.config/labrat/config.yml})
          expect(result[:stderr]).to match(/Merging system config/)
          expect(result[:stderr]).to match(/Merging user config/)
          expect(result[:stderr]).to match(/Added: *delta_x/)
          expect(result[:stderr]).to match(/Added: *delta_y/)
          expect(result[:stderr]).to match(/Changed: *delta_x/)
          expect(result[:stderr]).to match(/Unchanged: *delta_y/)
          expect(result[:stderr]).to match(/Changed: *page_height/)
          expect(result[:stderr]).to match(/Merging environment from LABRAT_OPTIONS/)
          expect(result[:stderr]).to match(/Added: *flip: false/)
          expect(result[:stderr]).to match(/Added: *flop: true/)
          expect(result[:stderr]).to match(/Changed: *printer: seiko3 -> hp1/)
          expect(result[:stderr]).to match(/Merging command-line/)
          expect(result[:stderr]).to match(/Changed: *page_width: 33mm -> 10cm/)
          expect(result[:stderr]).to match(/Changed: *printer: hp1 -> hp2/)

          expect(hsh[:page_width]).to eq('10cm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('hp2')
        end
      end
    end
  end
end
